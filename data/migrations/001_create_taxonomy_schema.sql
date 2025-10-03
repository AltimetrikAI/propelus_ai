-- Migration: 001_create_taxonomy_schema
-- Description: Initial schema for Profession Taxonomy SSOT
-- Author: Propelus AI Team
-- Date: 2025-01-11

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE profession_status AS ENUM ('active', 'inactive', 'deprecated');
CREATE TYPE translation_method AS ENUM ('ai', 'exact_match', 'fuzzy_match', 'manual', 'rule_based');
CREATE TYPE audit_action AS ENUM ('create', 'update', 'delete', 'approve', 'reject');

-- Core professions table (hierarchical taxonomy)
CREATE TABLE professions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    parent_id UUID REFERENCES professions(id) ON DELETE CASCADE,
    level INT NOT NULL CHECK (level >= 0),
    path TEXT, -- Materialized path for efficient hierarchy queries
    status profession_status DEFAULT 'active',
    
    -- Metadata fields
    description TEXT,
    regulatory_body VARCHAR(255),
    license_required BOOLEAN DEFAULT false,
    specializations JSONB DEFAULT '[]'::jsonb,
    related_codes JSONB DEFAULT '[]'::jsonb, -- Links to external systems
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    
    -- Constraints
    CONSTRAINT valid_parent CHECK (parent_id != id),
    CONSTRAINT valid_path CHECK (path IS NOT NULL OR parent_id IS NULL)
);

-- Indexes for performance
CREATE INDEX idx_professions_parent ON professions(parent_id);
CREATE INDEX idx_professions_code ON professions(code);
CREATE INDEX idx_professions_status ON professions(status);
CREATE INDEX idx_professions_path ON professions(path);
CREATE INDEX idx_professions_path_gin ON professions USING gin(path gin_trgm_ops);

-- Profession aliases table
CREATE TABLE profession_aliases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profession_id UUID NOT NULL REFERENCES professions(id) ON DELETE CASCADE,
    alias VARCHAR(255) NOT NULL,
    alias_type VARCHAR(50), -- 'abbreviation', 'common_name', 'legacy_code', etc.
    source_system VARCHAR(100),
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    
    -- Ensure unique aliases per profession
    CONSTRAINT unique_profession_alias UNIQUE (profession_id, alias)
);

CREATE INDEX idx_aliases_profession ON profession_aliases(profession_id);
CREATE INDEX idx_aliases_alias ON profession_aliases(alias);
CREATE INDEX idx_aliases_alias_trgm ON profession_aliases USING gin(alias gin_trgm_ops);

-- Translation history table
CREATE TABLE translations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Input data
    input_text TEXT NOT NULL,
    input_context JSONB, -- Additional context provided
    source_system VARCHAR(100),
    
    -- Translation results
    matched_profession_id UUID REFERENCES professions(id),
    confidence_score DECIMAL(5,4) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    method translation_method NOT NULL,
    alternative_matches JSONB DEFAULT '[]'::jsonb, -- Other possible matches
    
    -- Processing metadata
    processing_time_ms INT,
    model_version VARCHAR(50),
    model_response JSONB, -- Full model response for debugging
    
    -- Review status
    reviewed BOOLEAN DEFAULT false,
    reviewed_by VARCHAR(255),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_translations_input ON translations(input_text);
CREATE INDEX idx_translations_profession ON translations(matched_profession_id);
CREATE INDEX idx_translations_reviewed ON translations(reviewed);
CREATE INDEX idx_translations_created ON translations(created_at DESC);
CREATE INDEX idx_translations_confidence ON translations(confidence_score);

-- Audit log table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action audit_action NOT NULL,
    
    -- Change tracking
    old_values JSONB,
    new_values JSONB,
    changes JSONB, -- Computed diff
    
    -- User tracking
    user_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255),
    user_role VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    
    -- Additional context
    request_id UUID,
    session_id VARCHAR(255),
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_action ON audit_logs(action);

