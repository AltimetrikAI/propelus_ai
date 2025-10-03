-- Migration 009: September 29, 2025 Meeting Updates
-- Purpose: Implement changes from architecture simplification meeting
-- - Add optional file_url tracking to bronze layer
-- - Add versioning and active flags for remapping support
-- - Add request_id tracking for async operations
-- - Prepare for simplified customer taxonomy model

-- =============================================================================
-- BRONZE LAYER UPDATES
-- =============================================================================

-- Add optional file_url to bronze tables for file-based ingestion tracking
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS file_url VARCHAR(500),
ADD COLUMN IF NOT EXISTS request_id VARCHAR(100);

ALTER TABLE bronze_professions
ADD COLUMN IF NOT EXISTS file_url VARCHAR(500),
ADD COLUMN IF NOT EXISTS request_id VARCHAR(100);

-- Add index for request_id lookups
CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_request_id
ON bronze_taxonomies(request_id) WHERE request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bronze_professions_request_id
ON bronze_professions(request_id) WHERE request_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN bronze_taxonomies.file_url IS 'Optional URL/path to source file if data came from file upload';
COMMENT ON COLUMN bronze_taxonomies.request_id IS 'Unique request identifier for tracking async operations';
COMMENT ON COLUMN bronze_professions.file_url IS 'Optional URL/path to source file if data came from file upload';
COMMENT ON COLUMN bronze_professions.request_id IS 'Unique request identifier for tracking async operations';

-- =============================================================================
-- SILVER LAYER MAPPING UPDATES - REMAPPING SUPPORT
-- =============================================================================

-- Add versioning and active status to taxonomy mappings for remapping support
ALTER TABLE silver_mapping_taxonomies
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS mapping_version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS superseded_by_mapping_id INTEGER REFERENCES silver_mapping_taxonomies(mapping_id),
ADD COLUMN IF NOT EXISTS remapped_at TIMESTAMP;

-- Add versioning to profession mappings
ALTER TABLE silver_mapping_professions
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS mapping_version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS superseded_by_mapping_id INTEGER REFERENCES silver_mapping_professions(mapping_id),
ADD COLUMN IF NOT EXISTS remapped_at TIMESTAMP;

-- Add indexes for remapping queries
CREATE INDEX IF NOT EXISTS idx_silver_mapping_taxonomies_active_version
ON silver_mapping_taxonomies(is_active, mapping_version) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_silver_mapping_professions_active_version
ON silver_mapping_professions(is_active, mapping_version) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_silver_mapping_taxonomies_superseded
ON silver_mapping_taxonomies(superseded_by_mapping_id) WHERE superseded_by_mapping_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_silver_mapping_professions_superseded
ON silver_mapping_professions(superseded_by_mapping_id) WHERE superseded_by_mapping_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN silver_mapping_taxonomies.is_active IS 'TRUE if this is the current active mapping, FALSE if superseded by newer version';
COMMENT ON COLUMN silver_mapping_taxonomies.mapping_version IS 'Version number for tracking mapping evolution over time';
COMMENT ON COLUMN silver_mapping_taxonomies.superseded_by_mapping_id IS 'Reference to newer mapping that replaced this one during remapping';
COMMENT ON COLUMN silver_mapping_taxonomies.remapped_at IS 'Timestamp when this mapping was remapped/superseded';

COMMENT ON COLUMN silver_mapping_professions.is_active IS 'TRUE if this is the current active mapping, FALSE if superseded by newer version';
COMMENT ON COLUMN silver_mapping_professions.mapping_version IS 'Version number for tracking mapping evolution over time';
COMMENT ON COLUMN silver_mapping_professions.superseded_by_mapping_id IS 'Reference to newer mapping that replaced this one during remapping';
COMMENT ON COLUMN silver_mapping_professions.remapped_at IS 'Timestamp when this mapping was remapped/superseded';

-- =============================================================================
-- MASTER TAXONOMY VERSION TRACKING
-- =============================================================================

