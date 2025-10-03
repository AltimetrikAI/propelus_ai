-- Migration: 002_bronze_silver_gold_architecture
-- Description: Implement Bronze/Silver/Gold data architecture as per data engineer specification
-- Author: Propelus AI Team
-- Date: 2025-01-24

-- ============================================
-- BRONZE LAYER - Raw Data Ingestion
-- ============================================

-- Bronze layer for raw taxonomy data ingestion
CREATE TABLE bronze_taxonomies (
    customer_id INTEGER NOT NULL,
    row_json JSON NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    type VARCHAR(20) NOT NULL CHECK (type IN ('new', 'updated'))
);

CREATE INDEX idx_bronze_tax_customer ON bronze_taxonomies(customer_id);
CREATE INDEX idx_bronze_tax_load_date ON bronze_taxonomies(load_date);

-- Bronze layer for raw profession data ingestion
CREATE TABLE bronze_professions (
    customer_id INTEGER NOT NULL,
    row_json JSON NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    type VARCHAR(20) NOT NULL CHECK (type IN ('new', 'updated'))
);

CREATE INDEX idx_bronze_prof_customer ON bronze_professions(customer_id);
CREATE INDEX idx_bronze_prof_load_date ON bronze_professions(load_date);

-- ============================================
-- SILVER LAYER - Structured Data
-- ============================================

-- Silver taxonomies table
CREATE TABLE silver_taxonomies (
    taxonomy_id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('master', 'customer')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT master_taxonomy_customer CHECK (
        (type = 'master' AND customer_id = -1) OR
        (type = 'customer' AND customer_id > 0)
    )
);

CREATE INDEX idx_silver_tax_customer ON silver_taxonomies(customer_id);
CREATE INDEX idx_silver_tax_type ON silver_taxonomies(type);
CREATE INDEX idx_silver_tax_status ON silver_taxonomies(status);

