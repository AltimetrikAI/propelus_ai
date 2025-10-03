/**
 * Mapping Engine
 *
 * Orchestrates mapping process using multiple strategies:
 * 1. Exact matching
 * 2. Fuzzy matching (Levenshtein distance)
 * 3. AI semantic matching (Bedrock)
 */

import { AppDataSource } from '../../../../shared/database/connection';
import { logger } from '../../../../shared/utils/logger';
import { SilverTaxonomiesNodes } from '../../../../shared/database/entities/silver.entity';
import {
  SilverMappingTaxonomies,
  SilverMappingTaxonomiesRules,
} from '../../../../shared/database/entities/mapping.entity';
import { ExactMatcher } from '../matchers/exact-matcher';
import { FuzzyMatcher } from '../matchers/fuzzy-matcher';
import { AISemanticMatcher } from '../matchers/ai-semantic-matcher';

export interface MappingResult {
  totalNodes: number;
  mappedNodes: number;
  unmappedNodes: number;
  exactMatches: number;
  fuzzyMatches: number;
  aiMatches: number;
  lowConfidenceMatches: number;
}

export interface MappingDecision {
  masterNodeId: number;
  childNodeId: number;
  confidence: number;
  matchType: 'exact' | 'fuzzy' | 'ai_semantic';
  ruleId: number;
}

export class MappingEngine {
  private exactMatcher: ExactMatcher;
  private fuzzyMatcher: FuzzyMatcher;
  private aiMatcher: AISemanticMatcher;

  constructor() {
    this.exactMatcher = new ExactMatcher();
    this.fuzzyMatcher = new FuzzyMatcher();
    this.aiMatcher = new AISemanticMatcher();
  }

  /**
   * Process mappings for a customer taxonomy
   */
  async processMappings(
    customerId: number,
    taxonomyId: number,
    nodeIds?: number[]
  ): Promise<MappingResult> {
    logger.info('Starting mapping process', { customerId, taxonomyId, nodeIds });

    const result: MappingResult = {
      totalNodes: 0,
      mappedNodes: 0,
      unmappedNodes: 0,
      exactMatches: 0,
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

      for (const childNode of nodesToMap) {
        try {
          // Try exact match first
          let mappingDecision = await this.exactMatcher.findMatch(childNode, masterNodes);

          if (mappingDecision) {
            result.exactMatches++;
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
   * Get nodes to map from Silver layer
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
        .getMany();
    }

    return await repo.find({ where: { taxonomy_id: taxonomyId } });
  }

  /**
   * Get master taxonomy nodes
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

    return await repo.find({
      where: { taxonomy_id: (masterTaxonomy as any).taxonomy_id },
      relations: ['attributes'],
    });
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
