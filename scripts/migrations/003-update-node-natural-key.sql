-- ============================================================================
-- Migration 003: Update Node Natural Key (v1.0 Algorithm)
-- ============================================================================
-- Purpose: Change natural key to support same value at different levels
-- Old NK: (taxonomy_id, node_type_id, customer_id, LOWER(value))
-- New NK: (taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value))
--
-- This allows nodes with the same value to exist under different parents
-- Example: "Associate" can exist under "Social Worker" and "Nurse" independently
--
-- Date: 2025-10-14
-- Algorithm Version: v1.0
-- ============================================================================

BEGIN;

-- Step 1: Drop existing unique constraint if it exists
-- Note: The constraint name may vary based on PostgreSQL auto-naming
DO $$
DECLARE
    constraint_name text;
BEGIN
    -- Find the constraint name
    SELECT con.conname INTO constraint_name
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE rel.relname = 'silver_taxonomies_nodes'
      AND nsp.nspname = 'public'
      AND con.contype = 'u'  -- unique constraint
      AND con.conkey = ARRAY(
          SELECT a.attnum
          FROM pg_attribute a
          WHERE a.attrelid = rel.oid
            AND a.attname IN ('taxonomy_id', 'node_type_id', 'customer_id')
          ORDER BY a.attnum
      );

    -- Drop if found
    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE silver_taxonomies_nodes DROP CONSTRAINT %I', constraint_name);
        RAISE NOTICE 'Dropped old unique constraint: %', constraint_name;
    ELSE
        RAISE NOTICE 'No old unique constraint found, skipping drop';
    END IF;
END$$;

-- Step 2: Create new unique constraint with parent_node_id included
-- This allows same value under different parents
ALTER TABLE silver_taxonomies_nodes
  ADD CONSTRAINT uk_silver_nodes_natural_key_v1
    UNIQUE (taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value));

-- Step 3: Create supporting index for queries filtering by parent
-- Improves performance for parent-child hierarchy queries
CREATE INDEX IF NOT EXISTS idx_silver_nodes_by_parent
  ON silver_taxonomies_nodes (taxonomy_id, customer_id, parent_node_id)
  WHERE status = 'active' AND node_type_id != -1;

-- Step 4: Create index for level 0 (root) node queries
-- Optimizes queries for finding root nodes
CREATE INDEX IF NOT EXISTS idx_silver_nodes_root
  ON silver_taxonomies_nodes (taxonomy_id, customer_id, level)
  WHERE level = 0 AND status = 'active' AND node_type_id != -1;

-- Step 5: Update any conflicting rows (if needed)
-- This handles edge case where old data might violate new constraint
-- We keep the most recently updated row for each (taxonomy_id, node_type_id, customer_id, parent_node_id, value) group
WITH ranked_nodes AS (
  SELECT
    node_id,
    ROW_NUMBER() OVER (
      PARTITION BY taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value)
      ORDER BY last_updated_at DESC, node_id DESC
    ) AS rn
  FROM silver_taxonomies_nodes
)
UPDATE silver_taxonomies_nodes
SET status = 'inactive',
    last_updated_at = NOW()
WHERE node_id IN (
  SELECT node_id
  FROM ranked_nodes
  WHERE rn > 1
);

-- Record migration in log (if you have a migrations table)
-- If not, this will just be a comment
-- INSERT INTO schema_migrations (version, description, applied_at)
-- VALUES ('003', 'Update node natural key to include parent_node_id', NOW());

COMMIT;

-- ============================================================================
-- Rollback Instructions (if needed)
-- ============================================================================
-- To rollback this migration:
--
-- BEGIN;
-- DROP INDEX IF EXISTS idx_silver_nodes_by_parent;
-- DROP INDEX IF EXISTS idx_silver_nodes_root;
-- ALTER TABLE silver_taxonomies_nodes DROP CONSTRAINT uk_silver_nodes_natural_key_v1;
-- ALTER TABLE silver_taxonomies_nodes
--   ADD CONSTRAINT uk_silver_nodes_natural_key_old
--     UNIQUE (taxonomy_id, node_type_id, customer_id, LOWER(value));
-- COMMIT;
-- ============================================================================

-- Migration complete
SELECT 'Migration 003: Node natural key updated successfully' AS result;
