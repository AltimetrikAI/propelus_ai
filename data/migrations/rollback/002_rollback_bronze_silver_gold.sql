-- Rollback script for 002_bronze_silver_gold_architecture.sql
-- Removes additional columns and tables added in migration 002

BEGIN TRANSACTION;

-- Drop new indexes
DROP INDEX IF EXISTS idx_silver_attr_combinations_hash CASCADE;
DROP INDEX IF EXISTS idx_silver_attr_combinations_customer CASCADE;
DROP INDEX IF EXISTS idx_silver_prof_rules_enabled CASCADE;
DROP INDEX IF EXISTS idx_master_versions_active CASCADE;

-- Drop new tables
DROP TABLE IF EXISTS silver_attribute_combinations CASCADE;
DROP TABLE IF EXISTS silver_mapping_professions_rules_types CASCADE;
DROP TABLE IF EXISTS silver_mapping_professions_rules CASCADE;
DROP TABLE IF EXISTS silver_attribute_types CASCADE;
DROP TABLE IF EXISTS master_taxonomy_versions CASCADE;
DROP TABLE IF EXISTS api_contracts CASCADE;

-- Remove columns added to existing tables (if ALTER TABLE was used)
-- Note: PostgreSQL doesn't allow dropping columns in a transaction-safe way
-- These would need to be handled carefully in production

-- Remove any new functions
DROP FUNCTION IF EXISTS generate_mapping_confidence(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS validate_taxonomy_hierarchy(INTEGER) CASCADE;

-- Remove any new triggers
DROP TRIGGER IF EXISTS update_mapping_confidence ON silver_mapping_taxonomies CASCADE;
DROP TRIGGER IF EXISTS audit_taxonomy_changes ON silver_taxonomies CASCADE;

COMMIT;

-- Verification
SELECT 'Rollback of bronze-silver-gold architecture completed' as status;
SELECT COUNT(*) as remaining_tables
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'silver_%';