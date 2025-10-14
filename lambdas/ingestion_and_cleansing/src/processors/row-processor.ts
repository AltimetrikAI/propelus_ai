/**
 * Row Processor (Algorithm §7) - v1.0
 * Processes individual rows: single node per row with rolling ancestor memory
 */

import { PoolClient } from 'pg';
import { LoadContext, DictionaryCache } from '../types/context';
import { LayoutMaster, LayoutCustomer, NodeLevel } from '../types/layout';
import { normalize, lower } from '../utils/normalization';
import { insertBronzeRow, setBronzeRowStatus, appendRowError } from '../database/queries/bronze';
import { ensureNodeType, ensureAttributeType } from '../database/queries/silver-dictionaries';
import { upsertNode } from '../database/queries/silver-nodes';
import { upsertNodeAttribute } from '../database/queries/silver-attributes';
import { markLoadedNode, markLoadedAttribute } from '../database/queries/reconciliation';
import { RollingAncestorResolver } from './rolling-ancestor-resolver';

interface NodePiece {
  nodeTypeName: string;
  value: string;
  level: number;  // Explicit level from NodeLevels (0-based)
}

/**
 * §7: Process single row - single node with rolling ancestor memory (v1.0)
 *
 * Key changes in v1.0:
 * - Each row contains exactly ONE node at ONE explicit level
 * - Parent resolution uses rolling ancestor memory across rows
 * - Supports level 0 (root node)
 * - Multi-valued cells create sibling nodes under same parent
 */
export async function processRow(
  client: PoolClient,
  ctx: LoadContext,
  srcRow: any,
  cache: DictionaryCache,
  ancestorResolver: RollingAncestorResolver
): Promise<void> {
  // Insert raw row into bronze_taxonomies
  const rowId = await insertBronzeRow(client, ctx, srcRow);

  try {
    // Safe getter with normalization
    const rowGet = (colName: string) => normalize(srcRow[colName] ?? '');

    if (ctx.taxonomyType === 'master') {
      await processMasterRow(client, ctx, srcRow, rowId, cache, ancestorResolver, rowGet);
    } else {
      await processCustomerRow(client, ctx, srcRow, rowId, cache, rowGet);
    }

    // Mark bronze row as completed
    await setBronzeRowStatus(client, rowId, 'completed');
  } catch (error: any) {
    // Mark bronze row as failed and append error
    await setBronzeRowStatus(client, rowId, 'failed');
    await appendRowError(client, ctx.loadId, rowId, String(error));
  }
}

/**
 * Process Master taxonomy row (v1.0)
 * §7.1: Single-node row with rolling ancestor parent resolution
 */
async function processMasterRow(
  client: PoolClient,
  ctx: LoadContext,
  srcRow: any,
  rowId: number,
  cache: DictionaryCache,
  ancestorResolver: RollingAncestorResolver,
  rowGet: (colName: string) => string
): Promise<void> {
  const masterLayout = ctx.layout as LayoutMaster;

  // §7.1.1: Extract explicit level and node value(s) from row
  // Determine which level this row represents by finding the first non-empty node column
  let nodeLevel: NodeLevel | null = null;
  let rawValues: string[] = [];

  for (const nl of masterLayout.NodeLevels) {
    const value = rowGet(nl.name);
    if (value && !isNAValue(value)) {
      nodeLevel = nl;
      // Multi-valued cell: split on ';' or other delimiter
      rawValues = value.split(';').map(v => normalize(v)).filter(v => v && !isNAValue(v));
      break;
    }
  }

  // Skip if no node found
  if (!nodeLevel || rawValues.length === 0) {
    return;
  }

  // §2.3: Extract profession from ProfessionColumn (informational, not a node)
  const profession = rowGet(masterLayout.ProfessionColumn);

  // §7.1.1: Build row values map for parent resolution (for N/A checking)
  const rowValues = new Map<number, string | null>();
  for (const nl of masterLayout.NodeLevels) {
    const value = rowGet(nl.name);
    rowValues.set(nl.level, value || null);
  }

  // §7.1.1: Resolve parent using rolling ancestor memory
  const parentNodeId = ancestorResolver.resolveParent(nodeLevel.level, rowValues);

  // Ensure node type exists
  const nodeTypeId = await ensureNodeType(client, nodeLevel.name, ctx.loadId, cache);

  // §7.1.1: Create node(s) at level L (multi-valued cells create siblings)
  let lastCreatedNodeId: number | null = null;

  for (const value of rawValues) {
    // Insert or upsert node at its explicit level
    const nodeId = await upsertNode(client, ctx.loadType, {
      taxonomy_id: ctx.taxonomyId,
      customer_id: ctx.customerId,
      node_type_id: nodeTypeId,
      parent_node_id: parentNodeId,
      value,
      profession, // Stored on node row, not used as hierarchical node
      level: nodeLevel.level,
      load_id: ctx.loadId,
      row_id: rowId,
    });

    // Mark node as loaded (for reconciliation in UPDATED mode)
    if (ctx.loadType === 'updated') {
      await markLoadedNode(client, ctx.taxonomyId, ctx.customerId, nodeTypeId, value);
    }

    lastCreatedNodeId = nodeId;
  }

  // §7.1.1: Update rolling memory for this level
  if (lastCreatedNodeId !== null) {
    ancestorResolver.updateMemory(nodeLevel.level, lastCreatedNodeId);
  }

  // Process attributes on the last created node
  if (lastCreatedNodeId !== null) {
    await processAttributes(
      client,
      ctx,
      srcRow,
      rowId,
      lastCreatedNodeId,
      masterLayout.Attributes,
      cache,
      rowGet
    );
  }
}

