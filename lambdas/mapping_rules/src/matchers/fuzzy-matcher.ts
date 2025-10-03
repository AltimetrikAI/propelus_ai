/**
 * Fuzzy Matcher
 *
 * Performs fuzzy string matching using Levenshtein distance.
 * Useful for handling typos, abbreviations, and similar spellings.
 */

import { compareTwoStrings } from 'string-similarity';
import leven from 'leven';
import { logger } from '../../../../shared/utils/logger';
import { SilverTaxonomiesNodes } from '../../../../shared/database/entities/silver.entity';
import { MappingDecision } from '../services/mapping-engine';

export class FuzzyMatcher {
  private readonly MIN_SIMILARITY_THRESHOLD = 0.7; // 70% similarity
  private readonly MAX_LEVENSHTEIN_DISTANCE = 3; // Max 3 character differences

  /**
   * Find fuzzy match for a child node in master nodes
   */
  async findMatch(
    childNode: SilverTaxonomiesNodes,
    masterNodes: SilverTaxonomiesNodes[]
  ): Promise<MappingDecision | null> {
    logger.info('Attempting fuzzy match', { childNodeId: childNode.node_id });

    let bestMatch: MappingDecision | null = null;
    let bestSimilarity = 0;

    const childValue = this.normalizeValue(childNode.value);

    for (const masterNode of masterNodes) {
      // Only compare nodes of the same type
      if (childNode.node_type_id !== masterNode.node_type_id) {
        continue;
      }

      const masterValue = this.normalizeValue(masterNode.value);

      // Calculate similarity using string-similarity library
      const similarity = compareTwoStrings(childValue, masterValue);

      // Calculate Levenshtein distance
      const distance = leven(childValue, masterValue);

      // Check if this is a good match
      if (
        similarity >= this.MIN_SIMILARITY_THRESHOLD &&
        distance <= this.MAX_LEVENSHTEIN_DISTANCE &&
        similarity > bestSimilarity
      ) {
        bestSimilarity = similarity;
        bestMatch = {
          masterNodeId: masterNode.node_id,
          childNodeId: childNode.node_id,
          confidence: similarity,
          matchType: 'fuzzy',
          ruleId: 2, // Fuzzy match rule
        };

        logger.info('Potential fuzzy match found', {
          childNodeId: childNode.node_id,
          masterNodeId: masterNode.node_id,
          similarity,
          distance,
        });
      }
    }

    // Also try fuzzy matching on profession field
    if (!bestMatch && childNode.profession) {
      const professionMatch = await this.matchByProfession(childNode, masterNodes);
      if (professionMatch && professionMatch.confidence > bestSimilarity) {
        bestMatch = professionMatch;
      }
    }

    if (bestMatch) {
      logger.info('Fuzzy match selected', {
        childNodeId: childNode.node_id,
        masterNodeId: bestMatch.masterNodeId,
        confidence: bestMatch.confidence,
      });
    } else {
      logger.info('No fuzzy match found', { childNodeId: childNode.node_id });
    }

    return bestMatch;
  }

  /**
   * Match by profession field
   */
  private async matchByProfession(
    childNode: SilverTaxonomiesNodes,
    masterNodes: SilverTaxonomiesNodes[]
  ): Promise<MappingDecision | null> {
    if (!childNode.profession) return null;

    let bestMatch: MappingDecision | null = null;
    let bestSimilarity = 0;

    const childProfession = this.normalizeValue(childNode.profession);

    for (const masterNode of masterNodes) {
      if (!masterNode.profession) continue;

      const masterProfession = this.normalizeValue(masterNode.profession);
      const similarity = compareTwoStrings(childProfession, masterProfession);

      if (similarity >= this.MIN_SIMILARITY_THRESHOLD && similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = {
          masterNodeId: masterNode.node_id,
          childNodeId: childNode.node_id,
          confidence: similarity * 0.9, // Slightly reduce confidence for profession match
          matchType: 'fuzzy',
          ruleId: 2,
        };
      }
    }

    return bestMatch;
  }

  /**
   * Normalize value for comparison
   */
  private normalizeValue(value: string): string {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^\w\s]/g, '')
      .replace(/\s+/g, ' ');
  }

  /**
   * Calculate normalized similarity (0-1)
   */
  private calculateSimilarity(str1: string, str2: string): number {
    const maxLength = Math.max(str1.length, str2.length);
    const distance = leven(str1, str2);
    return 1 - distance / maxLength;
  }
}
