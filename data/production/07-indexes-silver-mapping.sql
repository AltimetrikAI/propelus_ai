-- ============================================================================
-- Production Indexes - Silver Mapping Layer
-- ============================================================================
-- Description: Performance indexes for mapping rules, assignments, and mappings
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (production-ddl.sql)
-- ============================================================================

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES_RULES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_name_lower_idx ON silver_mapping_taxonomies_rules (lower(name));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_name_trgm ON silver_mapping_taxonomies_rules USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_enabled_true_idx ON silver_mapping_taxonomies_rules (enabled);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_pattern_lower_idx ON silver_mapping_taxonomies_rules (lower(pattern));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_pattern_trgm ON silver_mapping_taxonomies_rules USING GIN (pattern gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_attributes_gin ON silver_mapping_taxonomies_rules USING GIN (attributes gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_flags_lower_idx ON silver_mapping_taxonomies_rules (lower(flags));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_flags_trgm ON silver_mapping_taxonomies_rules USING GIN (flags gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_action_lower_idx ON silver_mapping_taxonomies_rules (lower(action));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_action_trgm ON silver_mapping_taxonomies_rules USING GIN (action gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_AI_mapping_flag_true_idx ON silver_mapping_taxonomies_rules (AI_mapping_flag);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_Human_mapping_flag_true_idx ON silver_mapping_taxonomies_rules (Human_mapping_flag);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_created_at_brin ON silver_mapping_taxonomies_rules USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_last_updated_at_brin ON silver_mapping_taxonomies_rules USING BRIN (last_updated_at);

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES_RULES_ASSIGNMENT INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_assigment_mapping_rule_assigment_id_idx ON silver_mapping_taxonomies_rules_assigment (mapping_rule_assigment_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_assigment_master_node_type_id_idx ON silver_mapping_taxonomies_rules_assigment (master_node_type_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_assigment_child_node_type_id_idx ON silver_mapping_taxonomies_rules_assigment (child_node_type_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_assigment_enabled_true_idx ON silver_mapping_taxonomies_rules_assigment (enabled);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_assigment_created_at_brin ON silver_mapping_taxonomies_rules_assigment USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rules_assigment_last_updated_at_brin ON silver_mapping_taxonomies_rules_assigment USING BRIN (last_updated_at);

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_mapping_rule_id_idx ON silver_mapping_taxonomies (mapping_rule_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_master_node_id_idx ON silver_mapping_taxonomies (master_node_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_child_node_id_idx ON silver_mapping_taxonomies (child_node_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_status_lower_idx ON silver_mapping_taxonomies (lower(status));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_status_trgm ON silver_mapping_taxonomies USING GIN (status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_user_lower_idx ON silver_mapping_taxonomies (lower("user"));
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_user_trgm ON silver_mapping_taxonomies USING GIN ("user" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_created_at_brin ON silver_mapping_taxonomies USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_last_updated_at_brin ON silver_mapping_taxonomies USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_master_child_idx ON silver_mapping_taxonomies (master_node_id, child_node_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_rule_idx ON silver_mapping_taxonomies (mapping_rule_id);

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Critical for Lambda Mapping Command:
--   - enabled indexes: Fast rule filtering
--   - master_node_type_id, child_node_type_id: Rule assignment lookups
--   - master_node_id, child_node_id: Mapping lookups
--   - Composite indexes: Multi-column queries
--
-- Pattern matching:
--   - Trigram indexes on pattern/name: Fast fuzzy matching
--
-- ============================================================================
