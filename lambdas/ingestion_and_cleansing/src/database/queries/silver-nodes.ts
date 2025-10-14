/**
 * Silver Nodes Queries (Algorithm §7A.1, §7B.1) - v1.0
 * Two-path logic: NEW (insert-only) vs UPDATED (upsert)
 */

import { PoolClient } from 'pg';
import { LoadType } from '../../types/context';

export interface NodeParams {
  taxonomy_id: string;
  customer_id: string;
  node_type_id: number;
  parent_node_id: number | null;
  value: string;
  profession: string;
  level: number;
  load_id: number;
  row_id: number;
}

/**
 * §7A.1 / §7B.1: Insert or upsert node based on load_type (v1.0)
 * Natural key: (taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value))
 * NOTE: Natural key now includes parent_node_id to allow same value under different parents
 * Returns node_id
 */
export async function upsertNode(
  client: PoolClient,
  loadType: LoadType,
  params: NodeParams
): Promise<number> {
  if (loadType === 'new') {
    // §7A.1: INSERT only, do nothing on conflict (v1.0 - includes parent_node_id in NK)
    const query = `
      INSERT INTO silver_taxonomies_nodes
        (taxonomy_id, customer_id, node_type_id, parent_node_id, value, profession, level, status, created_at, last_updated_at, load_id, row_id)
      VALUES
        ($1, $2, $3, $4, $5, $6, $7, 'active', NOW(), NOW(), $8, $9)
      ON CONFLICT (taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value)) DO NOTHING
      RETURNING node_id;
    `;

    const result = await client.query(query, [
      params.taxonomy_id,
      params.customer_id,
      params.node_type_id,
      params.parent_node_id,
      params.value,
      params.profession,
      params.level,
      params.load_id,
      params.row_id,
    ]);

    if (result.rows.length > 0) {
      return result.rows[0].node_id as number;
    }

    // If insert skipped, SELECT existing node_id (v1.0 - includes parent_node_id)
    const selectQuery = `
      SELECT node_id
      FROM silver_taxonomies_nodes
      WHERE taxonomy_id = $1
        AND node_type_id = $2
        AND customer_id = $3
        AND parent_node_id IS NOT DISTINCT FROM $4
        AND LOWER(value) = LOWER($5);
    `;

    const selectResult = await client.query(selectQuery, [
      params.taxonomy_id,
      params.node_type_id,
      params.customer_id,
      params.parent_node_id,
      params.value,
    ]);

    return selectResult.rows[0].node_id as number;
  } else {
    // §7B.1: UPSERT - update parent_node_id, profession, level, status, timestamps (v1.0)
    const query = `
      INSERT INTO silver_taxonomies_nodes
        (taxonomy_id, customer_id, node_type_id, parent_node_id, value, profession, level, status, created_at, last_updated_at, load_id, row_id)
      VALUES
        ($1, $2, $3, $4, $5, $6, $7, 'active', NOW(), NOW(), $8, $9)
      ON CONFLICT (taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value)) DO UPDATE
      SET
        parent_node_id = EXCLUDED.parent_node_id,
        profession = EXCLUDED.profession,
        level = EXCLUDED.level,
        status = 'active',
        last_updated_at = NOW(),
        load_id = EXCLUDED.load_id,
        row_id = EXCLUDED.row_id
      RETURNING node_id;
    `;

    const result = await client.query(query, [
      params.taxonomy_id,
      params.customer_id,
      params.node_type_id,
      params.parent_node_id,
      params.value,
      params.profession,
      params.level,
      params.load_id,
      params.row_id,
    ]);

    return result.rows[0].node_id as number;
  }
}
