/**
 * Mapping Engine
 *
 * Orchestrates mapping process using multiple strategies:
 * 1. Exact matching
 * 2. NLP Qualifier matching (qualifier-aware patterns)
 * 3. Fuzzy matching (Levenshtein distance)
 * 4. AI semantic matching (Bedrock)
 */

import { AppDataSource } from '../../../../shared/database/connection';
import { logger } from '../../../../shared/utils/logger';
import { NA_NODE_TYPE_ID } from '@propelus/shared';
import { SilverTaxonomiesNodes } from '../../../../shared/database/entities/silver.entity';
import {
  SilverMappingTaxonomies,
  SilverMappingTaxonomiesRules,
} from '../../../../shared/database/entities/mapping.entity';
import { ExactMatcher } from '../matchers/exact-matcher';
import { NLPQualifierMatcher } from '../matchers/nlp-qualifier-matcher';
import { FuzzyMatcher } from '../matchers/fuzzy-matcher';
import { AISemanticMatcher } from '../matchers/ai-semantic-matcher';
import { Pool } from 'pg';

export interface MappingResult {
  totalNodes: number;
  mappedNodes: number;
  unmappedNodes: number;
  exactMatches: number;
  nlpMatches: number;
  fuzzyMatches: number;
  aiMatches: number;
  lowConfidenceMatches: number;
}

export interface MappingDecision {
  masterNodeId: number;
  childNodeId: number;
  confidence: number;
  matchType: 'exact' | 'nlp_qualifier' | 'fuzzy' | 'ai_semantic';
  ruleId: number;
}

export class MappingEngine {
  private exactMatcher: ExactMatcher;
  private nlpMatcher: NLPQualifierMatcher;
  private fuzzyMatcher: FuzzyMatcher;
  private aiMatcher: AISemanticMatcher;
  private pool: Pool;

  constructor(pool: Pool) {
    this.pool = pool;
    this.exactMatcher = new ExactMatcher();
    this.nlpMatcher = new NLPQualifierMatcher(pool);
    this.fuzzyMatcher = new FuzzyMatcher();
    this.aiMatcher = new AISemanticMatcher();
  }

