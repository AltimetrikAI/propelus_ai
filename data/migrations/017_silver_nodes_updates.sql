-- ============================================================================
-- Migration 017: Silver Taxonomies Nodes Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_taxonomies_nodes table per data engineer spec
--              - Add profession column
--              - Add level column (hierarchy level in taxonomy)
--              - Add status column
--              - Add load_id foreign key
--              - Add row_id foreign key
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD NEW COLUMNS
-- ============================================================================

-- Add profession column (name of the profession connected to the node)
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN IF NOT EXISTS profession VARCHAR(500);

-- Add level column (hierarchy level in taxonomy, 0 for root)
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN IF NOT EXISTS level INTEGER DEFAULT 0;

-- Add check constraint for level
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_silver_nodes_level'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes
        ADD CONSTRAINT chk_silver_nodes_level
        CHECK (level >= 0);
    END IF;
END $$;

-- Add status column
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

-- Add check constraint for status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_silver_nodes_status'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes
        ADD CONSTRAINT chk_silver_nodes_status
        CHECK (status IN ('active', 'inactive'));
    END IF;
END $$;

-- Add load_id foreign key
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN IF NOT EXISTS load_id INTEGER;

-- Add foreign key constraint for load_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_load'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes
        ADD CONSTRAINT fk_silver_nodes_load
        FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);
    END IF;
END $$;

-- Add row_id foreign key
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN IF NOT EXISTS row_id INTEGER;

-- Add foreign key constraint for row_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_row'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes
        ADD CONSTRAINT fk_silver_nodes_row
        FOREIGN KEY (row_id) REFERENCES bronze_taxonomies(row_id);
    END IF;
END $$;

-- ============================================================================
-- CREATE INDEXES FOR NEW COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_nodes_profession
ON silver_taxonomies_nodes(profession);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_level
ON silver_taxonomies_nodes(level);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_status
ON silver_taxonomies_nodes(status);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_load
ON silver_taxonomies_nodes(load_id);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_row
ON silver_taxonomies_nodes(row_id);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_taxonomy_level
ON silver_taxonomies_nodes(taxonomy_id, level);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_status_active
ON silver_taxonomies_nodes(status) WHERE status = 'active';

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_taxonomies_nodes IS 'Stores actual hierarchy nodes within taxonomies (for example: Healthcare for Industry type node, Advanced Psychiatric Nurse for Profession type of node)';
COMMENT ON COLUMN silver_taxonomies_nodes.node_id IS 'Primary surrogate key - ID of the node';
COMMENT ON COLUMN silver_taxonomies_nodes.node_type_id IS 'Foreign key to the silver_taxonomies_nodes_types';
COMMENT ON COLUMN silver_taxonomies_nodes.taxonomy_id IS 'Foreign key to the silver_taxonomies';
COMMENT ON COLUMN silver_taxonomies_nodes.parent_node_id IS 'Foreign key to parent node in the hierarchy (silver_taxonomies_node foreign key and null for top level)';
COMMENT ON COLUMN silver_taxonomies_nodes.value IS 'Text value of the node (for example: Healthcare, Advanced Psychiatric Nurse)';
COMMENT ON COLUMN silver_taxonomies_nodes.profession IS 'Name of the profession connected to the node';
COMMENT ON COLUMN silver_taxonomies_nodes.level IS 'Hierarchy level in taxonomy, numbers, 0 for root leaf of the hierarchy';
COMMENT ON COLUMN silver_taxonomies_nodes.status IS 'Active or inactive. Inactive can be set up manually by user if they don''t want the node to be active. Default is active';
COMMENT ON COLUMN silver_taxonomies_nodes.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_taxonomies_nodes.last_updated_at IS 'Timestamp when the row was last updated';
COMMENT ON COLUMN silver_taxonomies_nodes.load_id IS 'Foreign key to bronze_load_details table';
COMMENT ON COLUMN silver_taxonomies_nodes.row_id IS 'Foreign key to bronze_taxonomies table';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
BEGIN
    -- Check all new columns exist
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'silver_taxonomies_nodes'
    AND column_name IN ('profession', 'level', 'status', 'load_id', 'row_id');

    IF col_count <> 5 THEN
        RAISE EXCEPTION 'Migration 017 failed: Expected 5 new columns, found %', col_count;
    END IF;

    -- Check foreign keys exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_load'
    ) THEN
        RAISE EXCEPTION 'Migration 017 failed: load_id foreign key not created';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_row'
    ) THEN
        RAISE EXCEPTION 'Migration 017 failed: row_id foreign key not created';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 017: Silver Nodes Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Columns Added: 5';
    RAISE NOTICE '  - profession (VARCHAR(500))';
    RAISE NOTICE '  - level (INTEGER, default 0)';
    RAISE NOTICE '  - status (VARCHAR(20), default active)';
    RAISE NOTICE '  - load_id (INTEGER, FK to bronze_load_details)';
    RAISE NOTICE '  - row_id (INTEGER, FK to bronze_taxonomies)';
    RAISE NOTICE 'New Indexes Created: 7';
    RAISE NOTICE 'Constraints Added: 2 FK, 2 CHECK';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
