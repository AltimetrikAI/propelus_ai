-- ============================================================================
-- Migration 013: Bronze Load Details Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update bronze_load_details table with new columns per data engineer spec
--              - Add load_start, load_end timestamps
--              - Add load_status tracking
--              - Add load_active flag
--              - Add load_type (replaces old 'type' column)
--              - Add taxonomy_type (master or customer)
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD NEW COLUMNS TO bronze_load_details
-- ============================================================================

-- Add load_start timestamp
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_start TIMESTAMP WITH TIME ZONE;

-- Add load_end timestamp
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_end TIMESTAMP WITH TIME ZONE;

-- Add load_status with check constraint
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_status VARCHAR(50) DEFAULT 'in progress';

-- Add check constraint for load_status if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_bronze_load_status'
    ) THEN
        ALTER TABLE bronze_load_details
        ADD CONSTRAINT chk_bronze_load_status
        CHECK (load_status IN ('completed', 'partially completed', 'failed', 'in progress'));
    END IF;
END $$;

-- Add load_active flag (default true)
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_active BOOLEAN DEFAULT TRUE NOT NULL;

-- Add load_type (new column to replace old 'type')
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS load_type VARCHAR(20);

-- Add check constraint for load_type
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_bronze_load_type'
    ) THEN
        ALTER TABLE bronze_load_details
        ADD CONSTRAINT chk_bronze_load_type
        CHECK (load_type IN ('new', 'update'));
    END IF;
END $$;

-- Add taxonomy_type
ALTER TABLE bronze_load_details
ADD COLUMN IF NOT EXISTS taxonomy_type VARCHAR(20);

-- Add check constraint for taxonomy_type
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_bronze_taxonomy_type'
    ) THEN
        ALTER TABLE bronze_load_details
        ADD CONSTRAINT chk_bronze_taxonomy_type
        CHECK (taxonomy_type IN ('master', 'customer'));
    END IF;
END $$;

-- ============================================================================
-- MIGRATE DATA FROM OLD 'type' COLUMN TO NEW 'load_type'
-- ============================================================================

-- Copy data from old 'type' column to new 'load_type' column
UPDATE bronze_load_details
SET load_type = CASE
    WHEN type = 'New' THEN 'new'
    WHEN type = 'Updated' THEN 'update'
    ELSE NULL
END
WHERE load_type IS NULL AND type IS NOT NULL;

-- ============================================================================
-- CREATE INDEXES FOR NEW COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_status
ON bronze_load_details(load_status);

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_active
ON bronze_load_details(load_active);

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_load_type
ON bronze_load_details(load_type);

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_taxonomy_type
ON bronze_load_details(taxonomy_type);

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_start
ON bronze_load_details(load_start DESC);

CREATE INDEX IF NOT EXISTS idx_bronze_load_details_end
ON bronze_load_details(load_end DESC);

-- ============================================================================
-- ADD COLUMN COMMENTS
-- ============================================================================

COMMENT ON COLUMN bronze_load_details.load_start IS 'Timestamp when load started';
COMMENT ON COLUMN bronze_load_details.load_end IS 'Timestamp when load ended';
COMMENT ON COLUMN bronze_load_details.load_status IS 'Status of the load: completed, partially completed, failed, in progress';
COMMENT ON COLUMN bronze_load_details.load_active IS 'Flag indicating if data from this load is active (default: true, can be changed manually)';
COMMENT ON COLUMN bronze_load_details.load_type IS 'Type of load: new for new taxonomies, update for existing taxonomies';
COMMENT ON COLUMN bronze_load_details.taxonomy_type IS 'Type of taxonomy: master or customer';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    missing_columns TEXT := '';
    col_count INTEGER;
BEGIN
    -- Check all new columns exist
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'bronze_load_details'
    AND column_name IN ('load_start', 'load_end', 'load_status', 'load_active', 'load_type', 'taxonomy_type');

    IF col_count <> 6 THEN
        RAISE EXCEPTION 'Migration 013 failed: Expected 6 new columns, found %', col_count;
    END IF;

    -- Check constraints exist
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bronze_load_status') THEN
        missing_columns := missing_columns || 'chk_bronze_load_status, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bronze_load_type') THEN
        missing_columns := missing_columns || 'chk_bronze_load_type, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bronze_taxonomy_type') THEN
        missing_columns := missing_columns || 'chk_bronze_taxonomy_type, ';
    END IF;

    IF LENGTH(missing_columns) > 0 THEN
        RAISE EXCEPTION 'Migration 013 incomplete. Missing constraints: %', missing_columns;
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 013: Bronze Load Details Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Columns Added: 6';
    RAISE NOTICE '  - load_start (TIMESTAMP)';
    RAISE NOTICE '  - load_end (TIMESTAMP)';
    RAISE NOTICE '  - load_status (VARCHAR with check constraint)';
    RAISE NOTICE '  - load_active (BOOLEAN, default TRUE)';
    RAISE NOTICE '  - load_type (VARCHAR with check constraint)';
    RAISE NOTICE '  - taxonomy_type (VARCHAR with check constraint)';
    RAISE NOTICE 'New Indexes Created: 6';
    RAISE NOTICE 'Check Constraints Added: 3';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
