-- Migration 011: Martin's Bronze Layer Enhancements
-- Purpose: Implement Martin's proposed changes from Sept 30 meeting
-- - Add load_id identifier to bronze_load_details
-- - Add load_status for granular load tracking
-- - Add load_active flag for "withdraw without deletion"
-- - Add row_id and row_active to bronze data tables
-- - Enable soft-delete/deactivation workflows

-- =============================================================================
-- BRONZE_LOAD_DETAILS ENHANCEMENTS
-- =============================================================================

-- Add load_id as explicit identifier (currently using auto-generated ID)
-- Note: bronze_load_details already has a primary key, but adding load_id for external reference
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_id VARCHAR(100) UNIQUE;

-- Add load_status for granular tracking
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_status VARCHAR(50) DEFAULT 'pending';

-- Add load_active flag for soft deletion
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_active BOOLEAN DEFAULT TRUE;

-- Add constraint for valid load statuses
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_bronze_load_status'
    ) THEN
        ALTER TABLE bronze_load_details
        ADD CONSTRAINT chk_bronze_load_status
        CHECK (load_status IN ('pending', 'processing', 'successful', 'partially_successful', 'failed'));
    END IF;
END $$;

-- Create index for load_id lookups
CREATE INDEX IF NOT EXISTS idx_bronze_load_details_load_id
ON bronze_load_details(load_id) WHERE load_id IS NOT NULL;

-- Create index for active loads
CREATE INDEX IF NOT EXISTS idx_bronze_load_details_active
ON bronze_load_details(load_active, load_status) WHERE load_active = TRUE;

-- Add comments
COMMENT ON COLUMN bronze_load_details.load_id IS 'External load identifier for tracking and reference';
COMMENT ON COLUMN bronze_load_details.load_status IS 'Granular load status: pending, processing, successful, partially_successful, failed';
COMMENT ON COLUMN bronze_load_details.load_active IS 'FALSE allows withdrawing/deactivating a load without physical deletion';

-- =============================================================================
-- BRONZE_TAXONOMIES ROW-LEVEL TRACKING
-- =============================================================================

-- Add row_id for explicit row identification
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS row_id VARCHAR(100);

-- Add row_active flag for soft deletion
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS row_active BOOLEAN DEFAULT TRUE;

-- Link rows to specific load_id
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS load_id VARCHAR(100);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_row_id
ON bronze_taxonomies(row_id) WHERE row_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_row_active
ON bronze_taxonomies(row_active, load_id) WHERE row_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_load_id
ON bronze_taxonomies(load_id) WHERE load_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN bronze_taxonomies.row_id IS 'Unique row identifier within a load batch';
COMMENT ON COLUMN bronze_taxonomies.row_active IS 'FALSE allows deactivating individual rows without deletion';
COMMENT ON COLUMN bronze_taxonomies.load_id IS 'References the load_id from bronze_load_details';

-- =============================================================================
-- BRONZE_PROFESSIONS ROW-LEVEL TRACKING
-- =============================================================================

-- Add row_id for explicit row identification
ALTER TABLE bronze_professions
ADD COLUMN IF NOT EXISTS row_id VARCHAR(100);

-- Add row_active flag for soft deletion
ALTER TABLE bronze_professions
ADD COLUMN IF NOT EXISTS row_active BOOLEAN DEFAULT TRUE;

-- Link rows to specific load_id
ALTER TABLE bronze_professions
ADD COLUMN IF NOT EXISTS load_id VARCHAR(100);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_bronze_professions_row_id
ON bronze_professions(row_id) WHERE row_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bronze_professions_row_active
ON bronze_professions(row_active, load_id) WHERE row_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_bronze_professions_load_id
ON bronze_professions(load_id) WHERE load_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN bronze_professions.row_id IS 'Unique row identifier within a load batch';
COMMENT ON COLUMN bronze_professions.row_active IS 'FALSE allows deactivating individual rows without deletion';
COMMENT ON COLUMN bronze_professions.load_id IS 'References the load_id from bronze_load_details';

-- =============================================================================
-- SILVER LAYER LOAD TRACKING
-- =============================================================================

