/**
 * Exact Matcher
 *
 * Performs exact string matching for taxonomy mapping.
 * Handles case-insensitive comparison and attribute matching.
 */

import { logger } from '../../../../shared/utils/logger';
import { SilverTaxonomiesNodes } from '../../../../shared/database/entities/silver.entity';
import { MappingDecision } from '../services/mapping-engine';

export class ExactMatcher {
  /**
   * Find exact match for a child node in master nodes
   */
  async findMatch(
    childNode: SilverTaxonomiesNodes,
    masterNodes: SilverTaxonomiesNodes[]
  ): Promise<MappingDecision | null> {
    logger.info('Attempting exact match', { childNodeId: childNode.node_id });

    // Normalize child node value
    const normalizedChild = this.normalizeValue(childNode.value);

    // Find exact match in master nodes
    for (const masterNode of masterNodes) {
      const normalizedMaster = this.normalizeValue(masterNode.value);

      if (normalizedChild === normalizedMaster) {
        // Check if node types match
        if (childNode.node_type_id === masterNode.node_type_id) {
          logger.info('Exact match found', {
            childNodeId: childNode.node_id,
            masterNodeId: masterNode.node_id,
          });

          return {
            masterNodeId: masterNode.node_id,
            childNodeId: childNode.node_id,
            confidence: 1.0,
            matchType: 'exact',
            ruleId: 1, // Default exact match rule
          };
        }
      }
    }

    // Try matching with profession field
    if (childNode.profession) {
      const normalizedProfession = this.normalizeValue(childNode.profession);

      for (const masterNode of masterNodes) {
        if (masterNode.profession) {
          const normalizedMasterProf = this.normalizeValue(masterNode.profession);

          if (normalizedProfession === normalizedMasterProf) {
            logger.info('Exact profession match found', {
              childNodeId: childNode.node_id,
              masterNodeId: masterNode.node_id,
            });

            return {
              masterNodeId: masterNode.node_id,
              childNodeId: childNode.node_id,
              confidence: 0.95, // Slightly lower for profession match
              matchType: 'exact',
              ruleId: 1,
            };
          }
        }
      }
    }

    logger.info('No exact match found', { childNodeId: childNode.node_id });
    return null;
  }

  /**
   * Normalize value for comparison
   */
  private normalizeValue(value: string): string {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^\w\s]/g, '') // Remove special characters
      .replace(/\s+/g, ' '); // Normalize whitespace
  }
}
