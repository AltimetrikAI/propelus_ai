/**
 * Reconciliation Queries (Algorithm §7B.3, §7B.4)
 * Soft-delete missing nodes and attributes in UPDATED MASTER loads only
 *
 * NOTE: Customer taxonomies do NOT use reconciliation because:
 * - Update files may contain partial subsets
 * - No keys exist to track profession splits or attribute value changes
 */

import { PoolClient } from 'pg';

/**
 * §7B.3: Create temporary tables for tracking loaded nodes/attributes
 */
export async function createTempReconciliationTables(client: PoolClient): Promise<void> {
  // Temporary table for loaded nodes
  await client.query(`
    CREATE TEMP TABLE IF NOT EXISTS tmp_loaded_nodes (
      taxonomy_id VARCHAR(255),
      customer_id VARCHAR(255),
      node_type_id INTEGER,
      value_lower VARCHAR(255)
    ) ON COMMIT DROP;
  `);

  // Temporary table for loaded attributes
  await client.query(`
    CREATE TEMP TABLE IF NOT EXISTS tmp_loaded_attrs (
      node_id INTEGER,
      attribute_type_id INTEGER,
      value_lower VARCHAR(255)
    ) ON COMMIT DROP;
  `);
}

/**
 * §7B.3: Mark node as loaded (for reconciliation)
 */
export async function markLoadedNode(
  client: PoolClient,
  taxonomyId: string,
  customerId: string,
  nodeTypeId: number,
  value: string
): Promise<void> {
  const query = `
    INSERT INTO tmp_loaded_nodes (taxonomy_id, customer_id, node_type_id, value_lower)
    VALUES ($1, $2, $3, LOWER($4));
  `;

  await client.query(query, [taxonomyId, customerId, nodeTypeId, value]);
}

/**
 * §7B.3: Mark attribute as loaded (for reconciliation)
 */
export async function markLoadedAttribute(
  client: PoolClient,
  nodeId: number,
  attributeTypeId: number,
  value: string
): Promise<void> {
  const query = `
    INSERT INTO tmp_loaded_attrs (node_id, attribute_type_id, value_lower)
    VALUES ($1, $2, LOWER($3));
  `;

  await client.query(query, [nodeId, attributeTypeId, value]);
}

/**
 * §7B.3: Deactivate nodes not in current load (soft-delete)
 * Master taxonomies only - NOT used for customer taxonomies
 */
export async function deactivateMissingNodes(
  client: PoolClient,
  taxonomyId: string,
  customerId: string,
  loadId: number
): Promise<void> {
  const query = `
    UPDATE silver_taxonomies_nodes n
    SET
      status = 'inactive',
      last_updated_at = NOW(),
      load_id = $3
    WHERE n.taxonomy_id = $1
      AND n.customer_id = $2
      AND n.status = 'active'
      AND NOT EXISTS (
        SELECT 1
        FROM tmp_loaded_nodes t
        WHERE t.taxonomy_id = $1
          AND t.customer_id = $2
          AND t.node_type_id = n.node_type_id
          AND t.value_lower = LOWER(n.value)
      );
  `;

  await client.query(query, [taxonomyId, customerId, loadId]);
}

/**
 * §7B.4: Deactivate attributes not in current load (soft-delete)
 * Master taxonomies only - NOT used for customer taxonomies
 * Only for nodes belonging to this taxonomy
 */
export async function deactivateMissingAttributes(
  client: PoolClient,
  taxonomyId: string,
  customerId: string,
  loadId: number
): Promise<void> {
  const query = `
    UPDATE silver_taxonomies_nodes_attributes na
    SET
      status = 'inactive',
      last_updated_at = NOW(),
      load_id = $3
    WHERE na.node_id IN (
        SELECT node_id
        FROM silver_taxonomies_nodes
        WHERE taxonomy_id = $1 AND customer_id = $2
      )
      AND na.status = 'active'
      AND NOT EXISTS (
        SELECT 1
        FROM tmp_loaded_attrs t
        WHERE t.node_id = na.node_id
          AND t.attribute_type_id = na.attribute_type_id
          AND t.value_lower = LOWER(na.value)
      );
  `;

  await client.query(query, [taxonomyId, customerId, loadId]);
}
