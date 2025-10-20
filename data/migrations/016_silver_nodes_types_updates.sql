-- ============================================================================
-- Migration 016: Silver Taxonomies Nodes Types Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_taxonomies_nodes_types table per data engineer spec
--              - Add load_id foreign key to bronze_load_details
--              - Add column comments for documentation
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD load_id FOREIGN KEY
-- ============================================================================

ALTER TABLE silver_taxonomies_nodes_types
ADD COLUMN IF NOT EXISTS load_id INTEGER;

-- Add foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_types_load'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes_types
        ADD CONSTRAINT fk_silver_nodes_types_load
        FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);
    END IF;
END $$;

-- ============================================================================
-- CREATE INDEX FOR load_id
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_nodes_types_load
ON silver_taxonomies_nodes_types(load_id);

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_taxonomies_nodes_types IS 'Defines the types of nodes used in taxonomies';
COMMENT ON COLUMN silver_taxonomies_nodes_types.node_type_id IS 'Primary surrogate key - ID for the node type';
COMMENT ON COLUMN silver_taxonomies_nodes_types.name IS 'Name of the node type (for example: industry, Detailed occupation, Profession)';
COMMENT ON COLUMN silver_taxonomies_nodes_types.status IS 'Status of the node type - Determines if node type is active or inactive (used for current mappings or saved for historical purposes)';
COMMENT ON COLUMN silver_taxonomies_nodes_types.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_taxonomies_nodes_types.last_updated_at IS 'Timestamp when the row was last updated';
COMMENT ON COLUMN silver_taxonomies_nodes_types.load_id IS 'Foreign key to bronze_load_details table';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    -- Check load_id column exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_taxonomies_nodes_types'
        AND column_name = 'load_id'
    ) THEN
        RAISE EXCEPTION 'Migration 016 failed: load_id column not created';
    END IF;

    -- Check foreign key exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_types_load'
    ) THEN
        RAISE EXCEPTION 'Migration 016 failed: Foreign key constraint not created';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 016: Silver Nodes Types Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Column Added: 1';
    RAISE NOTICE '  - load_id (INTEGER, FK to bronze_load_details)';
    RAISE NOTICE 'New Index Created: 1';
    RAISE NOTICE 'Constraints Added: 1 FK';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
