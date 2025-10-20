-- ============================================================================
-- Migration 023: Silver Mapping Taxonomies Updates
-- ============================================================================
-- Date: 2025-01-26
-- Description: Update silver_mapping_taxonomies table per data engineer spec
--              - Add user column (who is responsible for creation/approval)
--              - Add child_node_id as alias for node_id
--              - Update column comments
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD NEW COLUMNS
-- ============================================================================

-- Add user column (user responsible for creation of this mapping)
ALTER TABLE silver_mapping_taxonomies
ADD COLUMN IF NOT EXISTS "user" VARCHAR(255);

-- Add child_node_id as a more descriptive alias (keeping node_id for backward compatibility)
-- Note: In the spec it's called child_node_id but existing code uses node_id
-- We'll add comments to clarify

-- ============================================================================
-- CREATE INDEXES FOR NEW COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_silver_mapping_taxonomies_user
ON silver_mapping_taxonomies("user");

-- ============================================================================
-- ADD/UPDATE COLUMN COMMENTS
-- ============================================================================

COMMENT ON TABLE silver_mapping_taxonomies IS 'Holds mapping results after applying mapping rules to taxonomies';

COMMENT ON COLUMN silver_mapping_taxonomies.mapping_id IS 'Primary surrogate key – mapping ID';
COMMENT ON COLUMN silver_mapping_taxonomies.mapping_rule_id IS 'Foreign key to silver_mapping_taxonomies_rules – indicates which rule was resolved the mapping';
COMMENT ON COLUMN silver_mapping_taxonomies.master_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in master taxonomy';
COMMENT ON COLUMN silver_mapping_taxonomies.node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in child taxonomy (also referred to as child_node_id in documentation)';
COMMENT ON COLUMN silver_mapping_taxonomies.confidence IS 'Confidence score of mapping (100 for command rules, different values for the same nodes mapping if AI rule was used)';
COMMENT ON COLUMN silver_mapping_taxonomies.status IS 'Flag – active or inactive (used for marking which mappings are currently approved used mappings, rest is inactive, sometimes saved for historical purposes)';
COMMENT ON COLUMN silver_mapping_taxonomies."user" IS 'User that is responsible for creation of this mapping, can be technical user or real user if the mapping was created or approved by human';
COMMENT ON COLUMN silver_mapping_taxonomies.created_at IS 'Timestamp when the row was created';
COMMENT ON COLUMN silver_mapping_taxonomies.last_updated_at IS 'Timestamp when the row was last updated';

-- ============================================================================
-- CREATE HELPFUL VIEW WITH CLEARER COLUMN NAMES
-- ============================================================================

CREATE OR REPLACE VIEW v_silver_mapping_taxonomies_detailed AS
SELECT
    m.mapping_id,
    m.mapping_rule_id,
    r.name AS rule_name,
    r.command AS rule_command,
    m.master_node_id,
    master.value AS master_node_value,
    master.profession AS master_profession,
    m.node_id AS child_node_id,
    child.value AS child_node_value,
    child.profession AS child_profession,
    m.confidence,
    m.status,
    m."user",
    m.created_at,
    m.last_updated_at
FROM silver_mapping_taxonomies m
LEFT JOIN silver_mapping_taxonomies_rules r ON m.mapping_rule_id = r.mapping_rule_id
LEFT JOIN silver_taxonomies_nodes master ON m.master_node_id = master.node_id
LEFT JOIN silver_taxonomies_nodes child ON m.node_id = child.node_id;

COMMENT ON VIEW v_silver_mapping_taxonomies_detailed IS 'Detailed view of taxonomy mappings with joined node information and clearer column naming (child_node_id instead of node_id)';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    -- Check user column exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_mapping_taxonomies'
        AND column_name = 'user'
    ) THEN
        RAISE EXCEPTION 'Migration 023 failed: user column not created';
    END IF;

    -- Check view exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.views
        WHERE table_name = 'v_silver_mapping_taxonomies_detailed'
    ) THEN
        RAISE WARNING 'Migration 023: Detailed view not created';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 023: Silver Mapping Taxonomies Updates - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Columns Added: 1';
    RAISE NOTICE '  - user (VARCHAR(255))';
    RAISE NOTICE 'New Indexes Created: 1';
    RAISE NOTICE 'Views Created: 1 (v_silver_mapping_taxonomies_detailed)';
    RAISE NOTICE 'Column Comments Updated: All columns documented';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Note: node_id column represents child_node_id in documentation';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
