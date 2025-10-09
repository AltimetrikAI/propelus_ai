/**
 * HierarchyQueries - N/A-Aware Hierarchy Query Utilities
 *
 * This class provides TypeScript wrappers around SQL hierarchy functions
 * with built-in N/A node handling according to Martin's approach.
 *
 * @author Implementation Team
 * @date October 2024
 * @reference SQL functions in migration 002-create-hierarchy-helper-functions.sql
 */

import { Pool, PoolClient } from 'pg';
import { NA_NODE_TYPE_ID, isNANodeType } from '../../utils/constants';

// ============================================================================
// Interfaces
// ============================================================================

/**
 * Node representation in hierarchy
 */
export interface HierarchyNode {
  node_id: number;
  value: string;
  profession: string;
  level: number;
  node_type_id: number;
  parent_node_id: number | null;
}

/**
 * Options for formatting paths
 */
export interface PathFormatOptions {
  separator?: string;
  includeLevel?: boolean;
  markNA?: boolean;
}

// ============================================================================
// HierarchyQueries Class
// ============================================================================

export class HierarchyQueries {
  constructor(private pool: Pool | PoolClient) {}

  /**
   * Get full hierarchy path INCLUDING N/A nodes
   *
   * Use this for:
   * - LLM matching (needs structural context)
   * - Internal processing
   * - Debugging
   *
   * @param nodeId - Target node ID
   * @returns Array of nodes from root to target (ordered by level)
   */
  async getFullPath(nodeId: number): Promise<HierarchyNode[]> {
    const result = await this.pool.query<HierarchyNode>(`
      SELECT * FROM get_node_full_path($1)
    `, [nodeId]);

    return result.rows;
  }

  /**
   * Get display path EXCLUDING N/A nodes
   *
   * Use this for:
   * - UI display
   * - API responses
   * - User-facing output
   *
   * @param nodeId - Target node ID
   * @returns Formatted path string without N/A nodes
   */
  async getDisplayPath(nodeId: number): Promise<string> {
    const result = await this.pool.query<{ path: string }>(`
      SELECT get_node_display_path($1) as path
    `, [nodeId]);

    return result.rows[0]?.path || '';
  }

  /**
   * Get active child nodes EXCLUDING N/A placeholders
   *
   * Use this for:
   * - Building navigation menus
   * - Listing sub-categories
   * - Dropdowns
   *
   * @param parentNodeId - Parent node ID
   * @returns Array of active child nodes
   */
  async getActiveChildren(parentNodeId: number): Promise<HierarchyNode[]> {
    const result = await this.pool.query<HierarchyNode>(`
      SELECT * FROM get_active_children($1)
    `, [parentNodeId]);

    return result.rows;
  }

  /**
   * Get ancestor nodes EXCLUDING N/A placeholders
   *
   * Use this for:
   * - Breadcrumb navigation
   * - Understanding node context
   *
   * @param nodeId - Target node ID
   * @returns Array of ancestor nodes (excluding the node itself)
   */
  async getAncestors(nodeId: number): Promise<HierarchyNode[]> {
    const result = await this.pool.query<HierarchyNode>(`
      SELECT * FROM get_node_ancestors($1)
    `, [nodeId]);

    return result.rows;
  }

  /**
   * Check if a node is an N/A placeholder
   *
   * @param nodeId - Node ID to check
   * @returns True if node is N/A placeholder
   */
  async isNANode(nodeId: number): Promise<boolean> {
    const result = await this.pool.query<{ is_na_node: boolean }>(`
      SELECT is_na_node($1) as is_na_node
    `, [nodeId]);

    return result.rows[0]?.is_na_node || false;
  }

  /**
   * Count N/A nodes in a path
   *
   * Use this for:
   * - Quality metrics
   * - Data analysis
   * - Monitoring
   *
   * @param nodeId - Target node ID
   * @returns Number of N/A nodes in path
   */
  async countNANodesInPath(nodeId: number): Promise<number> {
    const result = await this.pool.query<{ count: number }>(`
      SELECT count_na_nodes_in_path($1) as count
    `, [nodeId]);

    return result.rows[0]?.count || 0;
  }

  /**
   * Get path with level indicators (for LLM prompts)
   *
   * Format: "L1:Healthcare → [SKIP-L2]:N/A → L3:Registered Nurse"
   *
   * Use this for:
   * - LLM prompts requiring structural context
   * - Debugging
   *
   * @param nodeId - Target node ID
   * @returns Formatted path with level indicators
   */
  async getPathWithLevels(nodeId: number): Promise<string> {
    const result = await this.pool.query<{ path: string }>(`
      SELECT get_node_path_with_levels($1) as path
    `, [nodeId]);

    return result.rows[0]?.path || '';
  }

  // ============================================================================
  // Client-Side Utility Methods
  // ============================================================================

  /**
   * Filter N/A nodes from an array
   *
   * @param nodes - Array of nodes
   * @returns Array with N/A nodes removed
   */
  filterNANodes(nodes: HierarchyNode[]): HierarchyNode[] {
    return nodes.filter(node => !isNANodeType(node.node_type_id));
  }

  /**
   * Check if a node object is N/A (client-side check)
   *
   * @param node - Node to check
   * @returns True if node is N/A placeholder
   */
  isNANodeObject(node: HierarchyNode): boolean {
    return isNANodeType(node.node_type_id);
  }

  /**
   * Format path for display (client-side formatting)
   *
   * @param nodes - Array of nodes in path
   * @param options - Formatting options
   * @returns Formatted path string
   */
  formatPathForDisplay(
    nodes: HierarchyNode[],
    options: PathFormatOptions = {}
  ): string {
    const {
      separator = ' → ',
      includeLevel = false,
      markNA = false
    } = options;

    const filteredNodes = markNA ? nodes : this.filterNANodes(nodes);

    return filteredNodes
      .map(node => {
        const prefix = includeLevel ? `L${node.level}:` : '';
        const naMarker = this.isNANodeObject(node) && markNA ? '[SKIP]' : '';
        return `${naMarker}${prefix}${node.value}`;
      })
      .join(separator);
  }

  /**
   * Format path for LLM with level and N/A markers
   *
   * @param nodes - Array of nodes in path
   * @returns LLM-friendly formatted path
   */
  formatPathForLLM(nodes: HierarchyNode[]): string {
    return nodes
      .map(node => {
        const prefix = this.isNANodeObject(node) ? '[SKIP]' : `L${node.level}`;
        return `${prefix}:${node.value}`;
      })
      .join(' → ');
  }

  /**
   * Get path statistics
   *
   * @param nodeId - Target node ID
   * @returns Statistics about the path
   */
  async getPathStats(nodeId: number): Promise<PathStats> {
    const fullPath = await this.getFullPath(nodeId);
    const naCount = await this.countNANodesInPath(nodeId);

    return {
      totalLevels: fullPath.length,
      naLevels: naCount,
      realLevels: fullPath.length - naCount,
      naPercentage: fullPath.length > 0 ? (naCount / fullPath.length) * 100 : 0,
      rootLevel: fullPath[0]?.level || 0,
      targetLevel: fullPath[fullPath.length - 1]?.level || 0
    };
  }
}

// ============================================================================
// Types
// ============================================================================

export interface PathStats {
  totalLevels: number;
  naLevels: number;
  realLevels: number;
  naPercentage: number;
  rootLevel: number;
  targetLevel: number;
}

// ============================================================================
// Export
// ============================================================================

export default HierarchyQueries;
