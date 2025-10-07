/**
 * Versioning Queries (Algorithm §7A.3, §7B.5)
 * Track taxonomy evolution with version records
 */

import { PoolClient } from 'pg';
import { LoadContext, LoadType } from '../../types/context';

/**
 * §7A.3: Create Version 1 for NEW load
 */
async function createInitialVersion(client: PoolClient, ctx: LoadContext): Promise<void> {
  const query = `
    INSERT INTO silver_taxonomies_versions
      (taxonomy_id, taxonomy_version_number, change_type, affected_nodes, affected_attributes,
       remapping_flag, remapping_reason,
       total_mappings_processed, total_mappings_changed, total_mappings_unchanged, total_mappings_failed, total_mappings_new,
       remapping_proces_status, version_notes, version_from_date, version_to_date,
       created_at, last_updated_at, load_id)
    VALUES
      ($1, 1, 'initial load', '[]'::jsonb, '[]'::jsonb,
       false, NULL,
       0, 0, 0, 0, 0,
       NULL, NULL, NOW(), NULL,
       NOW(), NOW(), $2);
  `;

  await client.query(query, [ctx.taxonomyId, ctx.loadId]);
}

/**
 * §7B.5: Close previous version and create new version for UPDATED load
 */
async function createIncrementalVersion(client: PoolClient, ctx: LoadContext): Promise<void> {
  // Get next version number
  const versionQuery = `
    SELECT COALESCE(MAX(taxonomy_version_number), 0) + 1 AS next_version
    FROM silver_taxonomies_versions
    WHERE taxonomy_id = $1;
  `;

  const versionResult = await client.query(versionQuery, [ctx.taxonomyId]);
  const nextVersion = versionResult.rows[0].next_version as number;

  // Close previous version
  const closeQuery = `
    UPDATE silver_taxonomies_versions
    SET version_to_date = NOW()
    WHERE taxonomy_id = $1
      AND version_to_date IS NULL;
  `;

  await client.query(closeQuery, [ctx.taxonomyId]);

  // Collect affected nodes (changed to inactive in this load)
  const affectedNodesQuery = `
    SELECT jsonb_agg(
      jsonb_build_object(
        'node_id', node_id,
        'value', value,
        'node_type_id', node_type_id,
        'status', status
      )
    ) AS affected
    FROM silver_taxonomies_nodes
    WHERE taxonomy_id = $1
      AND customer_id = $2
      AND load_id = $3
      AND status = 'inactive';
  `;

  const affectedNodesResult = await client.query(affectedNodesQuery, [
    ctx.taxonomyId,
    ctx.customerId,
    ctx.loadId,
  ]);

  const affectedNodes = affectedNodesResult.rows[0]?.affected || '[]';

  // Collect affected attributes (changed to inactive in this load)
  const affectedAttributesQuery = `
    SELECT jsonb_agg(
      jsonb_build_object(
        'attribute_id', na.attribute_id,
        'node_id', na.node_id,
        'attribute_type_id', na.attribute_type_id,
        'value', na.value,
        'status', na.status
      )
    ) AS affected
    FROM silver_taxonomies_nodes_attributes na
    JOIN silver_taxonomies_nodes n ON na.node_id = n.node_id
    WHERE n.taxonomy_id = $1
      AND n.customer_id = $2
      AND na.load_id = $3
      AND na.status = 'inactive';
  `;

  const affectedAttributesResult = await client.query(affectedAttributesQuery, [
    ctx.taxonomyId,
    ctx.customerId,
    ctx.loadId,
  ]);

  const affectedAttributes = affectedAttributesResult.rows[0]?.affected || '[]';

  // Create new version
  const insertQuery = `
    INSERT INTO silver_taxonomies_versions
      (taxonomy_id, taxonomy_version_number, change_type, affected_nodes, affected_attributes,
       remapping_flag, remapping_reason,
       total_mappings_processed, total_mappings_changed, total_mappings_unchanged, total_mappings_failed, total_mappings_new,
       remapping_proces_status, version_notes, version_from_date, version_to_date,
       created_at, last_updated_at, load_id)
    VALUES
      ($1, $2, 'updated load', $3::jsonb, $4::jsonb,
       false, NULL,
       0, 0, 0, 0, 0,
       NULL, NULL, NOW(), NULL,
       NOW(), NOW(), $5);
  `;

  await client.query(insertQuery, [
    ctx.taxonomyId,
    nextVersion,
    affectedNodes,
    affectedAttributes,
    ctx.loadId,
  ]);
}

/**
 * §7A.3 / §7B.5: Write version record based on load type
 */
export async function writeVersion(
  client: PoolClient,
  ctx: LoadContext,
  loadType: LoadType
): Promise<void> {
  if (loadType === 'new') {
    await createInitialVersion(client, ctx);
  } else {
    await createIncrementalVersion(client, ctx);
  }
}
