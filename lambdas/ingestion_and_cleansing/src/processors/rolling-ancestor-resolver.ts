/**
 * Rolling Ancestor Resolver (Algorithm §7.1.1) - v1.0
 * Maintains last_seen[level] memory across rows for parent resolution
 */

import { PoolClient } from 'pg';

/**
 * Rolling ancestor state maintained across all rows in a load
 * Maps level number → most recently created node_id at that level
 */
export class RollingAncestorResolver {
  private lastSeen: Map<number, number>; // level -> node_id
  private client: PoolClient;

  constructor(client: PoolClient) {
    this.client = client;
    this.lastSeen = new Map();
  }

  /**
   * Resolve parent_node_id for a node at given level
   * §7.1.1: Find nearest realized lower-level ancestor
   *
   * @param level - The level of the node being created (0-based)
   * @param rowValues - Current row's values for all levels (for N/A checking)
   * @returns parent_node_id or null if level=0
   */
  resolveParent(level: number, rowValues: Map<number, string | null>): number | null {
    // §7.1.1: Level 0 (root) → parent_node_id = NULL
    if (level === 0) {
      return null;
    }

    // §7.1.1: Find nearest k in {L-1, L-2, ..., 0} such that:
    // - last_seen[k] exists
    // - current row's value at level k is not 'N/A' (or is absent in single-node rows)
    for (let k = level - 1; k >= 0; k--) {
      const hasLastSeen = this.lastSeen.has(k);
      const rowValue = rowValues.get(k);
      const isNA = this.isNAValue(rowValue);

      if (hasLastSeen && !isNA) {
        return this.lastSeen.get(k)!;
      }
    }

    // No valid parent found - this should not happen in well-formed data
    // but we'll return null to allow the node to be created as a root
    return null;
  }

  /**
   * Update rolling memory after creating a node
   * §7.1.1: Update last_seen[L] with the last created node_id for that level
   *
   * @param level - The level of the node just created
   * @param nodeId - The node_id that was just created/upserted
   */
  updateMemory(level: number, nodeId: number): void {
    this.lastSeen.set(level, nodeId);
  }

  /**
   * Get current state for debugging
   */
  getState(): Map<number, number> {
    return new Map(this.lastSeen);
  }

  /**
   * Check if a value is considered 'N/A' (empty, null, or literal 'N/A')
   */
  private isNAValue(value: string | null | undefined): boolean {
    if (value === null || value === undefined || value === '') {
      return true;
    }

    const normalized = value.trim().toLowerCase();
    return normalized === 'n/a' || normalized === 'na';
  }

  /**
   * Reset state (useful for testing or processing multiple files)
   */
  reset(): void {
    this.lastSeen.clear();
  }
}