-- Add load_id reference to silver tables for lineage tracking
ALTER TABLE silver_taxonomies
ADD COLUMN IF NOT EXISTS source_load_id VARCHAR(100);

ALTER TABLE silver_professions
ADD COLUMN IF NOT EXISTS source_load_id VARCHAR(100);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_silver_taxonomies_load_id
ON silver_taxonomies(source_load_id) WHERE source_load_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_silver_professions_load_id
ON silver_professions(source_load_id) WHERE source_load_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN silver_taxonomies.source_load_id IS 'Tracks which bronze load this silver record originated from';
COMMENT ON COLUMN silver_professions.source_load_id IS 'Tracks which bronze load this silver record originated from';

-- =============================================================================
-- VIEWS FOR ACTIVE DATA ONLY
-- =============================================================================

-- View for active bronze taxonomies (filtered by both load_active and row_active)
CREATE OR REPLACE VIEW v_bronze_taxonomies_active AS
SELECT
    bt.bronze_taxonomy_id,
    bt.customer_id,
    bt.row_json,
    bt.load_date,
    bt.file_url,
    bt.request_id,
    bt.row_id,
    bt.load_id,
    bld.load_status,
    bld.load_type
FROM bronze_taxonomies bt
INNER JOIN bronze_load_details bld
    ON bt.load_id = bld.load_id
WHERE bt.row_active = TRUE
  AND bld.load_active = TRUE;

COMMENT ON VIEW v_bronze_taxonomies_active IS 'Shows only active bronze taxonomy rows (both row and load must be active)';

-- View for active bronze professions
CREATE OR REPLACE VIEW v_bronze_professions_active AS
SELECT
    bp.bronze_profession_id,
    bp.customer_id,
    bp.row_json,
    bp.load_date,
    bp.file_url,
    bp.request_id,
    bp.row_id,
    bp.load_id,
    bld.load_status,
    bld.load_type
FROM bronze_professions bp
INNER JOIN bronze_load_details bld
    ON bp.load_id = bld.load_id
WHERE bp.row_active = TRUE
  AND bld.load_active = TRUE;

COMMENT ON VIEW v_bronze_professions_active IS 'Shows only active bronze profession rows (both row and load must be active)';

-- =============================================================================
-- HELPER FUNCTIONS FOR LOAD MANAGEMENT
-- =============================================================================

-- Function to deactivate an entire load (soft delete)
CREATE OR REPLACE FUNCTION deactivate_bronze_load(p_load_id VARCHAR)
RETURNS TABLE (
    rows_affected_taxonomies INTEGER,
    rows_affected_professions INTEGER
) AS $$
DECLARE
    v_tax_count INTEGER;
    v_prof_count INTEGER;
BEGIN
    -- Deactivate the load
    UPDATE bronze_load_details
    SET load_active = FALSE,
        load_status = 'withdrawn'
    WHERE load_id = p_load_id;

    -- Count affected rows in taxonomies
    SELECT COUNT(*) INTO v_tax_count
    FROM bronze_taxonomies
    WHERE load_id = p_load_id;

    -- Count affected rows in professions
    SELECT COUNT(*) INTO v_prof_count
    FROM bronze_professions
    WHERE load_id = p_load_id;

    RETURN QUERY SELECT v_tax_count, v_prof_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION deactivate_bronze_load IS 'Soft-deletes an entire load by setting load_active to FALSE';

