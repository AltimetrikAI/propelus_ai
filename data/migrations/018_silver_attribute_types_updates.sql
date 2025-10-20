-- ============================================================================
-- Migration 018: Silver Taxonomies Attribute Types Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_taxonomies_attribute_types table per data engineer spec
--              - Add load_id foreign key to bronze_load_details
--              - Add column comments for documentation
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD load_id FOREIGN KEY
-- ============================================================================

ALTER TABLE silver_taxonomies_attribute_types
ADD COLUMN IF NOT EXISTS load_id INTEGER;

-- Add foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_attr_types_load'
    ) THEN
        ALTER TABLE silver_taxonomies_attribute_types
        ADD CONSTRAINT fk_silver_attr_types_load
        FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);
    END IF;
END $$;

-- ============================================================================
-- CREATE INDEX FOR load_id
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_attr_types_load
ON silver_taxonomies_attribute_types(load_id);

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_taxonomies_attribute_types IS 'Defines the types of attributes that can be assigned to taxonomy nodes. Acts as a reference table so attributes are standardized across taxonomies';
COMMENT ON COLUMN silver_taxonomies_attribute_types.attribute_type_id IS 'Primary surrogate key - ID of the attribute type';
COMMENT ON COLUMN silver_taxonomies_attribute_types.name IS 'Name of the attribute type (for example: State)';
COMMENT ON COLUMN silver_taxonomies_attribute_types.status IS 'Active or inactive. Inactive can be set up manually by user if they don''t want attribute type to be active. Default is active';
COMMENT ON COLUMN silver_taxonomies_attribute_types.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_taxonomies_attribute_types.last_updated_at IS 'Timestamp when the row was last updated';
COMMENT ON COLUMN silver_taxonomies_attribute_types.load_id IS 'Foreign key to bronze_load_details table';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    -- Check load_id column exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_taxonomies_attribute_types'
        AND column_name = 'load_id'
    ) THEN
        RAISE EXCEPTION 'Migration 018 failed: load_id column not created';
    END IF;

    -- Check foreign key exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_attr_types_load'
    ) THEN
        RAISE EXCEPTION 'Migration 018 failed: Foreign key constraint not created';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 018: Silver Attribute Types Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Column Added: 1';
    RAISE NOTICE '  - load_id (INTEGER, FK to bronze_load_details)';
    RAISE NOTICE 'New Index Created: 1';
    RAISE NOTICE 'Constraints Added: 1 FK';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