/**
 * Process Customer taxonomy row
 * Customer taxonomy logic remains unchanged from previous version
 */
async function processCustomerRow(
  client: PoolClient,
  ctx: LoadContext,
  srcRow: any,
  rowId: number,
  cache: DictionaryCache,
  rowGet: (colName: string) => string
): Promise<void> {
  const customerLayout = ctx.layout as LayoutCustomer;
  const professionCol = customerLayout['Proffesion column'].Profession;
  const value = rowGet(professionCol);

  if (!value) {
    return; // Skip empty rows
  }

  // Ensure node type exists
  const nodeTypeId = await ensureNodeType(client, professionCol, ctx.loadId, cache);

  // Customer taxonomy: single node at level 1, no parent
  const nodeId = await upsertNode(client, ctx.loadType, {
    taxonomy_id: ctx.taxonomyId,
    customer_id: ctx.customerId,
    node_type_id: nodeTypeId,
    parent_node_id: null, // Level 1, no parent
    value,
    profession: value, // For customer, profession = node value
    level: 1,
    load_id: ctx.loadId,
    row_id: rowId,
  });

  // Mark node as loaded (for reconciliation in UPDATED mode)
  if (ctx.loadType === 'updated') {
    await markLoadedNode(client, ctx.taxonomyId, ctx.customerId, nodeTypeId, value);
  }

  // Determine attribute columns (all except profession column)
  const rowKeys = Object.keys(srcRow);
  const attributeColumns = rowKeys.filter(
    (k) => lower(normalize(k)) !== lower(normalize(professionCol))
  );

  await processAttributes(client, ctx, srcRow, rowId, nodeId, attributeColumns, cache, rowGet);
}

/**
 * Process attributes for a node
 */
async function processAttributes(
  client: PoolClient,
  ctx: LoadContext,
  srcRow: any,
  rowId: number,
  nodeId: number,
  attributeColumns: string[],
  cache: DictionaryCache,
  rowGet: (colName: string) => string
): Promise<void> {
  for (const col of attributeColumns) {
    const value = rowGet(col);
    if (!value || isNAValue(value)) continue; // Skip blank/N/A values

    // Ensure attribute type exists
    const attributeTypeId = await ensureAttributeType(client, col, ctx.loadId, cache);

    // Insert or upsert attribute
    await upsertNodeAttribute(client, ctx.loadType, {
      node_id: nodeId,
      attribute_type_id: attributeTypeId,
      value,
      load_id: ctx.loadId,
      row_id: rowId,
    });

    // Mark attribute as loaded (for reconciliation in UPDATED mode)
    if (ctx.loadType === 'updated') {
      await markLoadedAttribute(client, nodeId, attributeTypeId, value);
    }
  }
}

/**
 * Check if a value is considered 'N/A' (empty, null, or literal 'N/A')
 */
function isNAValue(value: string | null | undefined): boolean {
  if (value === null || value === undefined || value === '') {
    return true;
  }

  const normalized = value.trim().toLowerCase();
  return normalized === 'n/a' || normalized === 'na';
}
