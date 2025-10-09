-- ============================================================================
-- Migration: 001 - Create N/A Node Type
-- Purpose: Initialize N/A placeholder node type for hierarchy gap filling
-- Author: Martin (Data Engineer)
-- Date: October 2024
-- Reference: Meeting transcript Oct 8, 2024 - Martin's N/A approach decision
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- STEP 1: Create N/A Node Type
-- ============================================================================
-- This is the core of Martin's approach - a special node type with ID -1
-- that represents "Not Available" placeholders in the taxonomy hierarchy

INSERT INTO silver_taxonomies_nodes_types (
    node_type_id,
    name,
    status,
    created_at,
    last_updated_at
)
VALUES (
    -1,           -- Reserved ID for N/A node type
    'N/A',        -- Node type name
    'active',     -- Status
    NOW(),
    NOW()
)
ON CONFLICT (node_type_id) DO UPDATE
SET
    name = EXCLUDED.name,
    status = EXCLUDED.status,
    last_updated_at = NOW();

-- Verify insertion
DO $$
DECLARE
    na_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO na_count
    FROM silver_taxonomies_nodes_types
    WHERE node_type_id = -1;

    IF na_count = 1 THEN
        RAISE NOTICE '✓ N/A node type created successfully (node_type_id = -1)';
    ELSE
        RAISE EXCEPTION '✗ Failed to create N/A node type';
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Create Performance Index for N/A Filtering
-- ============================================================================
-- Partial index to optimize queries that exclude N/A nodes
-- Most display/UI queries will filter WHERE node_type_id != -1

CREATE INDEX IF NOT EXISTS idx_nodes_exclude_na
ON silver_taxonomies_nodes (node_type_id, status, taxonomy_id, parent_node_id)
WHERE node_type_id != -1 AND status = 'active';

-- Index for finding N/A nodes quickly
CREATE INDEX IF NOT EXISTS idx_nodes_na_only
ON silver_taxonomies_nodes (taxonomy_id, level, parent_node_id)
WHERE node_type_id = -1;

RAISE NOTICE '✓ Performance indexes created';

-- ============================================================================
-- STEP 3: Add Comments for Documentation
-- ============================================================================

COMMENT ON TABLE silver_taxonomies_nodes_types IS
'Node types for taxonomy hierarchies. Special node_type_id = -1 represents N/A placeholder nodes used to fill hierarchy gaps.';

COMMENT ON COLUMN silver_taxonomies_nodes_types.node_type_id IS
'Unique identifier for node type. Value -1 is reserved for N/A placeholder nodes.';

-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================
-- To rollback this migration:
--
-- -- Delete N/A node type
-- DELETE FROM silver_taxonomies_nodes_types WHERE node_type_id = -1;
--
-- -- Drop indexes
-- DROP INDEX IF EXISTS idx_nodes_exclude_na;
-- DROP INDEX IF EXISTS idx_nodes_na_only;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
