-- ============================================================================
-- Migration 020: Create silver_taxonomies_versions Table
-- ============================================================================
-- Date: 2025-01-26
-- Description: Create silver_taxonomies_versions table per data engineer spec
--              Tracks versions of taxonomies over time, including structural changes,
--              affected elements, and the impact on mappings
-- ============================================================================

BEGIN;

-- ============================================================================
-- CREATE silver_taxonomies_versions TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS silver_taxonomies_versions (
    taxonomy_version_id SERIAL PRIMARY KEY,
    taxonomy_id INTEGER NOT NULL,
    taxonomy_version_number INTEGER NOT NULL,
    change_type VARCHAR(100),
    affected_nodes JSONB,
    affected_attributes JSONB,
    remapping_flag BOOLEAN DEFAULT FALSE,
    remapping_reason TEXT,
    total_mappings_processed INTEGER DEFAULT 0,
    total_mappings_changed INTEGER DEFAULT 0,
    total_mappings_unchanged INTEGER DEFAULT 0,
    total_mappings_failed INTEGER DEFAULT 0,
    total_mappings_new INTEGER DEFAULT 0,
    remapping_proces_status VARCHAR(50),
    version_notes TEXT,
    version_from_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    version_to_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    load_id INTEGER
);

-- ============================================================================
-- ADD FOREIGN KEY CONSTRAINTS
-- ============================================================================

-- Foreign key to silver_taxonomies
ALTER TABLE silver_taxonomies_versions
ADD CONSTRAINT fk_silver_tax_versions_taxonomy
FOREIGN KEY (taxonomy_id) REFERENCES silver_taxonomies(taxonomy_id);

-- Foreign key to bronze_load_details
ALTER TABLE silver_taxonomies_versions
ADD CONSTRAINT fk_silver_tax_versions_load
FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);

-- ============================================================================
-- ADD CHECK CONSTRAINTS
-- ============================================================================

-- Check constraint for remapping_proces_status
ALTER TABLE silver_taxonomies_versions
ADD CONSTRAINT chk_silver_tax_versions_status
CHECK (remapping_proces_status IN ('in progress', 'completed', 'failed', NULL));

-- Check constraint for version numbers
ALTER TABLE silver_taxonomies_versions
ADD CONSTRAINT chk_silver_tax_versions_number
CHECK (taxonomy_version_number > 0);

-- Ensure mapping totals are non-negative
ALTER TABLE silver_taxonomies_versions
ADD CONSTRAINT chk_silver_tax_versions_mappings_positive
CHECK (
    total_mappings_processed >= 0 AND
    total_mappings_changed >= 0 AND
    total_mappings_unchanged >= 0 AND
    total_mappings_failed >= 0 AND
    total_mappings_new >= 0
);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

CREATE INDEX idx_silver_tax_versions_taxonomy
ON silver_taxonomies_versions(taxonomy_id);

CREATE INDEX idx_silver_tax_versions_number
ON silver_taxonomies_versions(taxonomy_id, taxonomy_version_number);

CREATE INDEX idx_silver_tax_versions_load
ON silver_taxonomies_versions(load_id);

CREATE INDEX idx_silver_tax_versions_from_date
ON silver_taxonomies_versions(version_from_date DESC);

CREATE INDEX idx_silver_tax_versions_to_date
ON silver_taxonomies_versions(version_to_date DESC);

CREATE INDEX idx_silver_tax_versions_remapping
ON silver_taxonomies_versions(remapping_flag);

CREATE INDEX idx_silver_tax_versions_status
ON silver_taxonomies_versions(remapping_proces_status);

CREATE INDEX idx_silver_tax_versions_current
ON silver_taxonomies_versions(taxonomy_id, version_to_date)
WHERE version_to_date IS NULL;

-- ============================================================================
-- ADD UNIQUE CONSTRAINT
-- ============================================================================

-- Ensure unique version numbers per taxonomy
CREATE UNIQUE INDEX idx_silver_tax_versions_unique
ON silver_taxonomies_versions(taxonomy_id, taxonomy_version_number);

-- ============================================================================
-- ADD COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_taxonomies_versions IS 'Tracks versions of taxonomies over time, including structural changes, affected elements, and the impact on mappings. This table provides a history of taxonomy evolution and supports remapping workflows';

