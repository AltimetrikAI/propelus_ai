/**
 * Load Orchestrator - Main Processing Pipeline
 * Orchestrates the complete Bronze → Silver transformation
 * Implements algorithm §1 through §8
 */
import { Pool } from 'pg';
import { LoadContext, LoadType, Layout, LayoutMaster } from '../types';
import { withTransaction } from '../database/connection';
import { openLoad, updateLoadHeader, finalizeLoad } from '../database/queries/load';
import { ensureSilverTaxonomy, deriveLoadType } from '../database/queries/silver-taxonomy';
import { ensureNodeType, ensureAttributeType } from '../database/queries/silver-dictionaries';
import {
  createTempReconciliationTables,
  deactivateMissingNodes,
  deactivateMissingAttributes
} from '../database/queries/reconciliation';
import { writeVersion } from '../database/queries/versioning';
import { processRow } from './row-processor';
import { RollingAncestorResolver } from './rolling-ancestor-resolver';

export interface OrchestrationInput {
  taxonomyType: 'master' | 'customer';
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
  description?: string;  // Optional human-friendly description
  rows: any[];
  layout: Layout;
  sourceType: 'api' | 's3';
  sourceDetails: any; // For seed JSON in bronze_load_details
}

export interface OrchestrationResult {
  ok: boolean;
  load_id: number;
  customer_id: string;
  taxonomy_id: string;
  taxonomy_type: string;
  load_type: LoadType;
  rows_processed: number;
}

/**
 * Main orchestration function for complete load process
 * Follows algorithm §1-§8
 */
export async function orchestrateLoad(
  pool: Pool,
  input: OrchestrationInput
): Promise<OrchestrationResult> {
  const {
    taxonomyType,
    customerId,
    taxonomyId,
    taxonomyName,
    description,
    rows,
    layout,
    sourceType,
    sourceDetails
  } = input;

  // §1: Open load in bronze_load_details
  const loadId = await openLoad(pool, taxonomyType, sourceDetails);

  try {
    // §3: Derive load_type (new vs updated)
    const loadType = await deriveLoadType(pool, customerId, taxonomyId);

    // §3: Update load header with IDs, row count, layout, and load_type
    const layoutFragment = buildLayoutFragment(layout, taxonomyType);
    await updateLoadHeader(
      pool,
      loadId,
      customerId,
      taxonomyId,
      rows.length,
      loadType,
      layoutFragment
    );

    // Build load context
    const ctx: LoadContext = {
      loadId,
      customerId,
      taxonomyId,
      taxonomyName,
      description,
      taxonomyType,
      loadType,
      layout,
      rows,
    };

    // §3: Ensure silver_taxonomies header row exists
    await ensureSilverTaxonomy(pool, ctx);

    // §6: Pre-populate dictionaries (append-only)
    await populateDictionaries(pool, ctx);

    // §7: Transform rows → Silver (with reconciliation for updated loads)
    await withTransaction(pool, async (cx) => {
      // Create temp reconciliation tables if updated load (§7B)
      if (ctx.loadType === 'updated') {
        await createTempReconciliationTables(cx);
      }

      // Dictionary cache for performance optimization
      const cache = {
        nodeTypes: new Map<string, number>(),
        attrTypes: new Map<string, number>(),
      };

      // §7.1.1: Initialize rolling ancestor resolver (v1.0)
      // Maintains last_seen[level] state across all rows for parent resolution
      const ancestorResolver = new RollingAncestorResolver(cx);

      // Process each row: bronze insert + silver transformation (§7)
      for (const srcRow of ctx.rows) {
        await processRow(cx, ctx, srcRow, cache, ancestorResolver);
      }

      // Reconciliation: deactivate missing nodes/attributes (§7B.3, §7B.4)
      if (ctx.loadType === 'updated') {
        await deactivateMissingNodes(cx, ctx.taxonomyId, ctx.customerId, ctx.loadId);
        await deactivateMissingAttributes(cx, ctx.loadId);
      }

      // Write version record (§7A.3, §7B.5)
      await writeVersion(cx, ctx, ctx.loadType);
    });

    // §8: Finalize load (compute row counts, set final status)
    await finalizeLoad(pool, loadId);

    // Return success result
    return {
      ok: true,
      load_id: loadId,
      customer_id: customerId,
      taxonomy_id: taxonomyId,
      taxonomy_type: taxonomyType,
      load_type: loadType,
      rows_processed: rows.length,
    };

  } catch (err: any) {
    // If load fails, mark it as failed in bronze_load_details
    try {
      await pool.query(
        `
        -- Mark the load as failed, set end time, and add the error to load_details
        update bronze_load_details
           set load_end=now(),
               load_status='failed',
               load_details = coalesce(load_details, '{}'::jsonb)
                                || jsonb_build_object('Request Status','Failed','Error', $2)
         where load_id=$1;
      `,
        [loadId, String(err?.message ?? err)]
      );
    } catch {
      // Ignore secondary failure (best-effort)
    }
    throw err; // Re-throw original error
  }
}

/**
 * Build layout fragment for bronze_load_details JSON - §4
 */
function buildLayoutFragment(layout: Layout, taxonomyType: 'master' | 'customer'): any {
  if (taxonomyType === 'master') {
    const masterLayout = layout as LayoutMaster;
    if (!('Nodes' in masterLayout)) {
      throw new Error('Master layout must contain Nodes and Attributes.');
    }
    return layout; // Already has Nodes[] & Attributes[]
  } else {
    return layout; // Customer has "Proffesion column"
  }
}

/**
 * Pre-populate dictionaries with known node/attribute types - §6
 * Append-only: insert if not exists, never modify
 */
async function populateDictionaries(pool: Pool, ctx: LoadContext) {
  await withTransaction(pool, async (cx) => {
    // Extract node type names from layout
    const nodeNames = getNodeTypeNames(ctx);

    // Extract attribute type names from layout (master only; customer attributes are dynamic)
    const attrNames = getAttributeTypeNames(ctx);

    // Insert node types (append-only, never update) - §6.1
    for (const name of nodeNames) {
      await ensureNodeType(cx, name, ctx.loadId);
    }

    // Insert attribute types (append-only, never update) - §6.2
    for (const name of attrNames) {
      await ensureAttributeType(cx, name, ctx.loadId);
    }
  });
}

/**
 * Extract node type names from layout
 */
function getNodeTypeNames(ctx: LoadContext): string[] {
  if (ctx.taxonomyType === 'master') {
    const masterLayout = ctx.layout as LayoutMaster;
    return Array.from(new Set(masterLayout.Nodes));
  } else {
    // Customer: single node type (profession column)
    const customerLayout = ctx.layout as any;
    return [customerLayout["Proffesion column"].Profession];
  }
}

/**
 * Extract attribute type names from layout
 * For master: explicit attribute columns
 * For customer: attributes are dynamic (determined per row)
 */
function getAttributeTypeNames(ctx: LoadContext): string[] {
  if (ctx.taxonomyType === 'master') {
    const masterLayout = ctx.layout as LayoutMaster;
    return Array.from(new Set(masterLayout.Attributes));
  } else {
    // Customer: attributes discovered dynamically during row processing
    return [];
  }
}
