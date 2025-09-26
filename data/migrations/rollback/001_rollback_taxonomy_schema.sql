-- Rollback script for 001_create_taxonomy_schema.sql
-- WARNING: This will delete all data in the taxonomy schema!
-- Execute with caution and ensure proper backups exist

BEGIN TRANSACTION;

-- Drop views first
DROP VIEW IF EXISTS v_taxonomy_hierarchy CASCADE;
DROP VIEW IF EXISTS v_profession_mappings CASCADE;
DROP VIEW IF EXISTS v_translation_patterns CASCADE;

-- Drop indexes
DROP INDEX IF EXISTS idx_bronze_taxonomies_source;
DROP INDEX IF EXISTS idx_bronze_professions_source;
DROP INDEX IF EXISTS idx_silver_nodes_taxonomy;
DROP INDEX IF EXISTS idx_silver_nodes_parent;
DROP INDEX IF EXISTS idx_silver_prof_customer;
DROP INDEX IF EXISTS idx_silver_mapping_tax_node;
DROP INDEX IF EXISTS idx_silver_mapping_prof_prof;
DROP INDEX IF EXISTS idx_gold_mapping_master;
DROP INDEX IF EXISTS idx_gold_mapping_customer;
DROP INDEX IF EXISTS idx_translation_pattern;
DROP INDEX IF EXISTS idx_audit_entity;
DROP INDEX IF EXISTS idx_processing_log_source;

-- Drop Gold layer tables
DROP TABLE IF EXISTS gold_translation_metrics CASCADE;
DROP TABLE IF EXISTS gold_taxonomies_mapping CASCADE;
DROP TABLE IF EXISTS gold_professions_mapping CASCADE;

-- Drop Silver layer tables
DROP TABLE IF EXISTS silver_translation_patterns CASCADE;
DROP TABLE IF EXISTS silver_mapping_professions CASCADE;
DROP TABLE IF EXISTS silver_mapping_taxonomies CASCADE;
DROP TABLE IF EXISTS silver_mapping_taxonomies_rules_assignment CASCADE;
DROP TABLE IF EXISTS silver_mapping_taxonomies_rules CASCADE;
DROP TABLE IF EXISTS silver_mapping_taxonomies_rules_types CASCADE;
DROP TABLE IF EXISTS silver_professions_attributes CASCADE;
DROP TABLE IF EXISTS silver_professions CASCADE;
DROP TABLE IF EXISTS silver_taxonomies_nodes_attributes CASCADE;
DROP TABLE IF EXISTS silver_taxonomies_nodes CASCADE;
DROP TABLE IF EXISTS silver_taxonomies_nodes_types CASCADE;
DROP TABLE IF EXISTS silver_taxonomies CASCADE;

-- Drop Bronze layer tables
DROP TABLE IF EXISTS bronze_professions CASCADE;
DROP TABLE IF EXISTS bronze_taxonomies CASCADE;
DROP TABLE IF EXISTS bronze_data_sources CASCADE;

-- Drop support tables
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS processing_log CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_modified_column() CASCADE;
DROP FUNCTION IF EXISTS calculate_confidence_score(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_taxonomy_path(INTEGER) CASCADE;

-- Drop types
DROP TYPE IF EXISTS processing_status CASCADE;
DROP TYPE IF EXISTS confidence_level CASCADE;
DROP TYPE IF EXISTS mapping_status CASCADE;

COMMIT;

-- Verification query
SELECT 'Rollback completed. Tables remaining in public schema:' as status;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;