-- Function to deactivate specific rows
CREATE OR REPLACE FUNCTION deactivate_bronze_rows(
    p_table_name VARCHAR,
    p_row_ids VARCHAR[]
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
    v_sql TEXT;
BEGIN
    IF p_table_name = 'bronze_taxonomies' THEN
        UPDATE bronze_taxonomies
        SET row_active = FALSE
        WHERE row_id = ANY(p_row_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;
    ELSIF p_table_name = 'bronze_professions' THEN
        UPDATE bronze_professions
        SET row_active = FALSE
        WHERE row_id = ANY(p_row_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;
    ELSE
        RAISE EXCEPTION 'Invalid table name: %', p_table_name;
    END IF;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION deactivate_bronze_rows IS 'Soft-deletes specific rows by row_id';

-- =============================================================================
-- DATA MIGRATION: SET DEFAULTS FOR EXISTING RECORDS
-- =============================================================================

-- Generate load_id for existing bronze_load_details records without one
UPDATE bronze_load_details
SET load_id = 'LEGACY_' || id::TEXT
WHERE load_id IS NULL;

-- Set existing loads as successful and active
UPDATE bronze_load_details
SET load_status = 'successful',
    load_active = TRUE
WHERE load_status IS NULL OR load_active IS NULL;

-- Set all existing bronze rows as active
UPDATE bronze_taxonomies
SET row_active = TRUE
WHERE row_active IS NULL;

UPDATE bronze_professions
SET row_active = TRUE
WHERE row_active IS NULL;

-- Link existing bronze rows to their load_id
-- This assumes the bronze_load_details.id corresponds to the foreign key relationship
-- Adjust this based on your actual schema structure
UPDATE bronze_taxonomies bt
SET load_id = bld.load_id
FROM bronze_load_details bld
WHERE bt.load_id IS NULL
  AND bt.load_date BETWEEN bld.load_start AND COALESCE(bld.load_end, CURRENT_TIMESTAMP);

UPDATE bronze_professions bp
SET load_id = bld.load_id
FROM bronze_load_details bld
WHERE bp.load_id IS NULL
  AND bp.load_date BETWEEN bld.load_start AND COALESCE(bld.load_end, CURRENT_TIMESTAMP);

-- =============================================================================
-- MIGRATION VERIFICATION
-- =============================================================================

DO $$
DECLARE
    missing_items TEXT := '';
BEGIN
    -- Check bronze_load_details columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_load_details' AND column_name = 'load_id') THEN
        missing_items := missing_items || 'bronze_load_details.load_id, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_load_details' AND column_name = 'load_status') THEN
        missing_items := missing_items || 'bronze_load_details.load_status, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_load_details' AND column_name = 'load_active') THEN
        missing_items := missing_items || 'bronze_load_details.load_active, ';
    END IF;

    -- Check bronze_taxonomies columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_taxonomies' AND column_name = 'row_id') THEN
        missing_items := missing_items || 'bronze_taxonomies.row_id, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_taxonomies' AND column_name = 'row_active') THEN
        missing_items := missing_items || 'bronze_taxonomies.row_active, ';
    END IF;

    -- Check bronze_professions columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_professions' AND column_name = 'row_id') THEN
        missing_items := missing_items || 'bronze_professions.row_id, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'bronze_professions' AND column_name = 'row_active') THEN
        missing_items := missing_items || 'bronze_professions.row_active, ';
    END IF;

    -- Check views
    IF NOT EXISTS (SELECT 1 FROM information_schema.views
                   WHERE table_name = 'v_bronze_taxonomies_active') THEN
        missing_items := missing_items || 'v_bronze_taxonomies_active view, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.views
                   WHERE table_name = 'v_bronze_professions_active') THEN
        missing_items := missing_items || 'v_bronze_professions_active view, ';
    END IF;

    IF LENGTH(missing_items) > 0 THEN
        RAISE EXCEPTION 'Migration 011 incomplete. Missing: %', missing_items;
    ELSE
        RAISE NOTICE 'Migration 011 completed successfully - Martin bronze layer enhancements applied';
    END IF;
END $$;

-- =============================================================================
-- SUMMARY
-- =============================================================================
-- Migration 011 implements Martin's proposed changes:
-- 1. ✅ load_id identifier for bronze_load_details
-- 2. ✅ load_status (pending, processing, successful, partially_successful, failed)
-- 3. ✅ load_active flag for soft deletion ("withdraw without deletion")
-- 4. ✅ row_id identifier for bronze_taxonomies and bronze_professions
-- 5. ✅ row_active flag for individual row soft deletion
-- 6. ✅ load_id linkage from bronze rows to bronze_load_details
-- 7. ✅ Views for active data filtering
-- 8. ✅ Helper functions for deactivation workflows
-- 9. ✅ Source load tracking in silver layer (data lineage)
-- =============================================================================
