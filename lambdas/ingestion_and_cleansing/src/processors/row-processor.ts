/**
 * Row Processor (Algorithm §7)
 * Processes individual rows: builds node chains and attaches attributes
 */

import { PoolClient } from 'pg';
import { LoadContext, DictionaryCache } from '../types/context';
import { LayoutMaster, LayoutCustomer } from '../types/layout';
import { normalize, lower } from '../utils/normalization';
import { insertBronzeRow, setBronzeRowStatus, appendRowError } from '../database/queries/bronze';
import { ensureNodeType, ensureAttributeType } from '../database/queries/silver-dictionaries';
import { upsertNode } from '../database/queries/silver-nodes';
import { upsertNodeAttribute } from '../database/queries/silver-attributes';
import { markLoadedNode, markLoadedAttribute } from '../database/queries/reconciliation';
import { NANodeHandler } from '@propelus/shared';

interface NodePiece {
  nodeTypeName: string;
  value: string;
  intendedLevel: number;  // Semantic level from column position
}

/**
 * §7: Process single row - build node chain and attach attributes
 */
export async function processRow(
  client: PoolClient,
  ctx: LoadContext,
  srcRow: any,
  cache: DictionaryCache
): Promise<void> {
  // Insert raw row into bronze_taxonomies
  const rowId = await insertBronzeRow(client, ctx, srcRow);

  try {
    // Safe getter with normalization
    const rowGet = (colName: string) => normalize(srcRow[colName] ?? '');

    // Build node chain based on taxonomy type
    const chain: NodePiece[] = [];

    if (ctx.taxonomyType === 'master') {
      // Master taxonomy: ordered node columns from layout
      const masterLayout = ctx.layout as LayoutMaster;
      for (let colIndex = 0; colIndex < masterLayout.Nodes.length; colIndex++) {
        const col = masterLayout.Nodes[colIndex];
        const value = rowGet(col);
        if (value) {
          // Track intended level based on column position (1-indexed)
          chain.push({
            nodeTypeName: col,
            value,
            intendedLevel: colIndex + 1
          });
        }
      }
    } else {
      // Customer taxonomy: single profession column at level 1
      const customerLayout = ctx.layout as LayoutCustomer;
      const professionCol = customerLayout['Proffesion column'].Profession;
      const value = rowGet(professionCol);
      if (value) {
        chain.push({
          nodeTypeName: professionCol,
          value,
          intendedLevel: 1
        });
      }
    }

    // Skip if no nodes in chain
    if (chain.length === 0) {
      await setBronzeRowStatus(client, rowId, 'completed');
      return;
    }

    // Profession = rightmost node value
    const profession = chain[chain.length - 1].value;

    // Initialize N/A node handler for automatic gap filling
    const naHandler = new NANodeHandler(client);

    // Walk chain to insert/upsert nodes with parent relationships
    let lastNodeId: number | null = null;
    let lastNodeLevel: number | null = null;
    let finalNodeId = -1;

    for (let i = 0; i < chain.length; i++) {
      const piece = chain[i];

      // Ensure node type exists
      const nodeTypeId = await ensureNodeType(client, piece.nodeTypeName, ctx.loadId, cache);

      // Determine parent with automatic N/A gap filling
      const parentNodeId = await naHandler.getOrCreateParentNode(
        ctx.taxonomyId,
        piece.intendedLevel,
        lastNodeId,
        lastNodeLevel,
        ctx.loadId,
        rowId
      );

      // Insert or upsert node at its intended level
      const nodeId = await upsertNode(client, ctx.loadType, {
        taxonomy_id: ctx.taxonomyId,
        customer_id: ctx.customerId,
        node_type_id: nodeTypeId,
        parent_node_id: parentNodeId,
        value: piece.value,
        profession,
        level: ctx.taxonomyType === 'master' ? piece.intendedLevel : 1,
        load_id: ctx.loadId,
        row_id: rowId,
      });

      // Mark node as loaded (for reconciliation in UPDATED mode)
      if (ctx.loadType === 'updated') {
        await markLoadedNode(client, ctx.taxonomyId, ctx.customerId, nodeTypeId, piece.value);
      }

      lastNodeId = nodeId;
      lastNodeLevel = piece.intendedLevel;
      finalNodeId = nodeId;
    }

    // Determine attribute columns
    let attributeColumns: string[] = [];
    const rowKeys = Object.keys(srcRow);

    if (ctx.taxonomyType === 'master') {
      // Master: explicit attribute columns from layout
      const masterLayout = ctx.layout as LayoutMaster;
      attributeColumns = masterLayout.Attributes;
    } else {
      // Customer: all columns except profession column
      const customerLayout = ctx.layout as LayoutCustomer;
      const professionCol = customerLayout['Proffesion column'].Profession;
      attributeColumns = rowKeys.filter((k) => lower(normalize(k)) !== lower(normalize(professionCol)));
    }

    // Process attributes
    for (const col of attributeColumns) {
      const value = rowGet(col);
      if (!value) continue; // Skip blank values

      // Ensure attribute type exists
      const attributeTypeId = await ensureAttributeType(client, col, ctx.loadId, cache);

      // Insert or upsert attribute
      await upsertNodeAttribute(client, ctx.loadType, {
        node_id: finalNodeId,
        attribute_type_id: attributeTypeId,
        value,
        load_id: ctx.loadId,
        row_id: rowId,
      });

      // Mark attribute as loaded (for reconciliation in UPDATED mode)
      if (ctx.loadType === 'updated') {
        await markLoadedAttribute(client, finalNodeId, attributeTypeId, value);
      }
    }

    // Mark bronze row as completed
    await setBronzeRowStatus(client, rowId, 'completed');
  } catch (error: any) {
    // Mark bronze row as failed and append error
    await setBronzeRowStatus(client, rowId, 'failed');
    await appendRowError(client, ctx.loadId, rowId, String(error));
  }
}
