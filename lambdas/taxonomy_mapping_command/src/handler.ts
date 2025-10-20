/**
 * Taxonomy Mapping Command Lambda Handler
 * Implements Translation Constant Command Logic Algorithm
 *
 * Maps customer taxonomy nodes to master taxonomy using non-AI command rules
 */

import { Context } from 'aws-lambda';
import { withTransaction, query } from './database/connection';
import { MappingCommandEvent, MappingCommandResponse, CustomerNode, NodeProcessingResult } from './types';
import { RuleLoader } from './services/rule-loader';
import { NodeMatcher } from './services/node-matcher';
import { MappingProcessor } from './services/mapping-processor';
import { VersioningService } from './services/versioning-service';

/**
 * Main Lambda handler
 */
export async function handler(
  event: MappingCommandEvent,
  context: Context
): Promise<MappingCommandResponse> {
  const startTime = Date.now();

  console.log('Mapping Command Lambda invoked', {
    requestId: context.requestId,
    event,
  });

  try {
    // Validate input
    validateEvent(event);

    // Execute mapping within transaction
    const results = await withTransaction(async (client) => {
      // Initialize services
      const ruleLoader = new RuleLoader();
      const nodeMatcher = new NodeMatcher();
      const mappingProcessor = new MappingProcessor();
      const versioningService = new VersioningService();

      // Step 1: Ensure taxonomy version exists
      const versionId = await versioningService.ensureTaxonomyVersion(
        client,
        event.taxonomy_id,
        event.load_id,
        event.load_type
      );

      console.log('Taxonomy version created/found:', versionId);

      // Step 2: Get master taxonomy info
      const masterTaxonomy = await getMasterTaxonomy(client);
      if (!masterTaxonomy) {
        throw new Error('No active master taxonomy found');
      }

      // Step 3: Load customer nodes for this taxonomy
      const customerNodes = await loadCustomerNodes(
        client,
        event.taxonomy_id
      );

      console.log(`Processing ${customerNodes.length} customer nodes`);

      // Step 4: Process each customer node
      const processingResults: NodeProcessingResult[] = [];

      for (const customerNode of customerNodes) {
        try {
          // Load applicable rules for this node type
          const ruleAssignments = await ruleLoader.loadRuleAssignments(
            masterTaxonomy.node_type_id,
            customerNode.node_type_id
          );

          if (ruleAssignments.length === 0) {
            console.warn(
              `No rules found for node type ${customerNode.node_type_id}`
            );
            processingResults.push({
              customer_node_id: customerNode.node_id,
              action_taken: 'no_match',
            });
            continue;
          }

          // Try each rule in priority order until first match
          let matchResult = undefined;
          for (const assignment of ruleAssignments) {
            const result = await nodeMatcher.findMatch(
              customerNode,
              masterTaxonomy.node_type_id,
              assignment.rule
            );

            if (result.matched) {
              matchResult = result;
              break; // Stop at first match (per algorithm spec)
            }
          }

          // Process the mapping based on match result
          const processingResult = await mappingProcessor.processNodeMapping(
            client,
            customerNode,
            matchResult,
            event.load_type
          );

          processingResults.push(processingResult);
        } catch (nodeError) {
          console.error(
            `Error processing node ${customerNode.node_id}:`,
            nodeError
          );
          processingResults.push({
            customer_node_id: customerNode.node_id,
            action_taken: 'no_match',
            error:
              nodeError instanceof Error
                ? nodeError.message
                : String(nodeError),
          });
        }
      }

      // Step 5: Update version counters
      await versioningService.updateVersionCounters(
        client,
        versionId,
        processingResults
      );

      // Step 6: Sync to Gold layer (only active non-AI mappings)
      await syncToGold(client);

      return {
        versionId,
        results: processingResults,
      };
    });

    // Build response
    const response = buildResponse(event, results.results, startTime);
    response.version_id = results.versionId;

    console.log('Mapping completed successfully', response);
    return response;
  } catch (error) {
    console.error('Mapping Command Lambda failed:', error);

    return {
      success: false,
      load_id: event.load_id,
      customer_id: event.customer_id,
      taxonomy_id: event.taxonomy_id,
      results: {
        nodes_processed: 0,
        mappings_created: 0,
        mappings_updated: 0,
        mappings_deactivated: 0,
        mappings_unchanged: 0,
        failures: 0,
      },
      errors: [error instanceof Error ? error.message : String(error)],
      processing_time_ms: Date.now() - startTime,
    };
  }
}