COMMENT ON COLUMN silver_taxonomies_versions.taxonomy_version_id IS 'Unique identifier for the taxonomy version';
COMMENT ON COLUMN silver_taxonomies_versions.taxonomy_id IS 'Foreign key to silver_taxonomies. Reference to the taxonomy being versioned';
COMMENT ON COLUMN silver_taxonomies_versions.taxonomy_version_number IS 'Sequential version number for the taxonomy';
COMMENT ON COLUMN silver_taxonomies_versions.change_type IS 'Type of change in this version (e.g., nodes added, attributes added, nodes deleted)';
COMMENT ON COLUMN silver_taxonomies_versions.affected_nodes IS 'List of nodes in taxonomy impacted by the change, with details of the type of change (new, deleted)';
COMMENT ON COLUMN silver_taxonomies_versions.affected_attributes IS 'List of attributes impacted by the change, with details of the type of change (new, deleted)';
COMMENT ON COLUMN silver_taxonomies_versions.remapping_flag IS 'Boolean/indicator whether remapping is required due to the change. Default is False';
COMMENT ON COLUMN silver_taxonomies_versions.remapping_reason IS 'Explanation for why remapping was needed. Default is False';
COMMENT ON COLUMN silver_taxonomies_versions.total_mappings_processed IS 'Total number of mappings processed during the version update. For initial creation it is zero';
COMMENT ON COLUMN silver_taxonomies_versions.total_mappings_changed IS 'Number of mappings that were modified. For initial creation it is zero';
COMMENT ON COLUMN silver_taxonomies_versions.total_mappings_unchanged IS 'Number of mappings unaffected by the version change. For initial creation it is zero';
COMMENT ON COLUMN silver_taxonomies_versions.total_mappings_failed IS 'Number of mappings that failed during processing. For initial creation it is zero';
COMMENT ON COLUMN silver_taxonomies_versions.total_mappings_new IS 'Number of new mappings created. For initial creation it is zero';
COMMENT ON COLUMN silver_taxonomies_versions.remapping_proces_status IS 'Status of the remapping process (e.g., in progress, completed, failed, NULL). For initial creation it will be always NULL';
COMMENT ON COLUMN silver_taxonomies_versions.version_notes IS 'Free-text notes about this version. Default is null, can be added manually by user';
COMMENT ON COLUMN silver_taxonomies_versions.version_from_date IS 'Date when this version became effective';
COMMENT ON COLUMN silver_taxonomies_versions.version_to_date IS 'Date when this version was superseded or closed (null if current). It should be updated for older version row, for creating a version it will always be NULL';
COMMENT ON COLUMN silver_taxonomies_versions.created_at IS 'Timestamp when this version record was created';
COMMENT ON COLUMN silver_taxonomies_versions.last_updated_at IS 'Timestamp when this version record was last modified';
COMMENT ON COLUMN silver_taxonomies_versions.load_id IS 'Foreign key to the bronze_load_details table. Reference to the ingestion/load event that generated this version';

-- ============================================================================
-- CREATE TRIGGER FOR last_updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_silver_tax_versions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_silver_tax_versions_timestamp
BEFORE UPDATE ON silver_taxonomies_versions
FOR EACH ROW
EXECUTE FUNCTION update_silver_tax_versions_timestamp();

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
        WHERE table_name = 'silver_taxonomies_versions'
    ) THEN
        RAISE EXCEPTION 'Migration 020 failed: Table silver_taxonomies_versions not created';
    END IF;

    -- Check column count
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'silver_taxonomies_versions';

    IF col_count <> 20 THEN
        RAISE WARNING 'Migration 020: Expected 20 columns, found %', col_count;
    END IF;

    -- Check indexes
    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE tablename = 'silver_taxonomies_versions';

    IF idx_count < 8 THEN
        RAISE WARNING 'Migration 020: Expected at least 8 indexes, found %', idx_count;
    END IF;

    -- Check foreign keys
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname IN ('fk_silver_tax_versions_taxonomy', 'fk_silver_tax_versions_load')
    ) THEN
        RAISE WARNING 'Migration 020: Some foreign keys may be missing';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 020: silver_taxonomies_versions - CREATED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Table Created: silver_taxonomies_versions';
    RAISE NOTICE 'Columns: 20';
    RAISE NOTICE 'Indexes: % (including unique constraint)', idx_count;
    RAISE NOTICE 'Foreign Keys: 2 (taxonomy_id, load_id)';
    RAISE NOTICE 'Check Constraints: 3';
    RAISE NOTICE 'Triggers: 1 (auto-update last_updated_at)';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'This table tracks taxonomy version history and supports remapping workflows';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
