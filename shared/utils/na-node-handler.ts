/**
 * NANodeHandler - N/A Node Management Utility
 *
 * This class handles the creation and management of N/A placeholder nodes
 * according to Martin's approved approach for filling hierarchy gaps.
 *
 * @author Implementation Team
 * @date October 2024
 * @reference Meeting transcript Oct 8, 2024 - Martin's N/A approach
 *
 * IMPORTANT:
 * - Never create N/A nodes manually
 * - Always use this handler to ensure consistency
 * - N/A nodes are reused when possible (same taxonomy, level, parent)
 */

import { Pool, PoolClient, QueryResult } from 'pg';
import {
  NA_NODE_TYPE_ID,
  NA_NODE_VALUE,
  NA_PROFESSION_VALUE,
  NODE_STATUS,
  MAX_HIERARCHY_DEPTH,
  ERROR_CODES
} from './constants';

// ============================================================================
// Interfaces
// ============================================================================

/**
 * Parameters for finding or creating an N/A node
 */
export interface NANodeParams {
  taxonomy_id: number;
  level: number;
  parent_node_id: number | null;
  load_id?: number;
  row_id?: number;
}

/**
 * Result of N/A node creation/retrieval
 */
export interface NANodeResult {
  node_id: number;
  existed: boolean;  // true if node already existed, false if newly created
}

/**
 * Database node representation
 */
export interface Node {
  node_id: number;
  node_type_id: number;
  taxonomy_id: number;
  parent_node_id: number | null;
  value: string;
  profession: string;
  level: number;
  status: string;
}

// ============================================================================
// NANodeHandler Class
// ============================================================================

export class NANodeHandler {
  constructor(
    private pool: Pool | PoolClient
  ) {}

  /**
   * Find existing N/A node or create a new one
   *
   * This is the primary method for N/A node management. It ensures
   * that we reuse existing N/A nodes instead of creating duplicates.
   *
   * @param params - Node parameters
   * @returns Node ID and whether it existed
   *
   * @example
   * ```typescript
   * const result = await handler.findOrCreateNANode({
   *   taxonomy_id: 1,
   *   level: 2,
   *   parent_node_id: 100
   * });
   * console.log(`N/A node ID: ${result.node_id}, existed: ${result.existed}`);
   * ```
   */
  async findOrCreateNANode(params: NANodeParams): Promise<NANodeResult> {
    const { taxonomy_id, level, parent_node_id, load_id, row_id } = params;

    // Validate level
    if (level < 1 || level > MAX_HIERARCHY_DEPTH) {
      throw new Error(
        `${ERROR_CODES.INVALID_LEVEL}: Level ${level} is outside valid range (1-${MAX_HIERARCHY_DEPTH})`
      );
    }

    // Check if N/A node already exists at this position
    const existingNode = await this.findExistingNANode(taxonomy_id, level, parent_node_id);

    if (existingNode) {
      return {
        node_id: existingNode.node_id,
        existed: true
      };
    }

    // Create new N/A node
    const newNodeId = await this.createNANode(params);

    return {
      node_id: newNodeId,
      existed: false
    };
  }

  /**
   * Find existing N/A node at specific position
   *
   * @private
   */
  private async findExistingNANode(
    taxonomy_id: number,
    level: number,
    parent_node_id: number | null
  ): Promise<Node | null> {
    const query = `
      SELECT
        node_id,
        node_type_id,
        taxonomy_id,
        parent_node_id,
        value,
        profession,
        level,
        status
      FROM silver_taxonomies_nodes
      WHERE taxonomy_id = $1
        AND level = $2
        AND parent_node_id ${parent_node_id === null ? 'IS NULL' : '= $3'}
        AND node_type_id = $4
        AND status = $5
      LIMIT 1
    `;

    const params = parent_node_id === null
      ? [taxonomy_id, level, NA_NODE_TYPE_ID, NODE_STATUS.ACTIVE]
      : [taxonomy_id, level, parent_node_id, NA_NODE_TYPE_ID, NODE_STATUS.ACTIVE];

    const result: QueryResult<Node> = await this.pool.query(query, params);

    return result.rows[0] || null;
  }

  /**
   * Create new N/A node
   *
   * @private
   */
  private async createNANode(params: NANodeParams): Promise<number> {
    const { taxonomy_id, level, parent_node_id, load_id, row_id } = params;

    const query = `
      INSERT INTO silver_taxonomies_nodes (
        node_type_id,
        taxonomy_id,
        parent_node_id,
        value,
        profession,
        level,
        status,
        created_at,
        last_updated_at
        ${load_id !== undefined ? ', load_id' : ''}
        ${row_id !== undefined ? ', row_id' : ''}
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7, NOW(), NOW()
        ${load_id !== undefined ? `, $8` : ''}
        ${row_id !== undefined ? `, ${load_id !== undefined ? '$9' : '$8'}` : ''}
      )
      RETURNING node_id
    `;

    const queryParams: any[] = [
      NA_NODE_TYPE_ID,
      taxonomy_id,
      parent_node_id,
      NA_NODE_VALUE,
      NA_PROFESSION_VALUE,
      level,
      NODE_STATUS.ACTIVE
    ];

    if (load_id !== undefined) queryParams.push(load_id);
    if (row_id !== undefined) queryParams.push(row_id);

    try {
      const result = await this.pool.query<{ node_id: number }>(query, queryParams);

      if (!result.rows[0]) {
        throw new Error(`${ERROR_CODES.NA_NODE_CREATION_FAILED}: No node_id returned`);
      }

      return result.rows[0].node_id;
    } catch (error) {
      throw new Error(
        `${ERROR_CODES.NA_NODE_CREATION_FAILED}: ${error.message}`
      );
    }
  }