-- Add version tracking to master taxonomy for remapping traceability
ALTER TABLE silver_taxonomies
ADD COLUMN IF NOT EXISTS taxonomy_version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS version_notes TEXT,
ADD COLUMN IF NOT EXISTS version_effective_date TIMESTAMP;

-- Create taxonomy version history table
CREATE TABLE IF NOT EXISTS silver_taxonomies_version_history (
    version_history_id SERIAL PRIMARY KEY,
    taxonomy_id INTEGER NOT NULL REFERENCES silver_taxonomies(taxonomy_id),
    previous_version INTEGER NOT NULL,
    new_version INTEGER NOT NULL,
    change_type VARCHAR(50) NOT NULL, -- 'node_added', 'node_modified', 'node_removed', 'attribute_changed'
    affected_nodes JSONB, -- List of node_ids affected by this version change
    change_description TEXT,
    changed_by VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_change_type CHECK (change_type IN ('node_added', 'node_modified', 'node_removed', 'attribute_changed', 'structure_change'))
);

CREATE INDEX IF NOT EXISTS idx_taxonomy_version_history_taxonomy
ON silver_taxonomies_version_history(taxonomy_id, new_version);

COMMENT ON TABLE silver_taxonomies_version_history IS 'Tracks changes to master taxonomy for remapping and audit purposes';

-- =============================================================================
-- REMAPPING AUDIT TABLE
-- =============================================================================

-- Track remapping operations for audit and analysis
CREATE TABLE IF NOT EXISTS silver_remapping_log (
    remapping_id SERIAL PRIMARY KEY,
    taxonomy_id INTEGER NOT NULL REFERENCES silver_taxonomies(taxonomy_id),
    trigger_reason VARCHAR(100) NOT NULL, -- 'master_taxonomy_updated', 'manual_trigger', 'rule_change'
    from_version INTEGER NOT NULL,
    to_version INTEGER NOT NULL,
    total_mappings_processed INTEGER,
    mappings_changed INTEGER,
    mappings_unchanged INTEGER,
    mappings_failed INTEGER,
    processing_started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_completed_at TIMESTAMP,
    processing_status VARCHAR(20) DEFAULT 'in_progress', -- 'in_progress', 'completed', 'failed', 'partial'
    triggered_by VARCHAR(255),
    notes TEXT,
    CONSTRAINT valid_remapping_status CHECK (processing_status IN ('in_progress', 'completed', 'failed', 'partial'))
);

CREATE INDEX IF NOT EXISTS idx_remapping_log_taxonomy_version
ON silver_remapping_log(taxonomy_id, to_version);

CREATE INDEX IF NOT EXISTS idx_remapping_log_status
ON silver_remapping_log(processing_status, processing_started_at);

COMMENT ON TABLE silver_remapping_log IS 'Audit log of remapping operations when master taxonomy is updated';

-- =============================================================================
-- GOLD LAYER UPDATES
-- =============================================================================

-- Add versioning to gold layer for production mapping tracking
ALTER TABLE gold_taxonomies_mapping
ADD COLUMN IF NOT EXISTS mapping_version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS promoted_from_mapping_id INTEGER;

ALTER TABLE gold_mapping_professions
ADD COLUMN IF NOT EXISTS mapping_version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS promoted_from_mapping_id INTEGER;

-- Add comments
COMMENT ON COLUMN gold_taxonomies_mapping.mapping_version IS 'Version of the mapping when promoted to gold';
COMMENT ON COLUMN gold_taxonomies_mapping.promoted_from_mapping_id IS 'Original silver layer mapping_id that was promoted';

COMMENT ON COLUMN gold_mapping_professions.mapping_version IS 'Version of the mapping when promoted to gold';
COMMENT ON COLUMN gold_mapping_professions.promoted_from_mapping_id IS 'Original silver layer mapping_id that was promoted';

-- =============================================================================
-- UPDATE BRONZE LOAD DETAILS FOR IMPROVED TRACKING
-- =============================================================================