  /**
   * Process mappings for a customer taxonomy
   */
  async processMappings(
    customerId: string,  // Updated to string (VARCHAR 255) - v4.1.0
    taxonomyId: number,
    nodeIds?: number[]
  ): Promise<MappingResult> {
    logger.info('Starting mapping process', { customerId, taxonomyId, nodeIds });

    const result: MappingResult = {
      totalNodes: 0,
      mappedNodes: 0,
      unmappedNodes: 0,
      exactMatches: 0,
      nlpMatches: 0,
      fuzzyMatches: 0,
      aiMatches: 0,
      lowConfidenceMatches: 0,
    };

    try {
      // Get nodes to map
      const nodesToMap = await this.getNodestToMap(taxonomyId, nodeIds);
      result.totalNodes = nodesToMap.length;

      logger.info(`Found ${nodesToMap.length} nodes to map`);

      // Get master taxonomy nodes (taxonomy with type='master')
      const masterNodes = await this.getMasterTaxonomyNodes();

      logger.info(`Found ${masterNodes.length} master taxonomy nodes`);

      // Initialize NLP matcher with master taxonomy
      const masterTaxonomyId = masterNodes[0]?.taxonomy_id;
      if (masterTaxonomyId) {
        await this.nlpMatcher.initialize(masterTaxonomyId);
      }

      for (const childNode of nodesToMap) {
        try {
          // Try exact match first
          let mappingDecision = await this.exactMatcher.findMatch(childNode, masterNodes);

          if (mappingDecision) {
            result.exactMatches++;
          } else {
            // Try NLP qualifier match
            const nlpResult = await this.nlpMatcher.match(
              childNode.value,
              masterNodes.map(n => ({
                node_id: n.node_id,
                value: n.value,
                level: n.level,
                taxonomy_id: n.taxonomy_id
              }))
            );

            if (nlpResult.matched) {
              mappingDecision = {
                masterNodeId: nlpResult.master_node_id!,
                childNodeId: childNode.node_id,
                confidence: nlpResult.confidence / 100, // Convert to 0-1 scale
                matchType: 'nlp_qualifier',
                ruleId: 0, // NLP matcher doesn't use specific rule ID
              };
              result.nlpMatches++;
            } else {
              // Try fuzzy match
              mappingDecision = await this.fuzzyMatcher.findMatch(childNode, masterNodes);

              if (mappingDecision && mappingDecision.confidence >= 0.7) {
                result.fuzzyMatches++;
              } else {
                // Try AI semantic match
                mappingDecision = await this.aiMatcher.findMatch(childNode, masterNodes);

                if (mappingDecision) {
                  result.aiMatches++;
                }
              }
            }
          }

          if (mappingDecision) {
            // Save mapping
            await this.saveMappingDecision(mappingDecision);

            result.mappedNodes++;

            if (mappingDecision.confidence < 0.7) {
              result.lowConfidenceMatches++;
              logger.warn('Low confidence mapping', {
                childNodeId: childNode.node_id,
                confidence: mappingDecision.confidence,
              });
            }
          } else {
            result.unmappedNodes++;
            logger.warn('No mapping found for node', { nodeId: childNode.node_id });
          }
        } catch (error) {
          logger.error('Failed to process node mapping', {
            nodeId: childNode.node_id,
            error: error instanceof Error ? error.message : String(error),
          });
          result.unmappedNodes++;
        }
      }

      logger.info('Mapping process completed', { result });

      return result;
    } catch (error) {
      logger.error('Mapping process failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  /**
   * Get nodes to map from Silver layer (excluding N/A placeholders)
   */
  private async getNodestToMap(
    taxonomyId: number,
    nodeIds?: number[]
  ): Promise<SilverTaxonomiesNodes[]> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodes);

    if (nodeIds && nodeIds.length > 0) {
      return await repo
        .createQueryBuilder('node')
        .where('node.taxonomy_id = :taxonomyId', { taxonomyId })
        .andWhere('node.node_id IN (:...nodeIds)', { nodeIds })
        .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
        .getMany();
    }

    // Exclude N/A placeholder nodes from mapping candidates
    return await repo
      .createQueryBuilder('node')
      .where('node.taxonomy_id = :taxonomyId', { taxonomyId })
      .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
      .getMany();
  }

  /**
   * Get master taxonomy nodes (excluding N/A placeholders)
   */
  private async getMasterTaxonomyNodes(): Promise<SilverTaxonomiesNodes[]> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodes);

    // Get master taxonomy
    const masterTaxonomy = await AppDataSource.getRepository('SilverTaxonomies').findOne({
      where: { type: 'master', status: 'active' },
    });

    if (!masterTaxonomy) {
      throw new Error('Master taxonomy not found');
    }

    // Exclude N/A placeholder nodes from matching candidates
    return await repo
      .createQueryBuilder('node')
      .where('node.taxonomy_id = :taxonomyId', { taxonomyId: (masterTaxonomy as any).taxonomy_id })
      .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
      .leftJoinAndSelect('node.attributes', 'attributes')
      .getMany();
  }

  /**
   * Save mapping decision
   */
  private async saveMappingDecision(decision: MappingDecision): Promise<void> {
    const repo = AppDataSource.getRepository(SilverMappingTaxonomies);

    // Check if mapping already exists
    const existing = await repo.findOne({
      where: {
        master_node_id: decision.masterNodeId,
        child_node_id: decision.childNodeId,
        is_active: true,
      },
    });

    if (existing) {
      // Update existing mapping
      await repo.update(existing.mapping_id, {
        confidence: decision.confidence,
        last_updated_at: new Date(),
      });

      logger.info('Updated existing mapping', {
        mappingId: existing.mapping_id,
        confidence: decision.confidence,
      });
    } else {
      // Create new mapping
      const mapping = repo.create({
        mapping_rule_id: decision.ruleId,
        master_node_id: decision.masterNodeId,
        child_node_id: decision.childNodeId,
        confidence: decision.confidence,
        status: decision.confidence >= 0.7 ? 'active' : 'pending_review',
        is_active: true,
        mapping_version: 1,
      });

      await repo.save(mapping);

      logger.info('Created new mapping', {
        mappingId: mapping.mapping_id,
        matchType: decision.matchType,
        confidence: decision.confidence,
      });
    }
  }
}
