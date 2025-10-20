-- ============================================================================
-- Production Indexes - Silver Core Layer
-- ============================================================================
-- Description: Performance indexes for silver_taxonomies, nodes, node_types, attributes
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (production-ddl.sql)
-- ============================================================================

-- ============================================================================
-- SILVER_TAXONOMIES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_customer_id_idx ON silver_taxonomies (customer_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_load_id_idx ON silver_taxonomies (load_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_name_lower_idx ON silver_taxonomies (lower(name));
CREATE INDEX IF NOT EXISTS silver_taxonomies_name_trgm ON silver_taxonomies USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_status_lower_idx ON silver_taxonomies (lower(status));
CREATE INDEX IF NOT EXISTS silver_taxonomies_status_trgm ON silver_taxonomies USING GIN (status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_created_at_brin ON silver_taxonomies USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_last_updated_at_brin ON silver_taxonomies USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_cust_tax_idx ON silver_taxonomies (customer_id, taxonomy_id);

-- ============================================================================
-- SILVER_TAXONOMIES_NODES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_node_type_id_idx ON silver_taxonomies_nodes (node_type_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_taxonomy_id_idx ON silver_taxonomies_nodes (taxonomy_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_parent_node_id_idx ON silver_taxonomies_nodes (parent_node_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_load_id_idx ON silver_taxonomies_nodes (load_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_row_id_idx ON silver_taxonomies_nodes (row_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_value_lower_idx ON silver_taxonomies_nodes (lower(value));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_value_trgm ON silver_taxonomies_nodes USING GIN (value gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_profession_lower_idx ON silver_taxonomies_nodes (lower(profession));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_profession_trgm ON silver_taxonomies_nodes USING GIN (profession gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_status_lower_idx ON silver_taxonomies_nodes (lower(status));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_status_trgm ON silver_taxonomies_nodes USING GIN (status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_created_at_brin ON silver_taxonomies_nodes USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_last_updated_at_brin ON silver_taxonomies_nodes USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_tax_type_idx ON silver_taxonomies_nodes (taxonomy_id, node_type_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_parent_idx ON silver_taxonomies_nodes (parent_node_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_level_idx ON silver_taxonomies_nodes (level);

-- ============================================================================
-- SILVER_TAXONOMIES_NODES_TYPES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_node_type_id_idx ON silver_taxonomies_nodes_types (node_type_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_name_lower_idx ON silver_taxonomies_nodes_types (lower(name));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_name_trgm ON silver_taxonomies_nodes_types USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_status_lower_idx ON silver_taxonomies_nodes_types (lower(status));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_status_trgm ON silver_taxonomies_nodes_types USING GIN (status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_created_at_brin ON silver_taxonomies_nodes_types USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_types_last_updated_at_brin ON silver_taxonomies_nodes_types USING BRIN (last_updated_at);

-- ============================================================================
-- SILVER_TAXONOMIES_ATTRIBUTE_TYPES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_attribute_type_id_idx ON silver_taxonomies_attribute_types (attribute_type_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_name_lower_idx ON silver_taxonomies_attribute_types (lower(name));
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_name_trgm ON silver_taxonomies_attribute_types USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_created_at_brin ON silver_taxonomies_attribute_types USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_attribute_types_last_updated_at_brin ON silver_taxonomies_attribute_types USING BRIN (last_updated_at);

-- ============================================================================
-- SILVER_TAXONOMIES_NODES_ATTRIBUTES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_attribute_type_id_idx ON silver_taxonomies_nodes_attributes (attribute_type_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_node_id_idx ON silver_taxonomies_nodes_attributes (node_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_load_id_idx ON silver_taxonomies_nodes_attributes (load_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_row_id_idx ON silver_taxonomies_nodes_attributes (row_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_value_lower_idx ON silver_taxonomies_nodes_attributes (lower(value));
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_value_trgm ON silver_taxonomies_nodes_attributes USING GIN (value gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_created_at_brin ON silver_taxonomies_nodes_attributes USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_last_updated_at_brin ON silver_taxonomies_nodes_attributes USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_nodes_attributes_node_attr_idx ON silver_taxonomies_nodes_attributes (node_id, attribute_type_id, value);

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Critical Indexes for Lambda Performance:
--   - taxonomy_id, node_type_id: Node lookups by type
--   - parent_node_id: Hierarchy traversal
--   - value/profession with trigram: Fuzzy matching
--   - level: Hierarchy level queries
--   - Composite indexes: Multi-column filtering
--
-- ============================================================================
