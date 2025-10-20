-- ============================================================================
-- Migration 014: Bronze Taxonomies Table Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update bronze_taxonomies table per data engineer spec
--              - Add row_id as primary key
--              - Add load_id foreign key to bronze_load_details
--              - Add taxonomy_id
--              - Add row_load_status
--              - Add row_active flag
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD row_id PRIMARY KEY
-- ============================================================================

-- Add row_id column if it doesn't exist
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS row_id SERIAL;

-- Add primary key constraint if table has no primary key
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'bronze_taxonomies'::regclass
        AND contype = 'p'
    ) THEN
        ALTER TABLE bronze_taxonomies
        ADD PRIMARY KEY (row_id);
    END IF;
END $$;

-- ============================================================================
-- ADD FOREIGN KEY TO bronze_load_details
-- ============================================================================

ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS load_id INTEGER;

-- Add foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_bronze_taxonomies_load'
    ) THEN
        ALTER TABLE bronze_taxonomies
        ADD CONSTRAINT fk_bronze_taxonomies_load
        FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);
    END IF;
END $$;

-- ============================================================================
-- ADD OTHER REQUIRED COLUMNS
-- ============================================================================

-- Add taxonomy_id
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS taxonomy_id INTEGER;

-- Add row_load_status with default 'in progress'
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS row_load_status VARCHAR(50) DEFAULT 'in progress';

-- Add check constraint for row_load_status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_bronze_row_load_status'
    ) THEN
        ALTER TABLE bronze_taxonomies
        ADD CONSTRAINT chk_bronze_row_load_status
        CHECK (row_load_status IN ('completed', 'in progress', 'failed'));
    END IF;
END $$;

-- Add row_active flag (default true)
ALTER TABLE bronze_taxonomies
ADD COLUMN IF NOT EXISTS row_active BOOLEAN DEFAULT TRUE NOT NULL;

-- ============================================================================
-- CREATE INDEXES FOR NEW COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_load
ON bronze_taxonomies(load_id);

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_taxonomy
ON bronze_taxonomies(taxonomy_id);

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_row_status
ON bronze_taxonomies(row_load_status);

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_active
ON bronze_taxonomies(row_active);

CREATE INDEX IF NOT EXISTS idx_bronze_taxonomies_load_taxonomy
ON bronze_taxonomies(load_id, taxonomy_id);

-- ============================================================================
-- ADD COLUMN COMMENTS
-- ============================================================================

COMMENT ON COLUMN bronze_taxonomies.row_id IS 'Primary key - ID of the row';
COMMENT ON COLUMN bronze_taxonomies.load_id IS 'Foreign key to bronze_load_details table';
COMMENT ON COLUMN bronze_taxonomies.customer_id IS 'Identifier of the customer providing the taxonomy';
COMMENT ON COLUMN bronze_taxonomies.taxonomy_id IS 'Identifier of the related taxonomy';
COMMENT ON COLUMN bronze_taxonomies.row_json IS 'JSON that contains one single row of taxonomy data';
COMMENT ON COLUMN bronze_taxonomies.row_load_status IS 'Status of the row load: completed, in progress, failed';
COMMENT ON COLUMN bronze_taxonomies.row_active IS 'Flag indicating if data from this row is active (default: true)';

-- ============================================================================
-- UPDATE TABLE COMMENT
-- ============================================================================

COMMENT ON TABLE bronze_taxonomies IS 'Raw ingestion of taxonomy data set per customer (row by row)';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
    idx_count INTEGER;
BEGIN
    -- Check all new columns exist
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'bronze_taxonomies'
    AND column_name IN ('row_id', 'load_id', 'taxonomy_id', 'row_load_status', 'row_active');

    IF col_count <> 5 THEN
        RAISE EXCEPTION 'Migration 014 failed: Expected 5 columns, found %', col_count;
    END IF;

    -- Check primary key exists
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'bronze_taxonomies'::regclass
        AND contype = 'p'
    ) THEN
        RAISE EXCEPTION 'Migration 014 failed: Primary key not created';
    END IF;

    -- Check foreign key exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_bronze_taxonomies_load'
    ) THEN
        RAISE EXCEPTION 'Migration 014 failed: Foreign key constraint not created';
    END IF;

    -- Check indexes created
    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE tablename = 'bronze_taxonomies'
    AND indexname IN (
        'idx_bronze_taxonomies_load',
        'idx_bronze_taxonomies_taxonomy',
        'idx_bronze_taxonomies_row_status',
        'idx_bronze_taxonomies_active',
        'idx_bronze_taxonomies_load_taxonomy'
    );

    IF idx_count < 5 THEN
        RAISE WARNING 'Migration 014: Expected 5 new indexes, found %', idx_count;
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 014: Bronze Taxonomies Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Columns Added: 5';
    RAISE NOTICE '  - row_id (SERIAL PRIMARY KEY)';
    RAISE NOTICE '  - load_id (INTEGER, FK to bronze_load_details)';
    RAISE NOTICE '  - taxonomy_id (INTEGER)';
    RAISE NOTICE '  - row_load_status (VARCHAR with check constraint)';
    RAISE NOTICE '  - row_active (BOOLEAN, default TRUE)';
    RAISE NOTICE 'New Indexes Created: 5';
    RAISE NOTICE 'Constraints Added: 1 FK, 1 CHECK';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