  /**
   * Create a chain of N/A nodes to fill gaps in hierarchy
   *
   * When creating a node at level N with a parent at level M (where M < N-1),
   * this method creates N/A placeholder nodes for all intermediate levels.
   *
   * Example: Creating level 4 node with level 1 parent
   * Creates: Level 1 → N/A(L2) → N/A(L3) → Level 4
   *
   * @param taxonomy_id - Taxonomy identifier
   * @param startLevel - First level to create N/A node
   * @param endLevel - Last level to create N/A node
   * @param startParentId - Parent node ID at level before startLevel
   * @param load_id - Optional load tracking ID
   * @param row_id - Optional row tracking ID
   * @returns Node ID of the last N/A node created (at endLevel)
   *
   * @example
   * ```typescript
   * // Create N/A nodes for levels 2 and 3
   * const level3NANodeId = await handler.createNAChain(
   *   1,    // taxonomy_id
   *   2,    // startLevel
   *   3,    // endLevel
   *   100   // parent at level 1
   * );
   * // Now use level3NANodeId as parent for level 4 node
   * ```
   */
  async createNAChain(
    taxonomy_id: number,
    startLevel: number,
    endLevel: number,
    startParentId: number | null,
    load_id?: number,
    row_id?: number
  ): Promise<number> {
    // Validation
    if (startLevel > endLevel) {
      throw new Error(
        `${ERROR_CODES.NA_CHAIN_INVALID}: startLevel (${startLevel}) cannot be greater than endLevel (${endLevel})`
      );
    }

    if (startLevel < 1 || endLevel > MAX_HIERARCHY_DEPTH) {
      throw new Error(
        `${ERROR_CODES.NA_CHAIN_INVALID}: Levels must be between 1 and ${MAX_HIERARCHY_DEPTH}`
      );
    }

    let currentParentId = startParentId;

    // Create N/A nodes for each level in the range
    for (let level = startLevel; level <= endLevel; level++) {
      const result = await this.findOrCreateNANode({
        taxonomy_id,
        level,
        parent_node_id: currentParentId,
        load_id,
        row_id
      });

      currentParentId = result.node_id;
    }

    return currentParentId;
  }

  /**
   * Get the appropriate parent node ID, creating N/A nodes if needed
   *
   * This is the main helper for node creation that handles gap filling automatically.
   *
   * @param taxonomy_id - Taxonomy identifier
   * @param targetLevel - Level of the node to be created
   * @param semanticParentNodeId - ID of the semantic parent (may be several levels above)
   * @param semanticParentLevel - Level of the semantic parent
   * @param load_id - Optional load tracking ID
   * @param row_id - Optional row tracking ID
   * @returns Parent node ID to use for the new node (may be N/A node)
   *
   * @example
   * ```typescript
   * // Creating a level 4 node with a level 1 parent
   * // This will automatically create N/A nodes at levels 2 and 3
   * const parentId = await handler.getOrCreateParentNode(
   *   1,    // taxonomy_id
   *   4,    // targetLevel
   *   100,  // semanticParentNodeId (at level 1)
   *   1     // semanticParentLevel
   * );
   * // parentId now points to N/A node at level 3
   * ```
   */
  async getOrCreateParentNode(
    taxonomy_id: number,
    targetLevel: number,
    semanticParentNodeId: number | null,
    semanticParentLevel: number | null,
    load_id?: number,
    row_id?: number
  ): Promise<number | null> {
    // Root level has no parent
    if (targetLevel === 1) {
      return null;
    }

    // If no semantic parent, must be creating root level node
    if (semanticParentNodeId === null || semanticParentLevel === null) {
      // For nodes at level > 1 without a parent, create N/A chain from level 1
      if (targetLevel > 1) {
        return await this.createNAChain(
          taxonomy_id,
          1,
          targetLevel - 1,
          null,
          load_id,
          row_id
        );
      }
      return null;
    }

    // If semantic parent is at level directly above, use it
    if (semanticParentLevel === targetLevel - 1) {
      return semanticParentNodeId;
    }

    // Need to fill gaps with N/A nodes
    const startLevel = semanticParentLevel + 1;
    const endLevel = targetLevel - 1;

    return await this.createNAChain(
      taxonomy_id,
      startLevel,
      endLevel,
      semanticParentNodeId,
      load_id,
      row_id
    );
  }

  /**
   * Get statistics about N/A node usage
   *
   * Useful for monitoring and quality metrics
   *
   * @param taxonomy_id - Optional filter by taxonomy
   * @returns Statistics object
   */
  async getNANodeStats(taxonomy_id?: number): Promise<NANodeStats> {
    const taxonomyFilter = taxonomy_id !== undefined
      ? `AND taxonomy_id = ${taxonomy_id}`
      : '';

    const query = `
      SELECT
        COUNT(*) as total_na_nodes,
        COUNT(DISTINCT taxonomy_id) as taxonomies_with_na,
        COUNT(DISTINCT level) as levels_with_na,
        AVG(level)::INTEGER as avg_na_level,
        MIN(level) as min_na_level,
        MAX(level) as max_na_level
      FROM silver_taxonomies_nodes
      WHERE node_type_id = ${NA_NODE_TYPE_ID}
        AND status = '${NODE_STATUS.ACTIVE}'
        ${taxonomyFilter}
    `;

    const result = await this.pool.query<NANodeStats>(query);
    return result.rows[0];
  }
}

// ============================================================================
// Types
// ============================================================================

export interface NANodeStats {
  total_na_nodes: number;
  taxonomies_with_na: number;
  levels_with_na: number;
  avg_na_level: number;
  min_na_level: number;
  max_na_level: number;
}

// ============================================================================
// Export
// ============================================================================

export default NANodeHandler;
