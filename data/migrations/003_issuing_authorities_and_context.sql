-- Migration: 003_issuing_authorities_and_context
-- Description: Add issuing authorities, context rules, and attribute combination tracking
-- Author: Propelus AI Team
-- Date: 2025-01-24
-- Based on: Sept 24 meeting insights

-- ============================================
-- ISSUING AUTHORITIES
-- ============================================

-- Table for issuing authorities (boards, certification bodies)
CREATE TABLE silver_issuing_authorities (
    authority_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('state', 'national', 'federal')),
    state_code VARCHAR(2), -- NULL for national/federal
    abbreviation VARCHAR(50),
    full_name TEXT,
    verification_url TEXT, -- Base URL for verification (optional)
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 100, -- Lower number = higher priority
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_issuing_auth_type ON silver_issuing_authorities(type);
CREATE INDEX idx_issuing_auth_state ON silver_issuing_authorities(state_code);
CREATE INDEX idx_issuing_auth_active ON silver_issuing_authorities(is_active);

-- Link professions to their issuing authorities
CREATE TABLE silver_professions_authorities (
    id SERIAL PRIMARY KEY,
    profession_id INTEGER REFERENCES silver_professions(profession_id),
    authority_id INTEGER REFERENCES silver_issuing_authorities(authority_id),
    profession_code VARCHAR(100), -- Authority-specific code
    verification_method VARCHAR(50) CHECK (verification_method IN ('automated', 'manual')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(profession_id, authority_id)
);

CREATE INDEX idx_prof_auth_profession ON silver_professions_authorities(profession_id);
CREATE INDEX idx_prof_auth_authority ON silver_professions_authorities(authority_id);

-- ============================================
-- CONTEXT RULES FOR DISAMBIGUATION
-- ============================================

-- Table for storing context rules and patterns
CREATE TABLE silver_context_rules (
    rule_id SERIAL PRIMARY KEY,
    rule_name VARCHAR(255) NOT NULL,
    rule_type VARCHAR(50) CHECK (rule_type IN ('abbreviation', 'override', 'disambiguation', 'priority')),
    pattern TEXT NOT NULL, -- Regex or exact match pattern
    context_key VARCHAR(100), -- e.g., 'ACLS', 'ARRT', 'RQI'
    context_value TEXT, -- e.g., 'American Heart Association'
    authority_id INTEGER REFERENCES silver_issuing_authorities(authority_id),
    priority INTEGER DEFAULT 100, -- Execution order
    override_state BOOLEAN DEFAULT FALSE, -- TRUE if this rule overrides state attribute
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_context_rules_type ON silver_context_rules(rule_type);
CREATE INDEX idx_context_rules_key ON silver_context_rules(context_key);
CREATE INDEX idx_context_rules_active ON silver_context_rules(is_active, priority);

-- ============================================
-- ATTRIBUTE COMBINATIONS TRACKING
-- ============================================

-- Track unique combinations of attributes seen during mapping
CREATE TABLE silver_attribute_combinations (
    combination_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    state_code VARCHAR(2),
    profession_code VARCHAR(100),
    profession_description TEXT,
    issuing_authority VARCHAR(255),
    additional_attributes JSONB, -- Store any other attributes as JSON
    combination_hash VARCHAR(64) UNIQUE, -- Hash of all attributes for quick lookup
    first_seen_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_seen_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    occurrence_count INTEGER DEFAULT 1,
    mapped_node_id INTEGER REFERENCES silver_taxonomies_nodes(node_id),
    mapping_confidence DECIMAL(5,2),
    mapping_status VARCHAR(20) CHECK (mapping_status IN ('mapped', 'pending', 'failed', 'ambiguous'))
);

CREATE INDEX idx_attr_comb_customer ON silver_attribute_combinations(customer_id);
CREATE INDEX idx_attr_comb_hash ON silver_attribute_combinations(combination_hash);
CREATE INDEX idx_attr_comb_status ON silver_attribute_combinations(mapping_status);
CREATE INDEX idx_attr_comb_state ON silver_attribute_combinations(state_code);

-- ============================================
-- TRANSLATION REQUEST HISTORY
-- ============================================

-- Track translation requests for analysis (not every request, but unique patterns)
CREATE TABLE silver_translation_patterns (
    pattern_id SERIAL PRIMARY KEY,
    source_taxonomy_id INTEGER REFERENCES silver_taxonomies(taxonomy_id),
    target_taxonomy_id INTEGER REFERENCES silver_taxonomies(taxonomy_id),
    source_code VARCHAR(100),
    source_attributes JSONB,
    result_count INTEGER, -- Number of matches returned
    result_codes TEXT[], -- Array of returned codes
    is_ambiguous BOOLEAN DEFAULT FALSE,
    resolution_method VARCHAR(50), -- 'automatic', 'rule_based', 'human_review'
    first_requested TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_requested TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    request_count INTEGER DEFAULT 1
);

CREATE INDEX idx_trans_pattern_source ON silver_translation_patterns(source_taxonomy_id);
CREATE INDEX idx_trans_pattern_target ON silver_translation_patterns(target_taxonomy_id);
CREATE INDEX idx_trans_pattern_ambiguous ON silver_translation_patterns(is_ambiguous);

-- ============================================
-- ENHANCED MAPPING TABLES
-- ============================================

-- Add issuing authority to taxonomy node mappings
ALTER TABLE silver_mapping_taxonomies
ADD COLUMN authority_id INTEGER REFERENCES silver_issuing_authorities(authority_id),
ADD COLUMN requires_authority BOOLEAN DEFAULT FALSE;

-- Add issuing authority to profession mappings
ALTER TABLE silver_mapping_professions
ADD COLUMN authority_id INTEGER REFERENCES silver_issuing_authorities(authority_id),
ADD COLUMN requires_state BOOLEAN DEFAULT FALSE;

-- ============================================
-- FUNCTIONS AND TRIGGERS
-- ============================================

-- Function to generate combination hash
CREATE OR REPLACE FUNCTION generate_combination_hash(
    p_customer_id INTEGER,
    p_state_code VARCHAR(2),
    p_profession_code VARCHAR(100),
    p_profession_description TEXT,
    p_issuing_authority VARCHAR(255),
    p_additional_attributes JSONB
) RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN MD5(
        COALESCE(p_customer_id::TEXT, '') || '|' ||
        COALESCE(p_state_code, '') || '|' ||
        COALESCE(p_profession_code, '') || '|' ||
        COALESCE(p_profession_description, '') || '|' ||
        COALESCE(p_issuing_authority, '') || '|' ||
        COALESCE(p_additional_attributes::TEXT, '{}')
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger to auto-generate combination hash
CREATE OR REPLACE FUNCTION auto_generate_hash() RETURNS TRIGGER AS $$
BEGIN
    NEW.combination_hash = generate_combination_hash(
        NEW.customer_id,
        NEW.state_code,
        NEW.profession_code,
        NEW.profession_description,
        NEW.issuing_authority,
        NEW.additional_attributes
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_combination_hash_trigger
    BEFORE INSERT OR UPDATE ON silver_attribute_combinations
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_hash();

-- Function to update last seen date and count
CREATE OR REPLACE FUNCTION update_combination_stats() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        NEW.last_seen_date = CURRENT_TIMESTAMP;
        NEW.occurrence_count = OLD.occurrence_count + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_combination_stats_trigger
    BEFORE UPDATE ON silver_attribute_combinations
    FOR EACH ROW
    EXECUTE FUNCTION update_combination_stats();

-- ============================================
-- INITIAL DATA - Common Issuing Authorities
-- ============================================

-- Insert state authorities
INSERT INTO silver_issuing_authorities (name, type, state_code, abbreviation, priority) VALUES
('Alabama Board of Nursing', 'state', 'AL', 'AL BON', 50),
('California Board of Registered Nursing', 'state', 'CA', 'CA BRN', 50),
('Florida Board of Nursing', 'state', 'FL', 'FL BON', 50),
('Texas Board of Nursing', 'state', 'TX', 'TX BON', 50),
('Washington State Nursing Commission', 'state', 'WA', 'WA NC', 50);

-- Insert national certification authorities
INSERT INTO silver_issuing_authorities (name, type, abbreviation, full_name, priority, override_state) VALUES
('American Heart Association', 'national', 'AHA', 'American Heart Association', 10, TRUE),
('American Registry of Radiologic Technologists', 'national', 'ARRT', 'American Registry of Radiologic Technologists', 10, TRUE),
('American Hospital Association', 'national', 'AHA-H', 'American Hospital Association', 20, TRUE),
('National Board of Certification & Recertification for Nurse Anesthetists', 'national', 'NBCRNA', 'National Board of Certification & Recertification for Nurse Anesthetists', 10, TRUE);

-- Insert context rules for common abbreviations
INSERT INTO silver_context_rules (rule_name, rule_type, pattern, context_key, context_value, priority, override_state, notes) VALUES
('ACLS to AHA', 'abbreviation', '^ACLS', 'ACLS', 'American Heart Association', 10, FALSE, 'Advanced Cardiovascular Life Support'),
('ARRT National Override', 'override', 'AR[R]?T', 'ARRT', 'American Registry of Radiologic Technologists', 5, TRUE, 'ARRT overrides any state attribute'),
('RQI Context', 'disambiguation', 'RQI', 'RQI', 'Resuscitation Quality Improvement', 20, FALSE, 'Can be AHA or facility-specific'),
('BLS to AHA', 'abbreviation', '^BLS', 'BLS', 'American Heart Association', 10, FALSE, 'Basic Life Support'),
('PALS to AHA', 'abbreviation', '^PALS', 'PALS', 'American Heart Association', 10, FALSE, 'Pediatric Advanced Life Support'),
('NRP Context', 'abbreviation', '^NRP', 'NRP', 'American Academy of Pediatrics', 15, FALSE, 'Neonatal Resuscitation Program');

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- View for professions with their authorities
CREATE VIEW v_professions_with_authorities AS
SELECT
    p.profession_id,
    p.customer_id,
    p.name as profession_name,
    pa.profession_code as authority_code,
    ia.authority_id,
    ia.name as authority_name,
    ia.type as authority_type,
    ia.state_code,
    pa.verification_method
FROM silver_professions p
LEFT JOIN silver_professions_authorities pa ON p.profession_id = pa.profession_id
LEFT JOIN silver_issuing_authorities ia ON pa.authority_id = ia.authority_id;

-- View for attribute combinations with mapping status
CREATE VIEW v_attribute_combinations_summary AS
SELECT
    ac.customer_id,
    ac.state_code,
    ac.profession_code,
    ac.profession_description,
    ac.mapping_status,
    ac.mapping_confidence,
    ac.occurrence_count,
    tn.value as mapped_to_value,
    tnt.name as mapped_to_type
FROM silver_attribute_combinations ac
LEFT JOIN silver_taxonomies_nodes tn ON ac.mapped_node_id = tn.node_id
LEFT JOIN silver_taxonomies_nodes_types tnt ON tn.node_type_id = tnt.node_type_id;

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE silver_issuing_authorities IS 'Stores all issuing authorities including state boards and national certification bodies';
COMMENT ON TABLE silver_professions_authorities IS 'Links professions to their issuing authorities with authority-specific codes';
COMMENT ON TABLE silver_context_rules IS 'Defines context rules for disambiguating abbreviations and handling special cases';
COMMENT ON TABLE silver_attribute_combinations IS 'Tracks unique combinations of attributes seen during mapping for pattern recognition';
COMMENT ON TABLE silver_translation_patterns IS 'Stores patterns of translation requests for analysis and optimization';
COMMENT ON COLUMN silver_context_rules.override_state IS 'If TRUE, this rule overrides any state attribute provided (e.g., ARRT is always national)';
COMMENT ON COLUMN silver_attribute_combinations.combination_hash IS 'MD5 hash of all attributes for quick duplicate detection';