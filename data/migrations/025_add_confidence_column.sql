-- ============================================================================
-- Migration 025: Add Confidence Column to Silver Mapping Taxonomies
-- ============================================================================
-- Date: 2025-01-26
-- Description: Add confidence score column to silver_mapping_taxonomies table
--              - confidence: Confidence score of mapping (100 for command rules,
--                different values for AI-based mappings)
-- ============================================================================

BEGIN;

-- ============================================================================
-- ADD CONFIDENCE COLUMN
-- ============================================================================

-- Add confidence column (numeric score 0-100)
ALTER TABLE silver_mapping_taxonomies
ADD COLUMN IF NOT EXISTS confidence NUMERIC(5,2) DEFAULT 100.00;

-- Add check constraint to ensure confidence is between 0 and 100
ALTER TABLE silver_mapping_taxonomies
ADD CONSTRAINT chk_silver_mapping_taxonomies_confidence
CHECK (confidence >= 0 AND confidence <= 100);

-- ============================================================================
-- CREATE INDEX FOR CONFIDENCE QUERIES
-- ============================================================================

-- Index for filtering by confidence threshold (e.g., low-confidence mappings)
CREATE INDEX IF NOT EXISTS idx_silver_mapping_taxonomies_confidence
ON silver_mapping_taxonomies(confidence);

-- Index for status + confidence queries (find low-confidence active mappings)
CREATE INDEX IF NOT EXISTS idx_silver_mapping_taxonomies_status_confidence
ON silver_mapping_taxonomies(status, confidence);

-- ============================================================================
-- ADD COLUMN COMMENT
-- ============================================================================

COMMENT ON COLUMN silver_mapping_taxonomies.confidence IS 'Confidence score of mapping (100 for command rules, different values for the same nodes mapping if AI rule was used). Range: 0-100';

-- ============================================================================
-- UPDATE EXISTING VIEW
-- ============================================================================

-- Drop and recreate the detailed view with confidence column
DROP VIEW IF EXISTS v_silver_mapping_taxonomies_detailed;

CREATE OR REPLACE VIEW v_silver_mapping_taxonomies_detailed AS
SELECT
    m.mapping_id,
    m.mapping_rule_id,
    r.name AS rule_name,
    r.command AS rule_command,
    m.master_node_id,
    master.value AS master_node_value,
    master.profession AS master_profession,
    m.child_node_id,
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
LEFT JOIN silver_taxonomies_nodes child ON m.child_node_id = child.node_id;

COMMENT ON VIEW v_silver_mapping_taxonomies_detailed IS 'Detailed view of taxonomy mappings with joined node information including confidence scores';

-- ============================================================================
-- CREATE HELPER VIEW FOR LOW-CONFIDENCE MAPPINGS
-- ============================================================================

CREATE OR REPLACE VIEW v_low_confidence_mappings AS
SELECT
    m.mapping_id,
    m.confidence,
    m.status,
    master.value AS master_node_value,
    child.value AS child_node_value,
    master.taxonomy_id AS master_taxonomy_id,
    child.taxonomy_id AS child_taxonomy_id,
    r.name AS rule_name,
    r.command AS rule_command,
    m.created_at
FROM silver_mapping_taxonomies m
LEFT JOIN silver_mapping_taxonomies_rules r ON m.mapping_rule_id = r.mapping_rule_id
LEFT JOIN silver_taxonomies_nodes master ON m.master_node_id = master.node_id
LEFT JOIN silver_taxonomies_nodes child ON m.child_node_id = child.node_id
WHERE m.confidence < 80.00
AND m.status = 'active'
ORDER BY m.confidence ASC;

COMMENT ON VIEW v_low_confidence_mappings IS 'View showing all active mappings with confidence score below 80% that may need human review';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_column_exists BOOLEAN;
    v_constraint_exists BOOLEAN;
    v_index_count INTEGER;
BEGIN
    -- Check confidence column exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'silver_mapping_taxonomies'
        AND column_name = 'confidence'
    ) INTO v_column_exists;

    IF NOT v_column_exists THEN
        RAISE EXCEPTION 'Migration 025 failed: confidence column not created';
    END IF;

    -- Check constraint exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_name = 'silver_mapping_taxonomies'
        AND constraint_name = 'chk_silver_mapping_taxonomies_confidence'
    ) INTO v_constraint_exists;

    IF NOT v_constraint_exists THEN
        RAISE WARNING 'Migration 025: Check constraint not created';
    END IF;

    -- Check indexes exist
    SELECT COUNT(*)
    FROM pg_indexes
    WHERE tablename = 'silver_mapping_taxonomies'
    AND indexname LIKE '%confidence%'
    INTO v_index_count;

    IF v_index_count < 2 THEN
        RAISE WARNING 'Migration 025: Not all confidence indexes were created';
    END IF;

    -- Check views exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.views
        WHERE table_name = 'v_low_confidence_mappings'
    ) THEN
        RAISE WARNING 'Migration 025: Low confidence mappings view not created';
    END IF;

    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 025: Add Confidence Column - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Columns Added: 1';
    RAISE NOTICE '  - confidence (NUMERIC(5,2), default 100.00, range 0-100)';
    RAISE NOTICE 'New Constraints: 1';
    RAISE NOTICE '  - chk_silver_mapping_taxonomies_confidence (0 <= confidence <= 100)';
    RAISE NOTICE 'New Indexes Created: 2';
    RAISE NOTICE '  - idx_silver_mapping_taxonomies_confidence';
    RAISE NOTICE '  - idx_silver_mapping_taxonomies_status_confidence';
    RAISE NOTICE 'Views Updated: 1 (v_silver_mapping_taxonomies_detailed)';
    RAISE NOTICE 'Views Created: 1 (v_low_confidence_mappings)';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Default Value: 100.00 (perfect confidence for command-based rules)';
    RAISE NOTICE 'Use Case: AI-based mappings will have variable confidence scores';
    RAISE NOTICE '=============================================================================';
END $$;

COMMIT;
