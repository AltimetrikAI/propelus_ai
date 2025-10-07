/**
 * Load Management Queries (Algorithm §1, §3, §8)
 * Manages bronze_load_details lifecycle
 */

import { Pool } from 'pg';
import { TaxonomyType } from '../../types/events';
import { LoadStatus } from '../../utils/constants';

/**
 * §1: Open new load record
 * Creates bronze_load_details entry with status='in progress'
 */
export async function openLoad(
  pool: Pool,
  taxonomyType: TaxonomyType,
  sourceDetails: any
): Promise<number> {
  const query = `
    INSERT INTO bronze_load_details
      (customer_id, taxonomy_id, load_details, load_date, load_start, load_status, load_active_flag, load_type, taxonomy_type)
    VALUES
      (NULL, NULL, $1::jsonb, CURRENT_DATE, NOW(), $2, true, NULL, $3)
    RETURNING load_id;
  `;

  const result = await pool.query(query, [
    JSON.stringify(sourceDetails),
    LoadStatus.IN_PROGRESS,
    taxonomyType,
  ]);

  return result.rows[0].load_id as number;
}

/**
 * §3: Update load header with customer/taxonomy info
 */
export async function updateLoadHeader(
  pool: Pool,
  loadId: number,
  customerId: string,
  taxonomyId: string,
  rowCount: number,
  loadType: string,
  layoutDetails: any
): Promise<void> {
  const query = `
    UPDATE bronze_load_details
    SET
      customer_id = $1,
      taxonomy_id = $2,
      load_type = $3,
      load_details = COALESCE(load_details, '{}'::jsonb) || $4::jsonb
    WHERE load_id = $5;
  `;

  await pool.query(query, [
    customerId,
    taxonomyId,
    loadType,
    JSON.stringify({ Layout: layoutDetails, 'Row Count': rowCount }),
    loadId,
  ]);
}

/**
 * §8: Finalize load with success status
 */
export async function finalizeLoad(pool: Pool, loadId: number): Promise<void> {
  const query = `
    UPDATE bronze_load_details
    SET
      load_status = $1,
      load_end = NOW()
    WHERE load_id = $2;
  `;

  await pool.query(query, [LoadStatus.COMPLETED, loadId]);
}

/**
 * Mark load as failed
 */
export async function failLoad(pool: Pool, loadId: number, error: string): Promise<void> {
  const query = `
    UPDATE bronze_load_details
    SET
      load_status = $1,
      load_end = NOW(),
      load_details = COALESCE(load_details, '{}'::jsonb) || jsonb_build_object('Error', $2)
    WHERE load_id = $3;
  `;

  await pool.query(query, [LoadStatus.FAILED, error, loadId]);
}
