/**
 * Dictionary Management Queries (Algorithm §6)
 * Append-only dictionaries for node types and attribute types
 */

import { PoolClient } from 'pg';
import { lower } from '../../utils/normalization';
import { DictionaryCache } from '../../types/context';

/**
 * §6: Ensure node type exists (INSERT if not exists, case-insensitive)
 * Returns node_type_id
 */
export async function ensureNodeType(
  client: PoolClient,
  name: string,
  loadId: number,
  cache?: DictionaryCache
): Promise<number> {
  // Check cache first
  const lowerName = lower(name);
  if (cache && cache.nodeTypes.has(lowerName)) {
    return cache.nodeTypes.get(lowerName)!;
  }

  // Try INSERT
  const insertQuery = `
    INSERT INTO silver_taxonomies_nodes_types
      (name, status, created_at, last_updated_at, load_id)
    VALUES
      ($1, 'active', NOW(), NOW(), $2)
    ON CONFLICT (LOWER(name)) DO NOTHING
    RETURNING node_type_id;
  `;

  const insertResult = await client.query(insertQuery, [name, loadId]);

  if (insertResult.rows.length > 0) {
    const id = insertResult.rows[0].node_type_id as number;
    if (cache) cache.nodeTypes.set(lowerName, id);
    return id;
  }

  // SELECT existing if insert skipped
  const selectQuery = `
    SELECT node_type_id
    FROM silver_taxonomies_nodes_types
    WHERE LOWER(name) = LOWER($1);
  `;

  const selectResult = await client.query(selectQuery, [name]);
  const id = selectResult.rows[0].node_type_id as number;
  if (cache) cache.nodeTypes.set(lowerName, id);
  return id;
}

/**
 * §6: Ensure attribute type exists (INSERT if not exists, case-insensitive)
 * Returns attribute_type_id
 */
export async function ensureAttributeType(
  client: PoolClient,
  name: string,
  loadId: number,
  cache?: DictionaryCache
): Promise<number> {
  // Check cache first
  const lowerName = lower(name);
  if (cache && cache.attrTypes.has(lowerName)) {
    return cache.attrTypes.get(lowerName)!;
  }

  // Try INSERT
  const insertQuery = `
    INSERT INTO silver_taxonomies_attribute_types
      (name, status, created_at, last_updated_at, load_id)
    VALUES
      ($1, 'active', NOW(), NOW(), $2)
    ON CONFLICT (LOWER(name)) DO NOTHING
    RETURNING attribute_type_id;
  `;

  const insertResult = await client.query(insertQuery, [name, loadId]);

  if (insertResult.rows.length > 0) {
    const id = insertResult.rows[0].attribute_type_id as number;
    if (cache) cache.attrTypes.set(lowerName, id);
    return id;
  }

  // SELECT existing if insert skipped
  const selectQuery = `
    SELECT attribute_type_id
    FROM silver_taxonomies_attribute_types
    WHERE LOWER(name) = LOWER($1);
  `;

  const selectResult = await client.query(selectQuery, [name]);
  const id = selectResult.rows[0].attribute_type_id as number;
  if (cache) cache.attrTypes.set(lowerName, id);
  return id;
}
