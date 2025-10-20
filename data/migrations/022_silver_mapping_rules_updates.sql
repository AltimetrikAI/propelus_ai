-- ============================================================================
-- Migration 022: Silver Mapping Taxonomies Rules Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_mapping_taxonomies_rules table per data engineer spec
--              - Add command column
--              - Add AI_mapping_flag column
--              - Add Human_mapping_flag column
--              - Update column comments
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD NEW COLUMNS
-- ============================================================================

-- Add command column (command executed by rule)
ALTER TABLE silver_mapping_taxonomies_rules
ADD COLUMN IF NOT EXISTS command VARCHAR(100);

-- Add AI_mapping_flag
ALTER TABLE silver_mapping_taxonomies_rules
ADD COLUMN IF NOT EXISTS AI_mapping_flag BOOLEAN DEFAULT FALSE NOT NULL;

-- Add Human_mapping_flag
ALTER TABLE silver_mapping_taxonomies_rules
ADD COLUMN IF NOT EXISTS Human_mapping_flag BOOLEAN DEFAULT FALSE NOT NULL;

-- ============================================================================
-- CREATE INDEXES FOR NEW COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_mapping_rules_command
ON silver_mapping_taxonomies_rules(command);

CREATE INDEX IF NOT EXISTS idx_silver_mapping_rules_ai_flag
ON silver_mapping_taxonomies_rules(AI_mapping_flag);

CREATE INDEX IF NOT EXISTS idx_silver_mapping_rules_human_flag
ON silver_mapping_taxonomies_rules(Human_mapping_flag);

CREATE INDEX IF NOT EXISTS idx_silver_mapping_rules_enabled_ai
ON silver_mapping_taxonomies_rules(enabled, AI_mapping_flag);

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_mapping_taxonomies_rules IS 'Stores automated mapping rules that determine how taxonomy nodes will be mapped to each other between taxonomies';

COMMENT ON COLUMN silver_mapping_taxonomies_rules.mapping_rule_id IS 'Primary surrogate key - rule ID';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.name IS 'Rule name, should indicate the algorithm of the rule';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.enabled IS 'Flag – active or inactive (used for current mappings or saved for historical purposes)';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.pattern IS 'Pattern used in executed command';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.attributes IS 'Attributes used with executed command';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.flags IS 'Flags used with executed command';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.action IS 'Action that command is performing';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.command IS 'Command executed by rule (for example: regex, special values: AI – for rule types connected to AI mappings, Human – for rule types connected to Human mappings)';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.AI_mapping_flag IS 'True or False indicates if this rule is connected to the AI-based mappings';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.Human_mapping_flag IS 'True or False indicates if this rule is connected to the Human-based mappings';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_mapping_taxonomies_rules.last_updated_at IS 'Timestamp when the row was last updated';

-- ============================================================================
-- UPDATE rules_assignment TABLE COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_mapping_taxonomies_rules_assignment IS 'Assigns mapping rules to node types and sets up priorities for using rules';

COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.mapping_rule_assignment_id IS 'Primary surrogate key - assignment ID';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.mapping_rule_id IS 'Foreign key to silver_mapping_taxonomies_rules';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.master_node_type_id IS 'Foreign key to silver_taxonomies_nodes_types indicates the type of node in master taxonomy';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.priority IS 'Priority of rule execution, number – indicates in which order the rules will be applied';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.enabled IS 'Flag – active or inactive (used for current mappings or saved for historical purposes)';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.last_updated_at IS 'Timestamp when the row was last updated';

-- Note: The assignment table has a "node_type_id" column which appears to be the child node type
-- Adding comment for clarification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_mapping_taxonomies_rules_assignment'
        AND column_name = 'node_type_id'
    ) THEN
        COMMENT ON COLUMN silver_mapping_taxonomies_rules_assignment.node_type_id IS 'Foreign key to silver_taxonomies_nodes_types indicates the type of node in child taxonomy (renamed in spec to Child_node_type_id but kept as node_type_id for backward compatibility)';
    END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
BEGIN
    -- Check new columns exist
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'silver_mapping_taxonomies_rules'
    AND column_name IN ('command', 'AI_mapping_flag', 'Human_mapping_flag');

    IF col_count <> 3 THEN
        RAISE EXCEPTION 'Migration 022 failed: Expected 3 new columns, found %', col_count;
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 022: Silver Mapping Rules Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Columns Added: 3';
    RAISE NOTICE '  - command (VARCHAR(100))';
    RAISE NOTICE '  - AI_mapping_flag (BOOLEAN, default FALSE)';
    RAISE NOTICE '  - Human_mapping_flag (BOOLEAN, default FALSE)';
    RAISE NOTICE 'New Indexes Created: 4';
    RAISE NOTICE 'Column Comments Updated: All columns documented';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