/**
 * Validate event input
 */
function validateEvent(event: MappingCommandEvent): void {
  if (!event.load_id || event.load_id <= 0) {
    throw new Error('Invalid load_id');
  }
  if (!event.customer_id || event.customer_id <= 0) {
    throw new Error('Invalid customer_id');
  }
  if (!event.taxonomy_id || event.taxonomy_id <= 0) {
    throw new Error('Invalid taxonomy_id');
  }
  if (!['new', 'update'].includes(event.load_type)) {
    throw new Error('Invalid load_type - must be "new" or "update"');
  }
}

/**
 * Get active master taxonomy
 */
async function getMasterTaxonomy(client: any): Promise<{ taxonomy_id: number; node_type_id: number } | null> {
  const result = await client.query(`
    SELECT t.taxonomy_id, nt.node_type_id
    FROM silver_taxonomies t
    CROSS JOIN silver_taxonomies_nodes_types nt
    WHERE t.type = 'master'
      AND t.status = 'active'
      AND nt.status = 'active'
    LIMIT 1
  `);

  return result.rows.length > 0 ? result.rows[0] : null;
}

/**
 * Load customer nodes for taxonomy
 */
async function loadCustomerNodes(
  client: any,
  taxonomyId: number
): Promise<CustomerNode[]> {
  const result = await client.query(`
    SELECT
      n.node_id,
      n.node_type_id,
      n.taxonomy_id,
      n.value,
      n.profession,
      n.level
    FROM silver_taxonomies_nodes n
    WHERE n.taxonomy_id = $1
      AND n.status = 'active'
      AND n.level = 0
    ORDER BY n.node_id
  `, [taxonomyId]);

  // Load attributes for each node
  const nodes: CustomerNode[] = [];
  for (const row of result.rows) {
    const attributes = await loadNodeAttributes(client, row.node_id);
    nodes.push({
      node_id: row.node_id,
      node_type_id: row.node_type_id,
      taxonomy_id: row.taxonomy_id,
      value: row.value,
      profession: row.profession,
      level: row.level,
      attributes,
    });
  }

  return nodes;
}

/**
 * Load attributes for a node
 */
async function loadNodeAttributes(client: any, nodeId: number): Promise<any[]> {
  const result = await client.query(`
    SELECT
      na.attribute_type_id,
      at.name as attribute_name,
      na.value
    FROM silver_taxonomies_nodes_attributes na
    INNER JOIN silver_taxonomies_attribute_types at
      ON na.attribute_type_id = at.attribute_type_id
    WHERE na.node_id = $1
      AND na.status = 'active'
  `, [nodeId]);

  return result.rows;
}

/**
 * Sync active non-AI mappings to Gold layer
 */
async function syncToGold(client: any): Promise<void> {
  await client.query(`SELECT sync_gold_mapping_taxonomies()`);
}

/**
 * Build response from processing results
 */
function buildResponse(
  event: MappingCommandEvent,
  results: NodeProcessingResult[],
  startTime: number
): MappingCommandResponse {
  const summary = {
    nodes_processed: results.length,
    mappings_created: results.filter((r) => r.action_taken === 'created').length,
    mappings_updated: results.filter((r) => r.action_taken === 'updated').length,
    mappings_deactivated: results.filter((r) => r.action_taken === 'deactivated').length,
    mappings_unchanged: results.filter((r) => r.action_taken === 'unchanged').length,
    failures: results.filter((r) => r.error).length,
  };

  const errors = results
    .filter((r) => r.error)
    .map((r) => `Node ${r.customer_node_id}: ${r.error}`);

  return {
    success: summary.failures === 0 || summary.failures < results.length,
    load_id: event.load_id,
    customer_id: event.customer_id,
    taxonomy_id: event.taxonomy_id,
    results: summary,
    errors: errors.length > 0 ? errors : undefined,
    processing_time_ms: Date.now() - startTime,
  };
}
