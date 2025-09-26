-- Rollback script for 004_sept25_refinements.sql
-- Removes Sept 25 schema refinements and updates

BEGIN TRANSACTION;

-- Revert column renames (if applicable)
ALTER TABLE silver_mapping_taxonomies
    RENAME COLUMN target_node_id TO master_node_id;

ALTER TABLE silver_mapping_professions
    RENAME COLUMN target_taxonomy_id TO master_taxonomy_id;

-- Drop new indexes
DROP INDEX IF EXISTS idx_bronze_load_type CASCADE;
DROP INDEX IF EXISTS idx_silver_confidence_status CASCADE;
DROP INDEX IF EXISTS idx_translation_ambiguous CASCADE;
DROP INDEX IF EXISTS idx_gold_active_mappings CASCADE;

-- Remove new columns
ALTER TABLE bronze_taxonomies DROP COLUMN IF EXISTS load_type;
ALTER TABLE bronze_professions DROP COLUMN IF EXISTS load_type;
ALTER TABLE silver_mapping_taxonomies DROP COLUMN IF EXISTS review_notes;
ALTER TABLE silver_mapping_professions DROP COLUMN IF EXISTS review_notes;
ALTER TABLE silver_translation_patterns DROP COLUMN IF EXISTS resolution_method;
ALTER TABLE gold_taxonomies_mapping DROP COLUMN IF EXISTS version_id;
ALTER TABLE gold_professions_mapping DROP COLUMN IF EXISTS version_id;

-- Drop new constraints
ALTER TABLE silver_mapping_taxonomies
    DROP CONSTRAINT IF EXISTS chk_confidence_range;

ALTER TABLE silver_mapping_professions
    DROP CONSTRAINT IF EXISTS chk_confidence_range;

-- Drop new functions
DROP FUNCTION IF EXISTS calculate_mapping_confidence(INTEGER, INTEGER, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_translation_path(INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS validate_mapping_rules(INTEGER) CASCADE;

-- Drop new triggers
DROP TRIGGER IF EXISTS update_confidence_on_review ON silver_mapping_taxonomies CASCADE;
DROP TRIGGER IF EXISTS update_confidence_on_review ON silver_mapping_professions CASCADE;
DROP TRIGGER IF EXISTS track_translation_patterns ON gold_taxonomies_mapping CASCADE;

-- Drop any materialized views
DROP MATERIALIZED VIEW IF EXISTS mv_mapping_statistics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_confidence_distribution CASCADE;

-- Restore original constraints if modified
-- This would need specific implementation based on what was changed

COMMIT;

-- Verification
SELECT 'Rollback of Sept 25 refinements completed' as status;

-- Check that columns have been reverted
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'silver_mapping_taxonomies'
  AND column_name IN ('master_node_id', 'target_node_id')
ORDER BY column_name;