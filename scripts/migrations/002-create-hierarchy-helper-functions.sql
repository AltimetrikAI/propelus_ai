-- ============================================================================
-- Migration: 002 - Create Hierarchy Helper Functions
-- Purpose: SQL functions for N/A-aware hierarchy traversal and display
-- Author: Martin (Data Engineer) / Implementation Team
-- Date: October 2024
-- Reference: N/A Node Implementation - Martin's approach
-- ============================================================================

-- ============================================================================
-- FUNCTION 1: get_node_full_path
-- Purpose: Returns complete hierarchy path INCLUDING N/A nodes
-- Use Case: LLM matching, internal processing, debugging
-- ============================================================================

CREATE OR REPLACE FUNCTION get_node_full_path(p_node_id BIGINT)
RETURNS TABLE(
    node_id BIGINT,
    value TEXT,
    profession TEXT,
    level INTEGER,
    node_type_id BIGINT,
    parent_node_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE node_path AS (
        -- Base case: start with target node
        SELECT
            n.node_id,
            n.value,
            n.profession,
            n.level,
            n.parent_node_id,
            n.node_type_id
        FROM silver_taxonomies_nodes n
        WHERE n.node_id = p_node_id

        UNION ALL

        -- Recursive case: traverse up to parent nodes
        SELECT
            n.node_id,
            n.value,
            n.profession,
            n.level,
            n.parent_node_id,
            n.node_type_id
        FROM silver_taxonomies_nodes n
        INNER JOIN node_path np ON n.node_id = np.parent_node_id
    )
    SELECT
        node_path.node_id,
        node_path.value,
        node_path.profession,
        node_path.level,
        node_path.node_type_id,
        node_path.parent_node_id
    FROM node_path
    ORDER BY level ASC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_node_full_path(BIGINT) IS
'Returns full hierarchy path from root to target node, INCLUDING N/A placeholders. Use for LLM context and internal processing.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function get_node_full_path created successfully';
END $$;

-- ============================================================================
-- FUNCTION 2: get_node_display_path
-- Purpose: Returns user-friendly path EXCLUDING N/A nodes
-- Use Case: UI display, API responses, user-facing output
-- ============================================================================

CREATE OR REPLACE FUNCTION get_node_display_path(p_node_id BIGINT)
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT string_agg(value, ' → ' ORDER BY level)
        FROM get_node_full_path(p_node_id)
        WHERE node_type_id != -1  -- Exclude N/A nodes
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_node_display_path(BIGINT) IS
'Returns user-friendly hierarchy path as text, EXCLUDING N/A placeholders. Use for display in UI and API responses.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function get_node_display_path created successfully';
END $$;

-- ============================================================================
-- FUNCTION 3: get_active_children
-- Purpose: Returns active child nodes EXCLUDING N/A placeholders
-- Use Case: Building navigation menus, listing sub-categories
-- ============================================================================

CREATE OR REPLACE FUNCTION get_active_children(p_parent_node_id BIGINT)
RETURNS TABLE(
    node_id BIGINT,
    value TEXT,
    profession TEXT,
    level INTEGER,
    node_type_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.node_id,
        n.value,
        n.profession,
        n.level,
        n.node_type_id
    FROM silver_taxonomies_nodes n
    WHERE n.parent_node_id = p_parent_node_id
      AND n.node_type_id != -1  -- Exclude N/A nodes
      AND n.status = 'active'
    ORDER BY n.value;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_active_children(BIGINT) IS
'Returns active child nodes of a parent, EXCLUDING N/A placeholders. Use for building navigation and category lists.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function get_active_children created successfully';
END $$;

-- ============================================================================
-- FUNCTION 4: get_node_ancestors
-- Purpose: Returns all ancestor nodes EXCLUDING N/A placeholders
-- Use Case: Breadcrumb navigation, understanding node context
-- ============================================================================

CREATE OR REPLACE FUNCTION get_node_ancestors(p_node_id BIGINT)
RETURNS TABLE(
    node_id BIGINT,
    value TEXT,
    profession TEXT,
    level INTEGER,
    node_type_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        node_path.node_id,
        node_path.value,
        node_path.profession,
        node_path.level,
        node_path.node_type_id
    FROM get_node_full_path(p_node_id) AS node_path
    WHERE node_path.node_id != p_node_id  -- Exclude the node itself
      AND node_path.node_type_id != -1     -- Exclude N/A nodes
    ORDER BY node_path.level ASC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_node_ancestors(BIGINT) IS
'Returns all ancestor nodes (parents, grandparents, etc.) EXCLUDING N/A placeholders. Use for breadcrumbs and context.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function get_node_ancestors created successfully';
END $$;

-- ============================================================================
-- FUNCTION 5: is_na_node
-- Purpose: Check if a node is an N/A placeholder
-- Use Case: Conditional logic in queries and applications
-- ============================================================================

CREATE OR REPLACE FUNCTION is_na_node(p_node_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM silver_taxonomies_nodes
        WHERE node_id = p_node_id
          AND node_type_id = -1
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION is_na_node(BIGINT) IS
'Returns TRUE if the specified node is an N/A placeholder, FALSE otherwise.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function is_na_node created successfully';
END $$;

-- ============================================================================
-- FUNCTION 6: count_na_nodes_in_path
-- Purpose: Count how many N/A nodes exist in a path
-- Use Case: Quality metrics, debugging, data analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION count_na_nodes_in_path(p_node_id BIGINT)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM get_node_full_path(p_node_id)
        WHERE node_type_id = -1
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION count_na_nodes_in_path(BIGINT) IS
'Returns the number of N/A placeholder nodes in the hierarchy path. Use for quality metrics and analysis.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function count_na_nodes_in_path created successfully';
END $$;

-- ============================================================================
-- FUNCTION 7: get_node_path_with_levels
-- Purpose: Returns path with explicit level indicators (for LLM prompts)
-- Use Case: Formatting paths for LLM matching with structural context
-- ============================================================================

CREATE OR REPLACE FUNCTION get_node_path_with_levels(p_node_id BIGINT)
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT string_agg(
            CASE
                WHEN node_type_id = -1 THEN '[SKIP-L' || level || ']:N/A'
                ELSE 'L' || level || ':' || value
            END,
            ' → '
            ORDER BY level
        )
        FROM get_node_full_path(p_node_id)
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_node_path_with_levels(BIGINT) IS
'Returns hierarchy path with level indicators, marking N/A nodes with [SKIP]. Use for LLM prompts requiring structural context.';

-- Test function
DO $$
BEGIN
    RAISE NOTICE '✓ Function get_node_path_with_levels created successfully';
END $$;

-- ============================================================================
-- USAGE EXAMPLES (Documentation)
-- ============================================================================

/*
-- Example 1: Get full path including N/A (for LLM)
SELECT * FROM get_node_full_path(12345);

-- Example 2: Get display path for UI (no N/A)
SELECT get_node_display_path(12345);
-- Result: "Healthcare → Nursing → Registered Nurse"

-- Example 3: Get active children for dropdown menu
SELECT * FROM get_active_children(100);

-- Example 4: Check if a node is N/A
SELECT is_na_node(200);

-- Example 5: Get path with level indicators for LLM
SELECT get_node_path_with_levels(12345);
-- Result: "L1:Healthcare → [SKIP-L2]:N/A → L3:Registered Nurse"

-- Example 6: Count N/A nodes in a path (quality metric)
SELECT count_na_nodes_in_path(12345);
-- Result: 2 (means path has 2 N/A placeholders)

-- Example 7: Get ancestors for breadcrumb navigation
SELECT * FROM get_node_ancestors(12345);
*/

-- ============================================================================
-- PERFORMANCE NOTES
-- ============================================================================

/*
These functions use recursive CTEs which are efficient for typical taxonomy depths (1-10 levels).
For very deep hierarchies (>20 levels), consider:
1. Materialized path pattern (store full path in column)
2. Closure table pattern (pre-compute all relationships)
3. Caching frequent queries at application layer

The partial indexes created in migration 001 optimize these queries significantly.
*/

-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================

/*
-- To rollback this migration:
DROP FUNCTION IF EXISTS get_node_full_path(BIGINT);
DROP FUNCTION IF EXISTS get_node_display_path(BIGINT);
DROP FUNCTION IF EXISTS get_active_children(BIGINT);
DROP FUNCTION IF EXISTS get_node_ancestors(BIGINT);
DROP FUNCTION IF EXISTS is_na_node(BIGINT);
DROP FUNCTION IF EXISTS count_na_nodes_in_path(BIGINT);
DROP FUNCTION IF EXISTS get_node_path_with_levels(BIGINT);
*/

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'Migration 002 completed successfully';
RAISE NOTICE '7 hierarchy helper functions created';
RAISE NOTICE '========================================';
