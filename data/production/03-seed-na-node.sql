-- ============================================================================
-- Production Aurora PostgreSQL - Seed N/A Node Type
-- ============================================================================
-- Description: Insert special N/A node type for hierarchy gap handling
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (03-tables.sql)
-- ============================================================================

-- ============================================================================
-- INSERT N/A NODE TYPE
-- ============================================================================
-- Purpose: Creates placeholder node type (ID: -1) for hierarchical gaps
-- Used by: Ingestion Lambda when customer taxonomies skip hierarchy levels
-- Example: Customer has "Level 1 → Level 3" (missing Level 2)
--          System inserts N/A node at Level 2 automatically

INSERT INTO silver_taxonomies_nodes_types (node_type_id, name, status, created_at, last_updated_at)
VALUES (-1, 'N/A', 'active', NOW(), NOW())
ON CONFLICT (node_type_id) DO NOTHING;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check N/A node type exists
SELECT node_type_id, name, status, created_at
FROM silver_taxonomies_nodes_types
WHERE node_type_id = -1;

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- N/A Node Type Behavior:
--   - ID: -1 (special reserved ID)
--   - Name: 'N/A'
--   - Status: 'active'
--   - Used automatically by ingestion Lambda
--   - Filtered out in display queries
--   - Included in LLM context for hierarchy understanding
--
-- Migration Reference:
--   - Migration 001: Creates N/A node type
--   - Migration 002: Helper functions for N/A filtering
--
-- ============================================================================
