/**
 * Silver Attributes Queries (Algorithm §7A.2, §7B.2)
 * Two-path logic: NEW (insert-only) vs UPDATED (upsert + reactivate)
 */

import { PoolClient } from 'pg';
import { LoadType } from '../../types/context';

export interface AttributeParams {
  node_id: number;
  attribute_type_id: number;
  value: string;
  load_id: number;
  row_id: number;
}

/**
 * §7A.2 / §7B.2: Insert or upsert node attribute based on load_type
 * Natural key: (node_id, attribute_type_id, LOWER(value))
 */
export async function upsertNodeAttribute(
  client: PoolClient,
  loadType: LoadType,
  params: AttributeParams
): Promise<void> {
  if (loadType === 'new') {
    // §7A.2: INSERT only, do nothing on conflict
    const query = `
      INSERT INTO silver_taxonomies_nodes_attributes
        (node_id, attribute_type_id, value, status, created_at, last_updated_at, load_id, row_id)
      VALUES
        ($1, $2, $3, 'active', NOW(), NOW(), $4, $5)
      ON CONFLICT (node_id, attribute_type_id, LOWER(value)) DO NOTHING;
    `;

    await client.query(query, [
      params.node_id,
      params.attribute_type_id,
      params.value,
      params.load_id,
      params.row_id,
    ]);
  } else {
    // §7B.2: UPSERT - reactivate if inactive, update timestamps
    const query = `
      INSERT INTO silver_taxonomies_nodes_attributes
        (node_id, attribute_type_id, value, status, created_at, last_updated_at, load_id, row_id)
      VALUES
        ($1, $2, $3, 'active', NOW(), NOW(), $4, $5)
      ON CONFLICT (node_id, attribute_type_id, LOWER(value)) DO UPDATE
      SET
        status = 'active',
        last_updated_at = NOW(),
        load_id = EXCLUDED.load_id,
        row_id = EXCLUDED.row_id;
    `;

    await client.query(query, [
      params.node_id,
      params.attribute_type_id,
      params.value,
      params.load_id,
      params.row_id,
    ]);
  }
}
