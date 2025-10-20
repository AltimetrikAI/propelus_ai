-- ============================================================================
-- Migration 024: Create gold_mapping_taxonomies Table
-- ============================================================================
-- Date: 2025-01-26
-- Description: Create gold_mapping_taxonomies table per data engineer spec
--              Final approved mappings between taxonomies (mirrors active non-AI mappings from Silver)
-- ============================================================================

BEGIN;

-- ============================================================================
-- CREATE gold_mapping_taxonomies TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS gold_mapping_taxonomies (
    mapping_id INTEGER PRIMARY KEY,
    master_node_id INTEGER NOT NULL,
    child_node_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ADD FOREIGN KEY CONSTRAINTS
-- ============================================================================

-- Foreign key to silver_mapping_taxonomies (source of truth)
ALTER TABLE gold_mapping_taxonomies
ADD CONSTRAINT fk_gold_mapping_silver
FOREIGN KEY (mapping_id) REFERENCES silver_mapping_taxonomies(mapping_id);

-- Foreign key to master node
ALTER TABLE gold_mapping_taxonomies
ADD CONSTRAINT fk_gold_mapping_master_node
FOREIGN KEY (master_node_id) REFERENCES silver_taxonomies_nodes(node_id);

-- Foreign key to child node
ALTER TABLE gold_mapping_taxonomies
ADD CONSTRAINT fk_gold_mapping_child_node
FOREIGN KEY (child_node_id) REFERENCES silver_taxonomies_nodes(node_id);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

CREATE INDEX idx_gold_mapping_master_node
ON gold_mapping_taxonomies(master_node_id);

CREATE INDEX idx_gold_mapping_child_node
ON gold_mapping_taxonomies(child_node_id);

CREATE INDEX idx_gold_mapping_both_nodes
ON gold_mapping_taxonomies(master_node_id, child_node_id);

CREATE INDEX idx_gold_mapping_created_at
ON gold_mapping_taxonomies(created_at DESC);

CREATE INDEX idx_gold_mapping_updated_at
ON gold_mapping_taxonomies(last_updated_at DESC);

-- ============================================================================
-- ADD COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE gold_mapping_taxonomies IS 'Final approved mappings between taxonomies. Contains only active, non-AI mappings mirrored from silver_mapping_taxonomies';

COMMENT ON COLUMN gold_mapping_taxonomies.mapping_id IS 'Primary key - values taken from silver_mapping_taxonomies';
COMMENT ON COLUMN gold_mapping_taxonomies.master_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in master taxonomy - taken from silver_mapping_taxonomies';
COMMENT ON COLUMN gold_mapping_taxonomies.child_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in child taxonomy - taken from silver_mapping_taxonomies';
COMMENT ON COLUMN gold_mapping_taxonomies.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN gold_mapping_taxonomies.last_updated_at IS 'Timestamp when the row was last updated';

-- ============================================================================
-- CREATE TRIGGER FOR last_updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_gold_mapping_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gold_mapping_timestamp
BEFORE UPDATE ON gold_mapping_taxonomies
FOR EACH ROW
EXECUTE FUNCTION update_gold_mapping_timestamp();

-- ============================================================================
-- CREATE SYNC VIEW FOR GOLD LAYER MAINTENANCE
-- ============================================================================

-- View to identify mappings that should be in Gold but aren't
CREATE OR REPLACE VIEW v_gold_sync_candidates AS
SELECT
    m.mapping_id,
    m.master_node_id,
    m.node_id AS child_node_id,
    m.confidence,
    m.status,
    m."user",
    r.AI_mapping_flag,
    r.Human_mapping_flag,
    CASE
        WHEN g.mapping_id IS NULL THEN 'missing_in_gold'
        ELSE 'exists_in_gold'
    END AS sync_status
FROM silver_mapping_taxonomies m
LEFT JOIN silver_mapping_taxonomies_rules r ON m.mapping_rule_id = r.mapping_rule_id
LEFT JOIN gold_mapping_taxonomies g ON m.mapping_id = g.mapping_id
WHERE m.status = 'active'
  AND (r.AI_mapping_flag = FALSE OR r.AI_mapping_flag IS NULL);

COMMENT ON VIEW v_gold_sync_candidates IS 'Identifies active non-AI mappings from Silver that should be synchronized to Gold layer';

-- View to identify orphaned Gold entries
CREATE OR REPLACE VIEW v_gold_orphaned_mappings AS
SELECT
    g.mapping_id,
    g.master_node_id,
    g.child_node_id,
    g.created_at,
    g.last_updated_at,
    CASE
        WHEN m.mapping_id IS NULL THEN 'missing_in_silver'
        WHEN m.status = 'inactive' THEN 'inactive_in_silver'
        WHEN r.AI_mapping_flag = TRUE THEN 'ai_mapping_in_silver'
        ELSE 'other'
    END AS orphan_reason
FROM gold_mapping_taxonomies g
LEFT JOIN silver_mapping_taxonomies m ON g.mapping_id = m.mapping_id
LEFT JOIN silver_mapping_taxonomies_rules r ON m.mapping_rule_id = r.mapping_rule_id
WHERE m.mapping_id IS NULL
   OR m.status = 'inactive'
   OR r.AI_mapping_flag = TRUE;

COMMENT ON VIEW v_gold_orphaned_mappings IS 'Identifies Gold mappings that should be removed (no longer active or are AI-based)';

-- ============================================================================
-- CREATE HELPER FUNCTION FOR GOLD SYNC
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_gold_mapping_taxonomies()
RETURNS TABLE (
    inserted_count INTEGER,
    deleted_count INTEGER,
    sync_summary TEXT
) AS $$
DECLARE
    v_inserted INTEGER := 0;
    v_deleted INTEGER := 0;
BEGIN
    -- Delete orphaned mappings from Gold
    DELETE FROM gold_mapping_taxonomies
    WHERE mapping_id IN (
        SELECT mapping_id FROM v_gold_orphaned_mappings
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    -- Insert missing active non-AI mappings to Gold
    INSERT INTO gold_mapping_taxonomies (mapping_id, master_node_id, child_node_id, created_at)
    SELECT
        mapping_id,
        master_node_id,
        child_node_id,
        CURRENT_TIMESTAMP
    FROM v_gold_sync_candidates
    WHERE sync_status = 'missing_in_gold'
    ON CONFLICT (mapping_id) DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    -- Return summary
    RETURN QUERY SELECT
        v_inserted,
        v_deleted,
        format('Inserted: %s, Deleted: %s', v_inserted, v_deleted);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sync_gold_mapping_taxonomies IS 'Synchronizes Gold layer with active non-AI mappings from Silver layer';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
    idx_count INTEGER;
BEGIN
    -- Check table exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_name = 'gold_mapping_taxonomies'
    ) THEN
        RAISE EXCEPTION 'Migration 024 failed: Table gold_mapping_taxonomies not created';
    END IF;

    -- Check column count
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'gold_mapping_taxonomies';

    IF col_count <> 5 THEN
        RAISE WARNING 'Migration 024: Expected 5 columns, found %', col_count;
    END IF;

    -- Check indexes
    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE tablename = 'gold_mapping_taxonomies';

    IF idx_count < 5 THEN
        RAISE WARNING 'Migration 024: Expected at least 5 indexes, found %', idx_count;
    END IF;

    -- Check foreign keys
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname IN ('fk_gold_mapping_silver', 'fk_gold_mapping_master_node', 'fk_gold_mapping_child_node')
    ) THEN
        RAISE WARNING 'Migration 024: Some foreign keys may be missing';
    END IF;

    -- Check views exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name IN ('v_gold_sync_candidates', 'v_gold_orphaned_mappings')
    ) THEN
        RAISE WARNING 'Migration 024: Some helper views may be missing';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 024: gold_mapping_taxonomies - CREATED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Table Created: gold_mapping_taxonomies';
    RAISE NOTICE 'Columns: 5';
    RAISE NOTICE 'Indexes: %', idx_count;
    RAISE NOTICE 'Foreign Keys: 3 (mapping_id, master_node_id, child_node_id)';
    RAISE NOTICE 'Triggers: 1 (auto-update last_updated_at)';
    RAISE NOTICE 'Helper Views: 2 (sync_candidates, orphaned_mappings)';
    RAISE NOTICE 'Helper Functions: 1 (sync_gold_mapping_taxonomies)';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Gold layer mirrors active non-AI mappings from Silver layer';
    RAISE NOTICE 'Use sync_gold_mapping_taxonomies() function to synchronize';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
