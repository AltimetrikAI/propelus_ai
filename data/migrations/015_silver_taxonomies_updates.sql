-- ============================================================================
-- Migration 015: Silver Taxonomies Table Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_taxonomies table per data engineer spec
--              - Add load_id foreign key to bronze_load_details
--              - Add column comments for documentation
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD load_id FOREIGN KEY
-- ============================================================================

ALTER TABLE silver_taxonomies
ADD COLUMN IF NOT EXISTS load_id INTEGER;

-- Add foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_taxonomies_load'
    ) THEN
        ALTER TABLE silver_taxonomies
        ADD CONSTRAINT fk_silver_taxonomies_load
        FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);
    END IF;
END $$;

-- ============================================================================
-- CREATE INDEX FOR load_id
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_taxonomies_load
ON silver_taxonomies(load_id);

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_taxonomies IS 'Table with basic data of taxonomies';
COMMENT ON COLUMN silver_taxonomies.taxonomy_id IS 'Primary key - ID of the taxonomy';
COMMENT ON COLUMN silver_taxonomies.customer_id IS 'Identifier of the customer providing the taxonomy taken from application API';
COMMENT ON COLUMN silver_taxonomies.name IS 'Name of the taxonomy';
COMMENT ON COLUMN silver_taxonomies.type IS 'Whether it is a master Propelus taxonomy (taxonomy_id will be -1) or customer taxonomy';
COMMENT ON COLUMN silver_taxonomies.status IS 'Determines if taxonomy is active or inactive (used for current mappings or saved for historical purposes)';
COMMENT ON COLUMN silver_taxonomies.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_taxonomies.last_updated_at IS 'Timestamp when the row was last updated';
COMMENT ON COLUMN silver_taxonomies.load_id IS 'Foreign key to bronze_load_details table - identifier of last load that occurred to this taxonomy';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    -- Check load_id column exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_taxonomies'
        AND column_name = 'load_id'
    ) THEN
        RAISE EXCEPTION 'Migration 015 failed: load_id column not created';
    END IF;

    -- Check foreign key exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_taxonomies_load'
    ) THEN
        RAISE EXCEPTION 'Migration 015 failed: Foreign key constraint not created';
    END IF;

    -- Check index exists
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE tablename = 'silver_taxonomies'
        AND indexname = 'idx_silver_taxonomies_load'
    ) THEN
        RAISE WARNING 'Migration 015: Index idx_silver_taxonomies_load not found';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 015: Silver Taxonomies Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Column Added: 1';
    RAISE NOTICE '  - load_id (INTEGER, FK to bronze_load_details)';
    RAISE NOTICE 'New Index Created: 1';
    RAISE NOTICE 'Constraints Added: 1 FK';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
