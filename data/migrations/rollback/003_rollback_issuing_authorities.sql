-- Rollback script for 003_issuing_authorities_and_context.sql
-- Removes issuing authorities and context rules functionality

BEGIN TRANSACTION;

-- Drop indexes
DROP INDEX IF EXISTS idx_issuing_auth_name CASCADE;
DROP INDEX IF EXISTS idx_issuing_auth_state CASCADE;
DROP INDEX IF EXISTS idx_context_rules_active CASCADE;
DROP INDEX IF EXISTS idx_context_rules_priority CASCADE;
DROP INDEX IF EXISTS idx_audit_enhanced_timestamp CASCADE;
DROP INDEX IF EXISTS idx_audit_enhanced_entity CASCADE;
DROP INDEX IF EXISTS idx_data_lineage_mapping CASCADE;
DROP INDEX IF EXISTS idx_data_lineage_source CASCADE;

-- Drop new tables
DROP TABLE IF EXISTS silver_context_rules CASCADE;
DROP TABLE IF EXISTS silver_issuing_authorities CASCADE;
DROP TABLE IF EXISTS audit_log_enhanced CASCADE;
DROP TABLE IF EXISTS data_lineage CASCADE;

-- Remove any foreign key constraints that reference these tables
ALTER TABLE silver_mapping_professions
    DROP CONSTRAINT IF EXISTS fk_mapping_prof_issuing_authority;

ALTER TABLE silver_mapping_taxonomies
    DROP CONSTRAINT IF EXISTS fk_mapping_tax_context_rule;

-- Remove columns added to existing tables (if any)
-- ALTER TABLE silver_professions DROP COLUMN IF EXISTS issuing_authority_id;
-- ALTER TABLE silver_mapping_professions DROP COLUMN IF EXISTS context_rule_id;

-- Drop functions related to context
DROP FUNCTION IF EXISTS apply_context_rules(INTEGER, JSONB) CASCADE;
DROP FUNCTION IF EXISTS validate_issuing_authority(TEXT, TEXT) CASCADE;

-- Drop any triggers
DROP TRIGGER IF EXISTS apply_context_on_mapping ON silver_mapping_professions CASCADE;
DROP TRIGGER IF EXISTS audit_authority_changes ON silver_issuing_authorities CASCADE;

COMMIT;

-- Verification
SELECT 'Rollback of issuing authorities and context completed' as status;
SELECT 'Tables removed:' as action, COUNT(*) as count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('silver_context_rules', 'silver_issuing_authorities',
                     'audit_log_enhanced', 'data_lineage')
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.tables t2
    WHERE t2.table_schema = 'public'
      AND t2.table_name = information_schema.tables.table_name
  );