-- Enhance bronze_load_details with request tracking
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS request_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS source_system VARCHAR(100), -- 'api', 'file_upload', 'admin_ui', 'batch_import'
ADD COLUMN IF NOT EXISTS callback_url VARCHAR(500); -- For async webhook notifications

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_request_id
ON bronze_load_details(request_id) WHERE request_id IS NOT NULL;

COMMENT ON COLUMN bronze_load_details.request_id IS 'Unique request identifier for async operation tracking';
COMMENT ON COLUMN bronze_load_details.source_system IS 'System that initiated the load operation';
COMMENT ON COLUMN bronze_load_details.callback_url IS 'Optional webhook URL for async completion notification';

-- =============================================================================
-- VIEW: ACTIVE MAPPINGS ONLY
-- =============================================================================

-- Create view for active mappings to simplify queries
CREATE OR REPLACE VIEW v_active_taxonomy_mappings AS
SELECT
    mapping_id,
    mapping_rule_id,
    target_node_id,
    child_node_id,
    confidence,
    status,
    mapping_version,
    created_at,
    last_updated_at,
    user_created
FROM silver_mapping_taxonomies
WHERE is_active = TRUE;

CREATE OR REPLACE VIEW v_active_profession_mappings AS
SELECT
    mapping_id,
    mapping_rule_id,
    node_id,
    profession_id,
    status,
    mapping_version,
    created_at,
    last_updated_at
FROM silver_mapping_professions
WHERE is_active = TRUE;

COMMENT ON VIEW v_active_taxonomy_mappings IS 'Current active taxonomy mappings only (latest versions)';
COMMENT ON VIEW v_active_profession_mappings IS 'Current active profession mappings only (latest versions)';

-- =============================================================================
-- MIGRATION VERIFICATION
-- =============================================================================

-- Verify all columns were added successfully
DO $$
DECLARE
    missing_columns TEXT := '';
BEGIN
    -- Check bronze_taxonomies
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_taxonomies' AND column_name = 'file_url') THEN
        missing_columns := missing_columns || 'bronze_taxonomies.file_url, ';
    END IF;

    -- Check silver_mapping_taxonomies
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'silver_mapping_taxonomies' AND column_name = 'is_active') THEN
        missing_columns := missing_columns || 'silver_mapping_taxonomies.is_active, ';
    END IF;

    -- Check if remapping_log table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_name = 'silver_remapping_log') THEN
        missing_columns := missing_columns || 'silver_remapping_log table, ';
    END IF;

    IF LENGTH(missing_columns) > 0 THEN
        RAISE EXCEPTION 'Migration incomplete. Missing: %', missing_columns;
    ELSE
        RAISE NOTICE 'Migration 009 completed successfully - All changes applied';
    END IF;
END $$;

-- =============================================================================
-- DATA MIGRATION: SET DEFAULTS FOR EXISTING RECORDS
-- =============================================================================

-- Set all existing mappings as active and version 1
UPDATE silver_mapping_taxonomies
SET is_active = TRUE, mapping_version = 1
WHERE is_active IS NULL;

UPDATE silver_mapping_professions
SET is_active = TRUE, mapping_version = 1
WHERE is_active IS NULL;

-- Set taxonomy version for master taxonomy
UPDATE silver_taxonomies
SET taxonomy_version = 1, version_effective_date = created_at
WHERE customer_id = -1 AND taxonomy_version IS NULL;

-- =============================================================================
-- SUMMARY
-- =============================================================================
-- Migration 009 implements:
-- 1. ✅ Optional file_url tracking in bronze layer
-- 2. ✅ Request ID tracking for async operations
-- 3. ✅ Versioning system for mappings (remapping support)
-- 4. ✅ Active/inactive flags for mapping lifecycle
-- 5. ✅ Master taxonomy version tracking
-- 6. ✅ Remapping audit log
-- 7. ✅ Enhanced gold layer with version tracking
-- 8. ✅ Views for active mappings
-- =============================================================================