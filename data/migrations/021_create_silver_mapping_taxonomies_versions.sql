-- ============================================================================
-- Migration 021: Create silver_mapping_taxonomies_versions Table
-- ============================================================================
-- Date: 2025-01-26
-- Description: Create silver_mapping_taxonomies_versions table per data engineer spec
--              Tracks versions of taxonomy mappings over time, including affected
--              elements and impacted mappings
-- ============================================================================

BEGIN;

-- ============================================================================
-- CREATE silver_mapping_taxonomies_versions TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS silver_mapping_taxonomies_versions (
    mapping_version_id SERIAL PRIMARY KEY,
    mapping_id INTEGER NOT NULL,
    mapping_version_number INTEGER NOT NULL,
    version_from_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    version_to_date TIMESTAMP WITH TIME ZONE,
    superseded_by_mapping_id INTEGER,
    superseded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ADD FOREIGN KEY CONSTRAINTS
-- ============================================================================

-- Foreign key to silver_mapping_taxonomies (current mapping)
ALTER TABLE silver_mapping_taxonomies_versions
ADD CONSTRAINT fk_silver_mapping_versions_current
FOREIGN KEY (mapping_id) REFERENCES silver_mapping_taxonomies(mapping_id);

-- Foreign key to silver_mapping_taxonomies (superseding mapping)
ALTER TABLE silver_mapping_taxonomies_versions
ADD CONSTRAINT fk_silver_mapping_versions_superseded
FOREIGN KEY (superseded_by_mapping_id) REFERENCES silver_mapping_taxonomies(mapping_id);

-- ============================================================================
-- ADD CHECK CONSTRAINTS
-- ============================================================================

-- Check constraint for version numbers
ALTER TABLE silver_mapping_taxonomies_versions
ADD CONSTRAINT chk_silver_mapping_versions_number
CHECK (mapping_version_number > 0);

-- Check constraint for date logic
ALTER TABLE silver_mapping_taxonomies_versions
ADD CONSTRAINT chk_silver_mapping_versions_dates
CHECK (version_to_date IS NULL OR version_to_date >= version_from_date);

-- Check constraint for superseded logic
ALTER TABLE silver_mapping_taxonomies_versions
ADD CONSTRAINT chk_silver_mapping_versions_superseded
CHECK (
    (superseded_by_mapping_id IS NULL AND superseded_at IS NULL) OR
    (superseded_by_mapping_id IS NOT NULL AND superseded_at IS NOT NULL)
);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

CREATE INDEX idx_silver_mapping_versions_mapping
ON silver_mapping_taxonomies_versions(mapping_id);

CREATE INDEX idx_silver_mapping_versions_number
ON silver_mapping_taxonomies_versions(mapping_id, mapping_version_number);

CREATE INDEX idx_silver_mapping_versions_from_date
ON silver_mapping_taxonomies_versions(version_from_date DESC);

CREATE INDEX idx_silver_mapping_versions_to_date
ON silver_mapping_taxonomies_versions(version_to_date DESC);

CREATE INDEX idx_silver_mapping_versions_superseded_by
ON silver_mapping_taxonomies_versions(superseded_by_mapping_id);

CREATE INDEX idx_silver_mapping_versions_superseded_at
ON silver_mapping_taxonomies_versions(superseded_at DESC);

CREATE INDEX idx_silver_mapping_versions_current
ON silver_mapping_taxonomies_versions(mapping_id, version_to_date)
WHERE version_to_date IS NULL;

-- ============================================================================
-- ADD UNIQUE CONSTRAINT
-- ============================================================================

-- Ensure unique version numbers per mapping
CREATE UNIQUE INDEX idx_silver_mapping_versions_unique
ON silver_mapping_taxonomies_versions(mapping_id, mapping_version_number);

-- ============================================================================
-- ADD COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_mapping_taxonomies_versions IS 'Tracks versions of taxonomy mappings over time, including affected elements and impacted mappings. This table provides a history of taxonomy mapping evolution';

COMMENT ON COLUMN silver_mapping_taxonomies_versions.mapping_version_id IS 'Primary surrogate key – mapping version ID';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.mapping_id IS 'Foreign key to current mapping in silver_mapping_taxonomies';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.mapping_version_number IS 'Sequential version number for the taxonomy mapping';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.version_from_date IS 'Date when this version became effective';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.version_to_date IS 'Date when this version was superseded or closed (null if current). It should be updated for older version row, for creating a version it will always be NULL';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.superseded_by_mapping_id IS 'Foreign key to previous version mapping in silver_mapping_taxonomies';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.superseded_at IS 'Timestamp indicates when this version of mapping was superseded';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_mapping_taxonomies_versions.last_updated_at IS 'Timestamp when the row was last updated';

-- ============================================================================
-- CREATE TRIGGER FOR last_updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_silver_mapping_versions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_silver_mapping_versions_timestamp
BEFORE UPDATE ON silver_mapping_taxonomies_versions
FOR EACH ROW
EXECUTE FUNCTION update_silver_mapping_versions_timestamp();

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
        WHERE table_name = 'silver_mapping_taxonomies_versions'
    ) THEN
        RAISE EXCEPTION 'Migration 021 failed: Table silver_mapping_taxonomies_versions not created';
    END IF;

    -- Check column count
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'silver_mapping_taxonomies_versions';

    IF col_count <> 9 THEN
        RAISE WARNING 'Migration 021: Expected 9 columns, found %', col_count;
    END IF;

    -- Check indexes
    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE tablename = 'silver_mapping_taxonomies_versions';

    IF idx_count < 7 THEN
        RAISE WARNING 'Migration 021: Expected at least 7 indexes, found %', idx_count;
    END IF;

    -- Check foreign keys
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname IN ('fk_silver_mapping_versions_current', 'fk_silver_mapping_versions_superseded')
    ) THEN
        RAISE WARNING 'Migration 021: Some foreign keys may be missing';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 021: silver_mapping_taxonomies_versions - CREATED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Table Created: silver_mapping_taxonomies_versions';
    RAISE NOTICE 'Columns: 9';
    RAISE NOTICE 'Indexes: % (including unique constraint)', idx_count;
    RAISE NOTICE 'Foreign Keys: 2 (mapping_id, superseded_by_mapping_id)';
    RAISE NOTICE 'Check Constraints: 3';
    RAISE NOTICE 'Triggers: 1 (auto-update last_updated_at)';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'This table tracks mapping version history and supersession relationships';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
