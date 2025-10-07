/**
 * Bronze Layer Queries
 * Manages bronze_taxonomies (raw row storage)
 */

import { PoolClient } from 'pg';
import { LoadContext } from '../../types/context';
import { RowStatus } from '../../utils/constants';

/**
 * Insert raw row into bronze_taxonomies
 * Returns row_id for lineage tracking
 */
export async function insertBronzeRow(
  client: PoolClient,
  ctx: LoadContext,
  srcRow: any
): Promise<number> {
  const query = `
    INSERT INTO bronze_taxonomies
      (load_id, customer_id, taxonomy_id, row_data, row_load_status, row_active_flag, created_at)
    VALUES
      ($1, $2, $3, $4::jsonb, NULL, true, NOW())
    RETURNING row_id;
  `;

  const result = await client.query(query, [
    ctx.loadId,
    ctx.customerId,
    ctx.taxonomyId,
    JSON.stringify(srcRow),
  ]);

  return result.rows[0].row_id as number;
}

/**
 * Update bronze row status (completed/failed)
 */
export async function setBronzeRowStatus(
  client: PoolClient,
  rowId: number,
  status: typeof RowStatus[keyof typeof RowStatus]
): Promise<void> {
  const query = `
    UPDATE bronze_taxonomies
    SET row_load_status = $1
    WHERE row_id = $2;
  `;

  await client.query(query, [status, rowId]);
}

/**
 * Append row error to load_details JSON
 */
export async function appendRowError(
  client: PoolClient,
  loadId: number,
  rowId: number,
  error: string
): Promise<void> {
  const query = `
    UPDATE bronze_load_details
    SET load_details = COALESCE(load_details, '{}'::jsonb) ||
        jsonb_build_object(
          'Row Errors',
          COALESCE((load_details->'Row Errors')::jsonb, '[]'::jsonb) ||
          jsonb_build_object('row_id', $1, 'error', $2)
        )
    WHERE load_id = $3;
  `;

  await client.query(query, [rowId, error, loadId]);
}
