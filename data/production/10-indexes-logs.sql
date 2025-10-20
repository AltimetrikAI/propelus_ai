-- ============================================================================
-- Production Indexes - Audit Log Tables
-- ============================================================================
-- Description: Performance indexes for all _log tables (audit trails)
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (production-ddl.sql)
-- ============================================================================

-- ============================================================================
-- SILVER_TAXONOMIES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_log_old_row_gin ON silver_taxonomies_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_log_new_row_gin ON silver_taxonomies_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_log_update_lower_idx ON silver_taxonomies_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_taxonomies_log_update_trgm ON silver_taxonomies_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_log_user_lower_idx ON silver_taxonomies_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_taxonomies_log_user_trgm ON silver_taxonomies_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_log_operation_date_brin ON silver_taxonomies_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_TAXONOMIES_NODES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_old_row_gin ON silver_taxonomies_nodes_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_new_row_gin ON silver_taxonomies_nodes_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_update_lower_idx ON silver_taxonomies_nodes_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_update_trgm ON silver_taxonomies_nodes_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_user_lower_idx ON silver_taxonomies_nodes_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_user_trgm ON silver_taxonomies_nodes_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_log_operation_date_brin ON silver_taxonomies_nodes_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_TAXONOMIES_NODES_TYPES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_node_type_id_idx ON silver_taxonomies_nodes_types_log (node_type_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_old_row_gin ON silver_taxonomies_nodes_types_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_new_row_gin ON silver_taxonomies_nodes_types_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_update_lower_idx ON silver_taxonomies_nodes_types_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_update_trgm ON silver_taxonomies_nodes_types_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_user_lower_idx ON silver_taxonomies_nodes_types_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_user_trgm ON silver_taxonomies_nodes_types_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_log_operation_date_brin ON silver_taxonomies_nodes_types_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES_RULES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_old_row_gin ON silver_mapping_taxonomies_rules_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_new_row_gin ON silver_mapping_taxonomies_rules_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_update_lower_idx ON silver_mapping_taxonomies_rules_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_update_trgm ON silver_mapping_taxonomies_rules_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_user_lower_idx ON silver_mapping_taxonomies_rules_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_user_trgm ON silver_mapping_taxonomies_rules_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_log_operation_date_brin ON silver_mapping_taxonomies_rules_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_MAPPING_RULES_ASSIGNMENT_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_mapping_rule_assigment_id_idx ON silver_mapping_rules_assigment_log (mapping_rule_assigment_id);
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_old_row_gin ON silver_mapping_rules_assigment_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_new_row_gin ON silver_mapping_rules_assigment_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_update_lower_idx ON silver_mapping_rules_assigment_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_update_trgm ON silver_mapping_rules_assigment_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_user_lower_idx ON silver_mapping_rules_assigment_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_user_trgm ON silver_mapping_rules_assigment_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_rules_assigment_log_operation_date_brin ON silver_mapping_rules_assigment_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_TAXONOMIES_NODES_ATTRIBUTES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_old_row_gin ON silver_taxonomies_nodes_attributes_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_new_row_gin ON silver_taxonomies_nodes_attributes_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_update_lower_idx ON silver_taxonomies_nodes_attributes_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_update_trgm ON silver_taxonomies_nodes_attributes_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_user_lower_idx ON silver_taxonomies_nodes_attributes_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_user_trgm ON silver_taxonomies_nodes_attributes_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_log_operation_date_brin ON silver_taxonomies_nodes_attributes_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_TAXONOMIES_ATTRIBUTE_TYPES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_old_row_gin ON silver_taxonomies_attribute_types_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_new_row_gin ON silver_taxonomies_attribute_types_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_update_lower_idx ON silver_taxonomies_attribute_types_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_update_trgm ON silver_taxonomies_attribute_types_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_user_lower_idx ON silver_taxonomies_attribute_types_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_user_trgm ON silver_taxonomies_attribute_types_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_log_operation_date_brin ON silver_taxonomies_attribute_types_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_TAXONOMIES_VERSIONS_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_old_row_gin ON silver_taxonomies_versions_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_new_row_gin ON silver_taxonomies_versions_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_update_lower_idx ON silver_taxonomies_versions_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_update_trgm ON silver_taxonomies_versions_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_user_lower_idx ON silver_taxonomies_versions_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_user_trgm ON silver_taxonomies_versions_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_log_operation_date_brin ON silver_taxonomies_versions_log USING BRIN (operation_date);

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES_VERSIONS_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_old_row_gin ON silver_mapping_taxonomies_versions_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_new_row_gin ON silver_mapping_taxonomies_versions_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_update_lower_idx ON silver_mapping_taxonomies_versions_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_update_trgm ON silver_mapping_taxonomies_versions_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_user_lower_idx ON silver_mapping_taxonomies_versions_log (lower("user"));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_user_trgm ON silver_mapping_taxonomies_versions_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_log_operation_date_brin ON silver_mapping_taxonomies_versions_log USING BRIN (operation_date);

-- ============================================================================
-- GOLD_MAPPING_TAXONOMIES_LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_old_row_gin ON gold_mapping_taxonomies_log USING GIN (old_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_new_row_gin ON gold_mapping_taxonomies_log USING GIN (new_row jsonb_path_ops);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_update_lower_idx ON gold_mapping_taxonomies_log (lower(operation_type));
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_update_trgm ON gold_mapping_taxonomies_log USING GIN (operation_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_user_lower_idx ON gold_mapping_taxonomies_log (lower("user"));
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_user_trgm ON gold_mapping_taxonomies_log USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_log_operation_date_brin ON gold_mapping_taxonomies_log USING BRIN (operation_date);

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Audit Log Performance:
--   - GIN indexes on JSONB: Fast queries on old_row/new_row
--   - Trigram on operation_type: Fuzzy matching
--   - BRIN on operation_date: Time-range queries
--   - User indexes: Track who made changes
--
-- Use Cases:
--   - Compliance audits
--   - Change tracking
--   - Rollback operations
--   - User activity monitoring
--
-- ============================================================================
