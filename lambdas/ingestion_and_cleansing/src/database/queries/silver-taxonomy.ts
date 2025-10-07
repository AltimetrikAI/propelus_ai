/**
 * Silver Taxonomy Queries
 * Manages silver_taxonomies table
 */

import { Pool } from 'pg';
import { LoadContext, LoadType } from '../../types/context';

/**
 * §3: Determine load type (new or updated)
 * Check if (customer_id, taxonomy_id) pair already exists
 */
export async function deriveLoadType(
  pool: Pool,
  customerId: string,
  taxonomyId: string
): Promise<LoadType> {
  const query = `
    SELECT COUNT(*) as count
    FROM silver_taxonomies
    WHERE customer_id = $1 AND taxonomy_id = $2;
  `;

  const result = await pool.query(query, [customerId, taxonomyId]);
  const count = parseInt(result.rows[0].count, 10);

  return count === 0 ? 'new' : 'updated';
}

/**
 * §3: Ensure silver_taxonomies entry exists
 * INSERT if not exists
 */
export async function ensureSilverTaxonomy(pool: Pool, ctx: LoadContext): Promise<void> {
  const query = `
    INSERT INTO silver_taxonomies
      (customer_id, taxonomy_id, taxonomy_name, taxonomy_type, status, created_at, last_updated_at, load_id)
    VALUES
      ($1, $2, $3, $4, 'active', NOW(), NOW(), $5)
    ON CONFLICT (customer_id, taxonomy_id) DO UPDATE
    SET
      taxonomy_name = EXCLUDED.taxonomy_name,
      last_updated_at = NOW(),
      load_id = EXCLUDED.load_id;
  `;

  await pool.query(query, [
    ctx.customerId,
    ctx.taxonomyId,
    ctx.taxonomyName,
    ctx.taxonomyType,
    ctx.loadId,
  ]);
}