-- Node types for taxonomies
CREATE TABLE silver_taxonomies_nodes_types (
    node_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    level INTEGER NOT NULL CHECK (level >= 1),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_node_types_level ON silver_taxonomies_nodes_types(level);
CREATE INDEX idx_node_types_status ON silver_taxonomies_nodes_types(status);

-- Taxonomy nodes (hierarchical structure)
CREATE TABLE silver_taxonomies_nodes (
    node_id SERIAL PRIMARY KEY,
    node_type_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes_types(node_type_id),
    taxonomy_id INTEGER NOT NULL REFERENCES silver_taxonomies(taxonomy_id),
    parent_node_id INTEGER REFERENCES silver_taxonomies_nodes(node_id),
    value TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_nodes_type ON silver_taxonomies_nodes(node_type_id);
CREATE INDEX idx_nodes_taxonomy ON silver_taxonomies_nodes(taxonomy_id);
CREATE INDEX idx_nodes_parent ON silver_taxonomies_nodes(parent_node_id);
CREATE INDEX idx_nodes_value ON silver_taxonomies_nodes(value);

-- Node attributes
CREATE TABLE silver_taxonomies_nodes_attributes (
    attribute_id SERIAL PRIMARY KEY,
    node_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes(node_id),
    name VARCHAR(100) NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_node_attr_node ON silver_taxonomies_nodes_attributes(node_id);
CREATE INDEX idx_node_attr_name ON silver_taxonomies_nodes_attributes(name);

-- ============================================
-- MAPPING RULES - TAXONOMIES
-- ============================================

-- Mapping rule types for taxonomies
CREATE TABLE silver_mapping_taxonomies_rules_types (
    mapping_rule_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    command VARCHAR(100) NOT NULL,
    ai_mapping_flag BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Mapping rules for taxonomies
CREATE TABLE silver_mapping_taxonomies_rules (
    mapping_rule_id SERIAL PRIMARY KEY,
    mapping_rule_type_id INTEGER NOT NULL REFERENCES silver_mapping_taxonomies_rules_types(mapping_rule_type_id),
    name VARCHAR(255) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    pattern TEXT,
    attributes JSONB,
    flags JSONB,
    action TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tax_rules_type ON silver_mapping_taxonomies_rules(mapping_rule_type_id);
CREATE INDEX idx_tax_rules_enabled ON silver_mapping_taxonomies_rules(enabled);

-- Rule assignments for taxonomies
CREATE TABLE silver_mapping_taxonomies_rules_assignment (
    mapping_rule_assignment_id SERIAL PRIMARY KEY,
    mapping_rule_id INTEGER NOT NULL REFERENCES silver_mapping_taxonomies_rules(mapping_rule_id),
    master_node_type_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes_types(node_type_id),
    node_type_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes_types(node_type_id),
    priority INTEGER NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tax_assign_rule ON silver_mapping_taxonomies_rules_assignment(mapping_rule_id);
CREATE INDEX idx_tax_assign_priority ON silver_mapping_taxonomies_rules_assignment(priority);
CREATE INDEX idx_tax_assign_enabled ON silver_mapping_taxonomies_rules_assignment(enabled);

-- Taxonomy mappings
CREATE TABLE silver_mapping_taxonomies (
    mapping_id SERIAL PRIMARY KEY,
    mapping_rule_id INTEGER REFERENCES silver_mapping_taxonomies_rules(mapping_rule_id),
    master_node_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes(node_id),
    node_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes(node_id),
    confidence DECIMAL(5,2) CHECK (confidence >= 0 AND confidence <= 100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tax_map_rule ON silver_mapping_taxonomies(mapping_rule_id);
CREATE INDEX idx_tax_map_master ON silver_mapping_taxonomies(master_node_id);
CREATE INDEX idx_tax_map_node ON silver_mapping_taxonomies(node_id);
CREATE INDEX idx_tax_map_status ON silver_mapping_taxonomies(status);
CREATE INDEX idx_tax_map_confidence ON silver_mapping_taxonomies(confidence);

-- ============================================
-- PROFESSIONS (Non-hierarchical)
-- ============================================

-- Silver professions table
CREATE TABLE silver_professions (
    profession_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    name VARCHAR(500) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prof_customer ON silver_professions(customer_id);
CREATE INDEX idx_prof_name ON silver_professions(name);

-- Profession attributes
CREATE TABLE silver_professions_attributes (
    attribute_id SERIAL PRIMARY KEY,
    profession_id INTEGER NOT NULL REFERENCES silver_professions(profession_id),
    name VARCHAR(100) NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prof_attr_prof ON silver_professions_attributes(profession_id);
CREATE INDEX idx_prof_attr_name ON silver_professions_attributes(name);

-- ============================================
-- MAPPING RULES - PROFESSIONS
-- ============================================

-- Mapping rule types for professions
CREATE TABLE silver_mapping_professions_rules_types (
    mapping_rule_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    command VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Mapping rules for professions
CREATE TABLE silver_mapping_professions_rules (
    mapping_rule_id SERIAL PRIMARY KEY,
    mapping_rule_type_id INTEGER NOT NULL REFERENCES silver_mapping_professions_rules_types(mapping_rule_type_id),
    name VARCHAR(255) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    pattern TEXT,
    attributes JSONB,
    flags JSONB,
    action TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prof_rules_type ON silver_mapping_professions_rules(mapping_rule_type_id);
CREATE INDEX idx_prof_rules_enabled ON silver_mapping_professions_rules(enabled);

-- Rule assignments for professions
CREATE TABLE silver_mapping_professions_rules_assignment (
    mapping_rule_assignment_id SERIAL PRIMARY KEY,
    mapping_rule_id INTEGER NOT NULL REFERENCES silver_mapping_professions_rules(mapping_rule_id),
    node_type_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes_types(node_type_id),
    priority INTEGER NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prof_assign_rule ON silver_mapping_professions_rules_assignment(mapping_rule_id);
CREATE INDEX idx_prof_assign_priority ON silver_mapping_professions_rules_assignment(priority);
CREATE INDEX idx_prof_assign_enabled ON silver_mapping_professions_rules_assignment(enabled);

-- Profession mappings
CREATE TABLE silver_mapping_professions (
    mapping_id SERIAL PRIMARY KEY,
    mapping_rule_id INTEGER REFERENCES silver_mapping_professions_rules(mapping_rule_id),
    node_id INTEGER NOT NULL REFERENCES silver_taxonomies_nodes(node_id),
    profession_id INTEGER NOT NULL REFERENCES silver_professions(profession_id),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prof_map_rule ON silver_mapping_professions(mapping_rule_id);
CREATE INDEX idx_prof_map_node ON silver_mapping_professions(node_id);
CREATE INDEX idx_prof_map_prof ON silver_mapping_professions(profession_id);
CREATE INDEX idx_prof_map_status ON silver_mapping_professions(status);

-- ============================================
-- AUDIT LOG TABLES
-- ============================================

-- Audit log for silver_taxonomies
CREATE TABLE silver_taxonomies_log (
    taxonomy_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_name VARCHAR(255)
);

CREATE INDEX idx_tax_log_id ON silver_taxonomies_log(taxonomy_id);
CREATE INDEX idx_tax_log_date ON silver_taxonomies_log(operation_date);

-- ============================================
-- GOLD LAYER - Production Data
-- ============================================

-- Gold taxonomy mappings
CREATE TABLE gold_taxonomies_mapping (
    mapping_id INTEGER PRIMARY KEY,
    master_node_id INTEGER NOT NULL,
    node_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gold_tax_master ON gold_taxonomies_mapping(master_node_id);
CREATE INDEX idx_gold_tax_node ON gold_taxonomies_mapping(node_id);

-- Gold profession mappings
CREATE TABLE gold_mapping_professions (
    mapping_id INTEGER PRIMARY KEY,
    node_id INTEGER NOT NULL,
    profession_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gold_prof_node ON gold_mapping_professions(node_id);
CREATE INDEX idx_gold_prof_id ON gold_mapping_professions(profession_id);

-- ============================================
-- UPDATE TRIGGERS
-- ============================================

-- Create update triggers for last_updated_at columns
CREATE OR REPLACE FUNCTION update_last_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to all tables with last_updated_at
CREATE TRIGGER update_silver_taxonomies_timestamp
    BEFORE UPDATE ON silver_taxonomies
    FOR EACH ROW EXECUTE FUNCTION update_last_updated_at();

CREATE TRIGGER update_silver_taxonomies_nodes_types_timestamp
    BEFORE UPDATE ON silver_taxonomies_nodes_types
    FOR EACH ROW EXECUTE FUNCTION update_last_updated_at();

CREATE TRIGGER update_silver_taxonomies_nodes_timestamp
    BEFORE UPDATE ON silver_taxonomies_nodes
    FOR EACH ROW EXECUTE FUNCTION update_last_updated_at();

CREATE TRIGGER update_silver_taxonomies_nodes_attributes_timestamp
    BEFORE UPDATE ON silver_taxonomies_nodes_attributes
    FOR EACH ROW EXECUTE FUNCTION update_last_updated_at();

CREATE TRIGGER update_silver_professions_timestamp
    BEFORE UPDATE ON silver_professions
    FOR EACH ROW EXECUTE FUNCTION update_last_updated_at();

CREATE TRIGGER update_silver_professions_attributes_timestamp
    BEFORE UPDATE ON silver_professions_attributes
    FOR EACH ROW EXECUTE FUNCTION update_last_updated_at();

-- ============================================
-- AUDIT TRIGGER FOR SILVER_TAXONOMIES
-- ============================================

CREATE OR REPLACE FUNCTION audit_silver_taxonomies()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO silver_taxonomies_log(taxonomy_id, old_row, new_row, operation_type, user_name)
        VALUES (NEW.taxonomy_id, NULL, row_to_json(NEW), 'insert', current_user);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO silver_taxonomies_log(taxonomy_id, old_row, new_row, operation_type, user_name)
        VALUES (NEW.taxonomy_id, row_to_json(OLD), row_to_json(NEW), 'update', current_user);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO silver_taxonomies_log(taxonomy_id, old_row, new_row, operation_type, user_name)
        VALUES (OLD.taxonomy_id, row_to_json(OLD), NULL, 'delete', current_user);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_silver_taxonomies_trigger
    AFTER INSERT OR UPDATE OR DELETE ON silver_taxonomies
    FOR EACH ROW EXECUTE FUNCTION audit_silver_taxonomies();

-- ============================================
-- INSERT INITIAL DATA
-- ============================================

-- Insert master taxonomy
INSERT INTO silver_taxonomies (taxonomy_id, customer_id, name, type, status)
VALUES (-1, -1, 'Propelus Master Taxonomy', 'master', 'active');

-- Insert example node types
INSERT INTO silver_taxonomies_nodes_types (name, level, status) VALUES
('Industry', 1, 'active'),
('Profession Group', 2, 'active'),
('Broad Occupation', 3, 'active'),
('Detailed Occupation', 4, 'active'),
('Occupation Specialty', 5, 'active'),
('Profession', 6, 'active');

-- Insert example mapping rule types for taxonomies
INSERT INTO silver_mapping_taxonomies_rules_types (name, command, ai_mapping_flag) VALUES
('regex', 'regex', FALSE),
('exact_match', 'exact', FALSE),
('fuzzy_match', 'fuzzy', FALSE),
('AI', 'ai_semantic', TRUE);

-- Insert example mapping rule types for professions
INSERT INTO silver_mapping_professions_rules_types (name, command) VALUES
('regex', 'regex'),
('exact_match', 'exact'),
('fuzzy_match', 'fuzzy');

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE bronze_taxonomies IS 'Raw ingestion of hierarchical taxonomy data per customer';
COMMENT ON TABLE bronze_professions IS 'Raw ingestion of non-hierarchical profession data with attributes per customer';
COMMENT ON TABLE silver_taxonomies IS 'Table with basic data of hierarchical taxonomies';
COMMENT ON TABLE silver_taxonomies_nodes_types IS 'Defines the types of nodes used in hierarchical taxonomies';
COMMENT ON TABLE silver_taxonomies_nodes IS 'Stores actual hierarchy nodes within taxonomies';
COMMENT ON TABLE silver_taxonomies_nodes_attributes IS 'Stores attributes assigned to taxonomy nodes';
COMMENT ON TABLE silver_mapping_taxonomies_rules_types IS 'Defines types of mapping rules for hierarchical taxonomies';
COMMENT ON TABLE silver_mapping_taxonomies_rules IS 'Stores automated mapping rules for taxonomy-to-taxonomy mapping';
COMMENT ON TABLE silver_mapping_taxonomies_rules_assignment IS 'Assigns mapping rules to node types and sets priorities';
COMMENT ON TABLE silver_mapping_taxonomies IS 'Holds mapping results after applying mapping rules to taxonomies';
COMMENT ON TABLE silver_professions IS 'Table with basic data of non-hierarchical profession data sets';
COMMENT ON TABLE silver_professions_attributes IS 'Stores attributes assigned to professions';
COMMENT ON TABLE silver_mapping_professions_rules_types IS 'Defines types of mapping rules for non-hierarchical professions';
COMMENT ON TABLE silver_mapping_professions_rules IS 'Stores automated mapping rules for profession-to-taxonomy mapping';
COMMENT ON TABLE silver_mapping_professions_rules_assignment IS 'Assigns mapping rules to customer taxonomies node types';
COMMENT ON TABLE silver_mapping_professions IS 'Holds mapping results for profession-to-taxonomy mappings';
COMMENT ON TABLE silver_taxonomies_log IS 'Audit trail of changes applied to silver_taxonomies table';
COMMENT ON TABLE gold_taxonomies_mapping IS 'Final approved mappings between master and customer taxonomy nodes';
COMMENT ON TABLE gold_mapping_professions IS 'Final mappings between taxonomy nodes and professions';