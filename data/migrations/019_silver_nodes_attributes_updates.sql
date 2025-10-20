-- ============================================================================
-- Migration 019: Silver Taxonomies Nodes Attributes Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_taxonomies_nodes_attributes table per data engineer spec
--              - Rename attribute_id to node_attribute_type_id
--              - Rename name column to attribute_type_id
--              - Add status column
--              - Add load_id and row_id foreign keys
-- ============================================================================

BEGIN;

-- ============================================================================
-- RENAME PRIMARY KEY COLUMN
-- ============================================================================

-- Rename attribute_id to node_attribute_type_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_taxonomies_nodes_attributes'
        AND column_name = 'attribute_id'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_taxonomies_nodes_attributes'
        AND column_name = 'node_attribute_type_id'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes_attributes
        RENAME COLUMN attribute_id TO node_attribute_type_id;
    END IF;
END $$;

-- ============================================================================
-- ADD attribute_type_id COLUMN AND MIGRATE DATA
-- ============================================================================

-- Add attribute_type_id column (will become FK to silver_taxonomies_attribute_types)
ALTER TABLE silver_taxonomies_nodes_attributes
ADD COLUMN IF NOT EXISTS attribute_type_id INTEGER;

-- Note: Data migration for attribute_type_id would need to be done separately
-- based on matching the old 'name' column to silver_taxonomies_attribute_types.name

-- ============================================================================
-- ADD FOREIGN KEY FOR attribute_type_id
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_attr_type'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes_attributes
        ADD CONSTRAINT fk_silver_nodes_attr_type
        FOREIGN KEY (attribute_type_id) REFERENCES silver_taxonomies_attribute_types(attribute_type_id);
    END IF;
END $$;

-- ============================================================================
-- ADD OTHER NEW COLUMNS
-- ============================================================================

-- Add status column
ALTER TABLE silver_taxonomies_nodes_attributes
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

-- Add check constraint for status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_silver_nodes_attr_status'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes_attributes
        ADD CONSTRAINT chk_silver_nodes_attr_status
        CHECK (status IN ('active', 'inactive'));
    END IF;
END $$;

-- Add load_id foreign key
ALTER TABLE silver_taxonomies_nodes_attributes
ADD COLUMN IF NOT EXISTS load_id INTEGER;

-- Add foreign key constraint for load_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_attr_load'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes_attributes
        ADD CONSTRAINT fk_silver_nodes_attr_load
        FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);
    END IF;
END $$;

-- Add row_id foreign key
ALTER TABLE silver_taxonomies_nodes_attributes
ADD COLUMN IF NOT EXISTS row_id INTEGER;

-- Add foreign key constraint for row_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_silver_nodes_attr_row'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes_attributes
        ADD CONSTRAINT fk_silver_nodes_attr_row
        FOREIGN KEY (row_id) REFERENCES bronze_taxonomies(row_id);
    END IF;
END $$;

-- ============================================================================
-- CREATE INDEXES FOR NEW COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_nodes_attr_type_id
ON silver_taxonomies_nodes_attributes(attribute_type_id);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_attr_status
ON silver_taxonomies_nodes_attributes(status);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_attr_load
ON silver_taxonomies_nodes_attributes(load_id);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_attr_row
ON silver_taxonomies_nodes_attributes(row_id);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_attr_node_type
ON silver_taxonomies_nodes_attributes(node_id, attribute_type_id);

CREATE INDEX IF NOT EXISTS idx_silver_nodes_attr_status_active
ON silver_taxonomies_nodes_attributes(status) WHERE status = 'active';

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_taxonomies_nodes_attributes IS 'Stores attributes assigned to taxonomy nodes, one or many attributes of the same type can be attached to the node';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.node_attribute_type_id IS 'Primary surrogate key - ID of the connection between node and attribute_type';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.attribute_type_id IS 'Foreign key to silver_taxonomies_attribute_types';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.node_id IS 'Foreign key to silver_taxonomies_nodes';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.value IS 'Attribute value (for example: CA, FL, WY, UT)';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.status IS 'Active or inactive. Inactive can be set up manually by user if they don''t want node attribute to be active. Default is active';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.last_updated_at IS 'Timestamp when the row was last updated';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.load_id IS 'Foreign key to bronze_load_details table';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.row_id IS 'Foreign key to bronze_taxonomies table';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
BEGIN
    -- Check new columns exist
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'silver_taxonomies_nodes_attributes'
    AND column_name IN ('node_attribute_type_id', 'attribute_type_id', 'status', 'load_id', 'row_id');

    IF col_count <> 5 THEN
        RAISE EXCEPTION 'Migration 019 failed: Expected 5 columns, found %', col_count;
    END IF;

    -- Check foreign keys exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname IN ('fk_silver_nodes_attr_type', 'fk_silver_nodes_attr_load', 'fk_silver_nodes_attr_row')
    ) THEN
        RAISE WARNING 'Migration 019: Some foreign keys may be missing';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 019: Silver Nodes Attributes Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Columns Renamed: 1';
    RAISE NOTICE '  - attribute_id → node_attribute_type_id';
    RAISE NOTICE 'New Columns Added: 4';
    RAISE NOTICE '  - attribute_type_id (INTEGER, FK to silver_taxonomies_attribute_types)';
    RAISE NOTICE '  - status (VARCHAR(20), default active)';
    RAISE NOTICE '  - load_id (INTEGER, FK to bronze_load_details)';
    RAISE NOTICE '  - row_id (INTEGER, FK to bronze_taxonomies)';
    RAISE NOTICE 'New Indexes Created: 6';
    RAISE NOTICE 'Constraints Added: 3 FK, 1 CHECK';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'NOTE: Data migration for attribute_type_id may be required';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