-- Hierarchy closure table for efficient ancestry queries
CREATE TABLE profession_hierarchy (
    ancestor_id UUID NOT NULL REFERENCES professions(id) ON DELETE CASCADE,
    descendant_id UUID NOT NULL REFERENCES professions(id) ON DELETE CASCADE,
    depth INT NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX idx_hierarchy_ancestor ON profession_hierarchy(ancestor_id);
CREATE INDEX idx_hierarchy_descendant ON profession_hierarchy(descendant_id);

-- Translation rules table for deterministic mappings
CREATE TABLE translation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pattern TEXT NOT NULL, -- Regex pattern
    profession_id UUID NOT NULL REFERENCES professions(id),
    priority INT DEFAULT 100,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255)
);

CREATE INDEX idx_rules_active ON translation_rules(is_active);
CREATE INDEX idx_rules_priority ON translation_rules(priority DESC);

-- Create update trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_professions_updated_at 
    BEFORE UPDATE ON professions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function to maintain hierarchy closure table
CREATE OR REPLACE FUNCTION maintain_hierarchy_closure()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Insert self-reference
        INSERT INTO profession_hierarchy (ancestor_id, descendant_id, depth)
        VALUES (NEW.id, NEW.id, 0);
        
        -- Insert ancestry relationships
        IF NEW.parent_id IS NOT NULL THEN
            INSERT INTO profession_hierarchy (ancestor_id, descendant_id, depth)
            SELECT ancestor_id, NEW.id, depth + 1
            FROM profession_hierarchy
            WHERE descendant_id = NEW.parent_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM profession_hierarchy 
        WHERE descendant_id = OLD.id OR ancestor_id = OLD.id;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER maintain_hierarchy
    AFTER INSERT OR DELETE ON professions
    FOR EACH ROW
    EXECUTE FUNCTION maintain_hierarchy_closure();

-- Function to calculate materialized path
CREATE OR REPLACE FUNCTION calculate_path()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parent_id IS NULL THEN
        NEW.path = '/' || NEW.id::text || '/';
    ELSE
        SELECT path || NEW.id::text || '/'
        INTO NEW.path
        FROM professions
        WHERE id = NEW.parent_id;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_profession_path
    BEFORE INSERT OR UPDATE OF parent_id ON professions
    FOR EACH ROW
    EXECUTE FUNCTION calculate_path();

-- Create views for common queries
CREATE VIEW profession_tree AS
SELECT 
    p.id,
    p.code,
    p.name,
    p.display_name,
    p.level,
    p.parent_id,
    pp.name as parent_name,
    p.status,
    p.path,
    COUNT(DISTINCT c.id) as child_count,
    COUNT(DISTINCT a.id) as alias_count
FROM professions p
LEFT JOIN professions pp ON p.parent_id = pp.id
LEFT JOIN professions c ON c.parent_id = p.id
LEFT JOIN profession_aliases a ON a.profession_id = p.id
GROUP BY p.id, p.code, p.name, p.display_name, p.level, 
         p.parent_id, pp.name, p.status, p.path;

-- Create materialized view for translation performance
CREATE MATERIALIZED VIEW profession_search_index AS
SELECT 
    p.id,
    p.code,
    p.name,
    p.display_name,
    p.status,
    p.level,
    p.path,
    to_tsvector('english', p.name || ' ' || p.display_name || ' ' || COALESCE(p.description, '')) as search_vector,
    array_agg(DISTINCT a.alias) FILTER (WHERE a.alias IS NOT NULL) as aliases
FROM professions p
LEFT JOIN profession_aliases a ON a.profession_id = p.id
WHERE p.status = 'active'
GROUP BY p.id, p.code, p.name, p.display_name, p.status, p.level, p.path, p.description;

CREATE INDEX idx_search_vector ON profession_search_index USING gin(search_vector);

-- Add comments for documentation
COMMENT ON TABLE professions IS 'Core taxonomy table storing hierarchical profession classifications';
COMMENT ON TABLE profession_aliases IS 'Alternative names and codes for professions';
COMMENT ON TABLE translations IS 'History of all translation requests and their results';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all system changes';
COMMENT ON TABLE profession_hierarchy IS 'Closure table for efficient hierarchy queries';
COMMENT ON TABLE translation_rules IS 'Deterministic rules for pattern-based translations';