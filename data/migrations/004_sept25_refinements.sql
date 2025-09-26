-- Migration: 004_sept25_refinements
-- Description: Refinements based on September 25 meeting discussions
-- Author: Propelus AI Team
-- Date: 2025-01-24
-- Based on: Sept 25 meeting with Edwin, Marcin, German, and Kirsten

-- ============================================
-- DATA SOURCE TRACKING
-- ============================================

-- Table to track data sources (API calls, files, etc.)
CREATE TABLE bronze_data_sources (
    source_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    source_type VARCHAR(50) CHECK (source_type IN ('api', 'file', 'manual', 'bucket')),
    source_name VARCHAR(255), -- File name or API endpoint
    source_url TEXT, -- API URL or S3 bucket path
    request_id UUID, -- For API calls
    session_id VARCHAR(255), -- For tracking related imports
    file_path TEXT, -- S3 or local file path
    file_size_bytes BIGINT,
    record_count INTEGER,
    import_status VARCHAR(50) CHECK (import_status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_data_source_customer ON bronze_data_sources(customer_id);
CREATE INDEX idx_data_source_type ON bronze_data_sources(source_type);
CREATE INDEX idx_data_source_status ON bronze_data_sources(import_status);
CREATE INDEX idx_data_source_request ON bronze_data_sources(request_id);

-- ============================================
-- BRONZE TO SILVER TRACEABILITY
-- ============================================

-- Add source_id to Bronze tables for traceability
ALTER TABLE bronze_taxonomies
ADD COLUMN source_id INTEGER REFERENCES bronze_data_sources(source_id),
ADD COLUMN bronze_id SERIAL UNIQUE;

ALTER TABLE bronze_professions
ADD COLUMN source_id INTEGER REFERENCES bronze_data_sources(source_id),
ADD COLUMN bronze_id SERIAL UNIQUE;

-- Add Bronze references to Silver tables
ALTER TABLE silver_taxonomies
ADD COLUMN source_id INTEGER REFERENCES bronze_data_sources(source_id),
ADD COLUMN bronze_taxonomy_id INTEGER;

ALTER TABLE silver_professions
ADD COLUMN source_id INTEGER REFERENCES bronze_data_sources(source_id),
ADD COLUMN bronze_profession_id INTEGER;

-- ============================================
-- MAPPING TERMINOLOGY UPDATES
-- ============================================

-- Rename master_node_id to target_node_id for flexibility
-- (Can map customer-to-customer, not just to master)
ALTER TABLE silver_mapping_taxonomies
RENAME COLUMN master_node_id TO target_node_id;

ALTER TABLE silver_mapping_taxonomies_rules_assignment
RENAME COLUMN master_node_type_id TO target_node_type_id;

ALTER TABLE gold_taxonomies_mapping
RENAME COLUMN master_node_id TO target_node_id;

-- ============================================
-- ATTRIBUTES CATALOG (Per Edwin's feedback)
-- ============================================

-- Create a catalog of attribute types (not values)
CREATE TABLE silver_attribute_types (
    attribute_type_id SERIAL PRIMARY KEY,
    attribute_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    data_type VARCHAR(50) CHECK (data_type IN ('string', 'number', 'boolean', 'date', 'array')),
    is_required BOOLEAN DEFAULT FALSE,
    applies_to VARCHAR(50) CHECK (applies_to IN ('node', 'profession', 'both')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert common attribute types
INSERT INTO silver_attribute_types (attribute_name, description, data_type, applies_to) VALUES
('state', 'US State code', 'string', 'both'),
('abbreviation', 'Professional abbreviation', 'string', 'both'),
('license_type', 'Type of license', 'string', 'profession'),
('verification_method', 'How to verify (automated/manual)', 'string', 'node'),
('board_name', 'Licensing board name', 'string', 'both'),
('renewal_cycle', 'License renewal cycle in months', 'number', 'profession');

-- Update attributes tables to reference attribute types
ALTER TABLE silver_taxonomies_nodes_attributes
ADD COLUMN attribute_type_id INTEGER REFERENCES silver_attribute_types(attribute_type_id);

ALTER TABLE silver_professions_attributes
ADD COLUMN attribute_type_id INTEGER REFERENCES silver_attribute_types(attribute_type_id);

-- ============================================
-- PROCESSING METADATA
-- ============================================

-- Table to track processing stages from Bronze to Gold
CREATE TABLE processing_log (
    log_id SERIAL PRIMARY KEY,
    source_id INTEGER REFERENCES bronze_data_sources(source_id),
    stage VARCHAR(50) CHECK (stage IN ('bronze_ingestion', 'silver_processing', 'mapping_rules', 'human_review', 'gold_promotion')),
    status VARCHAR(50) CHECK (status IN ('started', 'completed', 'failed', 'skipped')),
    records_processed INTEGER,
    records_failed INTEGER,
    processing_time_ms INTEGER,
    error_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_process_log_source ON processing_log(source_id);
CREATE INDEX idx_process_log_stage ON processing_log(stage);
CREATE INDEX idx_process_log_status ON processing_log(status);

-- ============================================
-- MASTER TAXONOMY METADATA
-- ============================================

-- Table to track master taxonomy versions and changes
CREATE TABLE master_taxonomy_versions (
    version_id SERIAL PRIMARY KEY,
    version_number VARCHAR(20) NOT NULL UNIQUE, -- e.g., "1.0.0"
    description TEXT,
    total_nodes INTEGER,
    total_levels INTEGER,
    created_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_current BOOLEAN DEFAULT FALSE,
    change_summary JSONB -- Track what changed from previous version
);

-- Link taxonomy nodes to versions
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN version_id INTEGER REFERENCES master_taxonomy_versions(version_id);

-- ============================================
-- API CONTRACT TRACKING
-- ============================================

-- Track API contracts and their schemas
CREATE TABLE api_contracts (
    contract_id SERIAL PRIMARY KEY,
    api_name VARCHAR(100) NOT NULL,
    version VARCHAR(20) NOT NULL,
    endpoint_path VARCHAR(255),
    method VARCHAR(10) CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH')),
    request_schema JSONB,
    response_schema JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deprecated_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(api_name, version)
);

-- ============================================
-- OBSERVABILITY IMPROVEMENTS
-- ============================================

-- Enhanced audit log with more context
CREATE TABLE audit_log_enhanced (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER,
    operation VARCHAR(20) CHECK (operation IN ('insert', 'update', 'delete', 'merge')),
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[], -- Array of field names that changed
    user_id VARCHAR(255),
    user_role VARCHAR(100),
    source_system VARCHAR(100), -- Which system initiated the change
    correlation_id UUID, -- To track related changes across tables
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_enhanced_table ON audit_log_enhanced(table_name);
CREATE INDEX idx_audit_enhanced_correlation ON audit_log_enhanced(correlation_id);
CREATE INDEX idx_audit_enhanced_user ON audit_log_enhanced(user_id);
CREATE INDEX idx_audit_enhanced_created ON audit_log_enhanced(created_at DESC);

-- ============================================
-- FUNCTIONS FOR TRACEABILITY
-- ============================================

-- Function to trace data lineage from Gold back to Bronze
CREATE OR REPLACE FUNCTION trace_data_lineage(p_gold_mapping_id INTEGER)
RETURNS TABLE (
    layer VARCHAR(10),
    table_name VARCHAR(100),
    record_id INTEGER,
    source_id INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Gold layer
    RETURN QUERY
    SELECT 'gold'::VARCHAR, 'gold_taxonomies_mapping'::VARCHAR,
           mapping_id, NULL::INTEGER, created_at
    FROM gold_taxonomies_mapping
    WHERE mapping_id = p_gold_mapping_id;

    -- Silver layer
    RETURN QUERY
    SELECT 'silver'::VARCHAR, 'silver_mapping_taxonomies'::VARCHAR,
           s.mapping_id, st.source_id, s.created_at
    FROM silver_mapping_taxonomies s
    JOIN silver_taxonomies_nodes sn ON s.target_node_id = sn.node_id
    JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
    WHERE s.mapping_id = p_gold_mapping_id;

    -- Bronze layer
    RETURN QUERY
    SELECT 'bronze'::VARCHAR, 'bronze_taxonomies'::VARCHAR,
           b.bronze_id, b.source_id, b.load_date
    FROM bronze_taxonomies b
    JOIN silver_taxonomies st ON b.source_id = st.source_id
    JOIN silver_taxonomies_nodes sn ON st.taxonomy_id = sn.taxonomy_id
    JOIN silver_mapping_taxonomies s ON sn.node_id = s.target_node_id
    WHERE s.mapping_id = p_gold_mapping_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- View for complete data lineage
CREATE VIEW v_data_lineage AS
SELECT
    ds.source_name,
    ds.source_type,
    ds.customer_id,
    bt.bronze_id as bronze_record_id,
    st.taxonomy_id as silver_taxonomy_id,
    st.name as taxonomy_name,
    smt.mapping_id as silver_mapping_id,
    gtm.mapping_id as gold_mapping_id,
    ds.created_at as ingestion_date
FROM bronze_data_sources ds
LEFT JOIN bronze_taxonomies bt ON ds.source_id = bt.source_id
LEFT JOIN silver_taxonomies st ON ds.source_id = st.source_id
LEFT JOIN silver_taxonomies_nodes stn ON st.taxonomy_id = stn.taxonomy_id
LEFT JOIN silver_mapping_taxonomies smt ON stn.node_id = smt.node_id
LEFT JOIN gold_taxonomies_mapping gtm ON smt.mapping_id = gtm.mapping_id;

-- View for processing status
CREATE VIEW v_processing_status AS
SELECT
    ds.source_id,
    ds.customer_id,
    ds.source_name,
    ds.import_status,
    MAX(CASE WHEN pl.stage = 'bronze_ingestion' THEN pl.status END) as bronze_status,
    MAX(CASE WHEN pl.stage = 'silver_processing' THEN pl.status END) as silver_status,
    MAX(CASE WHEN pl.stage = 'mapping_rules' THEN pl.status END) as mapping_status,
    MAX(CASE WHEN pl.stage = 'human_review' THEN pl.status END) as review_status,
    MAX(CASE WHEN pl.stage = 'gold_promotion' THEN pl.status END) as gold_status,
    ds.created_at,
    MAX(pl.created_at) as last_processed
FROM bronze_data_sources ds
LEFT JOIN processing_log pl ON ds.source_id = pl.source_id
GROUP BY ds.source_id, ds.customer_id, ds.source_name, ds.import_status, ds.created_at;

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE bronze_data_sources IS 'Tracks all data sources (API calls, files) for Bronze layer ingestion';
COMMENT ON TABLE silver_attribute_types IS 'Catalog of attribute types (not values) per Edwin feedback from Sept 25';
COMMENT ON TABLE processing_log IS 'Tracks data processing stages from Bronze to Gold';
COMMENT ON TABLE master_taxonomy_versions IS 'Version control for master taxonomy changes';
COMMENT ON TABLE api_contracts IS 'API contract definitions discussed on Sept 25';
COMMENT ON TABLE audit_log_enhanced IS 'Enhanced audit logging with correlation for observability';
COMMENT ON COLUMN silver_mapping_taxonomies.target_node_id IS 'Renamed from master_node_id - can map to any taxonomy, not just master';
COMMENT ON FUNCTION trace_data_lineage IS 'Traces data from Gold layer back to Bronze source';