-- Migration: 007_silver_structure_updates
-- Description: Silver Layer Structure Updates per Marcin's Data Model v0.42
-- Author: Propelus AI Team - Data Model Update
-- Date: 2025-01-11

-- ============================================================================
-- SILVER_TAXONOMIES_NODES TABLE UPDATES
-- ============================================================================

-- Add new columns to silver_taxonomies_nodes as per Marcin's specification
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN profession VARCHAR(500),
ADD COLUMN level INTEGER DEFAULT 1;

-- Add comments for new columns
COMMENT ON COLUMN silver_taxonomies_nodes.profession IS 'Name of the profession, for last leaf of hierarchy it will be always identical as the value';
COMMENT ON COLUMN silver_taxonomies_nodes.level IS 'Hierarchy level in taxonomy, numbers, 1 for root leaf of the hierarchy';

-- Update profession field for leaf nodes (nodes that don't have children)
UPDATE silver_taxonomies_nodes
SET profession = value
WHERE node_id NOT IN (
    SELECT DISTINCT parent_node_id
    FROM silver_taxonomies_nodes
    WHERE parent_node_id IS NOT NULL
);

-- Update level field based on hierarchy depth
-- This creates a recursive CTE to calculate proper levels
WITH RECURSIVE node_levels AS (
    -- Base case: root nodes (no parent) are level 1
    SELECT node_id, parent_node_id, value, 1 as calculated_level
    FROM silver_taxonomies_nodes
    WHERE parent_node_id IS NULL

    UNION ALL

    -- Recursive case: children are parent level + 1
    SELECT n.node_id, n.parent_node_id, n.value, nl.calculated_level + 1
    FROM silver_taxonomies_nodes n
    JOIN node_levels nl ON n.parent_node_id = nl.node_id
)
UPDATE silver_taxonomies_nodes
SET level = nl.calculated_level
FROM node_levels nl
WHERE silver_taxonomies_nodes.node_id = nl.node_id;

-- Create index on new level column for hierarchy queries
CREATE INDEX idx_silver_taxonomies_nodes_level ON silver_taxonomies_nodes(level);

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES_RULES TABLE UPDATES
-- ============================================================================

-- Add new fields to silver_mapping_taxonomies_rules
ALTER TABLE silver_mapping_taxonomies_rules
ADD COLUMN AI_mapping_flag BOOLEAN DEFAULT FALSE,
ADD COLUMN Human_mapping_flag BOOLEAN DEFAULT FALSE,
ADD COLUMN command VARCHAR(255);

-- Add comments for new columns
COMMENT ON COLUMN silver_mapping_taxonomies_rules.AI_mapping_flag IS 'True or False indicates if this rule is connected to the AI-based mappings';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.Human_mapping_flag IS 'True or False indicates if this rule is connected to the Human-based mappings';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.command IS 'Command executed by rule (for example: regex, special values: AI – for AI mappings, Human – for Human mappings)';

-- Update existing rules with appropriate flags based on rule type
UPDATE silver_mapping_taxonomies_rules
SET AI_mapping_flag = TRUE,
    command = 'AI'
WHERE name ILIKE '%ai%' OR name ILIKE '%semantic%' OR name ILIKE '%llm%';

UPDATE silver_mapping_taxonomies_rules
SET Human_mapping_flag = TRUE,
    command = 'Human'
WHERE name ILIKE '%human%' OR name ILIKE '%manual%' OR name ILIKE '%review%';

-- Set default command for existing rules without specific type
UPDATE silver_mapping_taxonomies_rules
SET command = COALESCE(
    CASE
        WHEN pattern IS NOT NULL AND pattern != '' THEN 'regex'
        WHEN action IS NOT NULL AND action != '' THEN 'action'
        ELSE 'exact_match'
    END,
    'exact_match'
)
WHERE command IS NULL;

-- Create indexes on new columns
CREATE INDEX idx_silver_mapping_rules_ai_flag ON silver_mapping_taxonomies_rules(AI_mapping_flag);
CREATE INDEX idx_silver_mapping_rules_human_flag ON silver_mapping_taxonomies_rules(Human_mapping_flag);
CREATE INDEX idx_silver_mapping_rules_command ON silver_mapping_taxonomies_rules(command);

-- ============================================================================
-- RENAME AND UPDATE RULES ASSIGNMENT TABLE
-- ============================================================================

-- Rename the table as per Marcin's specification (note: keeping typo from spec)
ALTER TABLE silver_mapping_taxonomies_rules_assignment
RENAME TO silver_mapping_taxonomies_rules_assigment;

-- Update the primary key column name
ALTER TABLE silver_mapping_taxonomies_rules_assigment
RENAME COLUMN mapping_rule_assignment_id TO mapping_rule_assigment_id;

-- Rename node_type_id to Child_node_type_id as per specification
ALTER TABLE silver_mapping_taxonomies_rules_assigment
RENAME COLUMN node_type_id TO Child_node_type_id;

-- Add comments for clarity
COMMENT ON TABLE silver_mapping_taxonomies_rules_assigment IS 'Assigns mapping rules to node types and set ups priorities for using rules';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assigment.mapping_rule_assigment_id IS 'Primary surrogate key - assignment ID';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assigment.Child_node_type_id IS 'Foreign key to silver_taxonomies_nodes_types indicates the type of node in child taxonomy';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assigment.master_node_type_id IS 'Foreign key to silver_taxonomies_nodes_types indicates the type of node in master taxonomy';

-- ============================================================================
-- UPDATE SILVER_MAPPING_TAXONOMIES TABLE
-- ============================================================================

-- Rename node_id to child_node_id for consistency
ALTER TABLE silver_mapping_taxonomies
RENAME COLUMN node_id TO child_node_id;

-- Add user column
ALTER TABLE silver_mapping_taxonomies
ADD COLUMN user VARCHAR(255);

-- Add comments for new/updated columns
COMMENT ON COLUMN silver_mapping_taxonomies.child_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in child taxonomy';
COMMENT ON COLUMN silver_mapping_taxonomies.user IS 'User that is responsible for creation of this mapping, can be technical user or real user if the mapping was created or approved by human';

-- Set default user for existing mappings
UPDATE silver_mapping_taxonomies
SET user = 'system_migration'
WHERE user IS NULL;

-- Update foreign key constraint name if needed
DO $$
BEGIN
    -- Drop old constraint if it exists
    IF EXISTS (SELECT constraint_name FROM information_schema.table_constraints
               WHERE table_name = 'silver_mapping_taxonomies'
               AND constraint_name LIKE '%node_id%') THEN
        ALTER TABLE silver_mapping_taxonomies DROP CONSTRAINT
            (SELECT constraint_name FROM information_schema.table_constraints
             WHERE table_name = 'silver_mapping_taxonomies'
             AND constraint_name LIKE '%node_id%' LIMIT 1);
    END IF;

    -- Add new constraint with updated name
    ALTER TABLE silver_mapping_taxonomies
    ADD CONSTRAINT fk_silver_mapping_taxonomies_child_node_id
    FOREIGN KEY (child_node_id) REFERENCES silver_taxonomies_nodes(node_id);
END $$;

-- Create index on user column
CREATE INDEX idx_silver_mapping_taxonomies_user ON silver_mapping_taxonomies(user);

-- ============================================================================
-- UPDATE TABLE COMMENTS FOR CONSISTENCY
-- ============================================================================

COMMENT ON TABLE silver_mapping_taxonomies IS 'Holds mapping results after applying mapping rules to taxonomies';
COMMENT ON COLUMN silver_mapping_taxonomies.mapping_id IS 'Primary surrogate key – mapping ID';
COMMENT ON COLUMN silver_mapping_taxonomies.mapping_rule_id IS 'Foreign key to silver_mapping_taxonomies_rules – indicates with rule was resolved the mapping';
COMMENT ON COLUMN silver_mapping_taxonomies.master_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in master taxonomy';
COMMENT ON COLUMN silver_mapping_taxonomies.confidence IS 'Confidence score of mapping (100 for command rules, different values for the same nodes mapping if AI rule was used)';
COMMENT ON COLUMN silver_mapping_taxonomies.status IS 'Flag – active or inactive (used for marking with mappings are currently approved used mappings, rest is inactive, sometimes saved for historical purposes)';

-- ============================================================================
-- CREATE TRIGGER FOR LAST_UPDATED_AT MAINTENANCE
-- ============================================================================

-- Create or replace function to update last_updated_at timestamp
CREATE OR REPLACE FUNCTION update_last_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tables that have last_updated_at column
DO $$
DECLARE
    table_record RECORD;
BEGIN
    FOR table_record IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE tablename LIKE 'silver_%'
        AND schemaname = 'public'
    LOOP
        -- Check if table has last_updated_at column
        IF EXISTS (
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = table_record.tablename
            AND column_name = 'last_updated_at'
        ) THEN
            -- Create trigger
            EXECUTE format('DROP TRIGGER IF EXISTS update_%s_last_updated_at ON %I',
                         table_record.tablename, table_record.tablename);
            EXECUTE format('CREATE TRIGGER update_%s_last_updated_at
                           BEFORE UPDATE ON %I
                           FOR EACH ROW EXECUTE FUNCTION update_last_updated_at()',
                         table_record.tablename, table_record.tablename);
        END IF;
    END LOOP;
END $$;