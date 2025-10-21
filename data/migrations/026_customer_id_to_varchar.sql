-- ============================================================================
-- Migration 026: Change customer_id from BIGINT to VARCHAR(255)
-- ============================================================================
-- Date: 2025-01-21
-- Description: Update customer_id to support subsystem identifiers
--              Format: "subsystem-clientid" (e.g., "evercheck-719", "datasolutions-123")
--              This allows client subsystems to use their own naming conventions
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Drop foreign key constraints that reference customer_id
-- ============================================================================

-- Drop FK from bronze_load_details to silver_taxonomies
ALTER TABLE bronze_load_details
DROP CONSTRAINT IF EXISTS bronze_load_details_customer_id_taxonomy_id_fkey;

-- Drop FK from bronze_taxonomies to silver_taxonomies
ALTER TABLE bronze_taxonomies
DROP CONSTRAINT IF EXISTS bronze_taxonomies_customer_id_taxonomy_id_fkey;

-- ============================================================================
-- STEP 2: Alter customer_id columns to VARCHAR(255)
-- ============================================================================

-- Update silver_taxonomies (parent table)
ALTER TABLE silver_taxonomies
ALTER COLUMN customer_id TYPE VARCHAR(255);

-- Update bronze_load_details
ALTER TABLE bronze_load_details
ALTER COLUMN customer_id TYPE VARCHAR(255);

-- Update bronze_taxonomies
ALTER TABLE bronze_taxonomies
ALTER COLUMN customer_id TYPE VARCHAR(255);

-- ============================================================================
-- STEP 3: Recreate foreign key constraints
-- ============================================================================

-- Recreate FK from bronze_load_details to silver_taxonomies
ALTER TABLE bronze_load_details
ADD CONSTRAINT bronze_load_details_customer_id_taxonomy_id_fkey
FOREIGN KEY (customer_id, taxonomy_id)
REFERENCES silver_taxonomies(customer_id, taxonomy_id);

-- Recreate FK from bronze_taxonomies to silver_taxonomies
ALTER TABLE bronze_taxonomies
ADD CONSTRAINT bronze_taxonomies_customer_id_taxonomy_id_fkey
FOREIGN KEY (customer_id, taxonomy_id)
REFERENCES silver_taxonomies(customer_id, taxonomy_id);

-- ============================================================================
-- STEP 4: Update indexes if needed
-- ============================================================================

-- Recreate indexes that may have been affected
DROP INDEX IF EXISTS bronze_load_details_customer_id_idx;
CREATE INDEX bronze_load_details_customer_id_idx
ON bronze_load_details(customer_id);

DROP INDEX IF EXISTS bronze_taxonomies_customer_id_idx;
CREATE INDEX bronze_taxonomies_customer_id_idx
ON bronze_taxonomies(customer_id);

DROP INDEX IF EXISTS silver_taxonomies_customer_id_idx;
CREATE INDEX silver_taxonomies_customer_id_idx
ON silver_taxonomies(customer_id);

-- ============================================================================
-- ADD COMMENTS
-- ============================================================================

COMMENT ON COLUMN silver_taxonomies.customer_id IS 'Customer identifier in format: subsystem-clientid (e.g., evercheck-719, datasolutions-123). Allows client subsystems to use their own naming conventions.';
COMMENT ON COLUMN bronze_load_details.customer_id IS 'Customer identifier matching silver_taxonomies.customer_id format';
COMMENT ON COLUMN bronze_taxonomies.customer_id IS 'Customer identifier matching silver_taxonomies.customer_id format';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    silver_type TEXT;
    bronze_load_type TEXT;
    bronze_tax_type TEXT;
BEGIN
    -- Check column types
    SELECT data_type INTO silver_type
    FROM information_schema.columns
    WHERE table_name = 'silver_taxonomies' AND column_name = 'customer_id';

    SELECT data_type INTO bronze_load_type
    FROM information_schema.columns
    WHERE table_name = 'bronze_load_details' AND column_name = 'customer_id';

    SELECT data_type INTO bronze_tax_type
    FROM information_schema.columns
    WHERE table_name = 'bronze_taxonomies' AND column_name = 'customer_id';

    IF silver_type = 'character varying' AND
       bronze_load_type = 'character varying' AND
       bronze_tax_type = 'character varying' THEN
        RAISE NOTICE '=============================================================================';
        RAISE NOTICE 'Migration 026: customer_id to VARCHAR - COMPLETED SUCCESSFULLY';
        RAISE NOTICE '=============================================================================';
        RAISE NOTICE 'Updated Tables: silver_taxonomies, bronze_load_details, bronze_taxonomies';
        RAISE NOTICE 'New Type: VARCHAR(255)';
        RAISE NOTICE 'Format: subsystem-clientid (e.g., evercheck-719)';
        RAISE NOTICE 'Foreign Keys: Recreated';
        RAISE NOTICE 'Indexes: Recreated';
        RAISE NOTICE '=============================================================================';
    ELSE
        RAISE EXCEPTION 'Migration 026 failed: Column types not updated correctly';
    END IF;
END $$;

COMMIT;
