/**
 * NLP Qualifier Matcher
 * Qualifier-aware pattern matching for profession taxonomies
 */

import { Pool } from 'pg';
import { VocabularyExtractor, TaxonomyVocabularies } from '../services/vocabulary-extractor';
import { normalize, tokenize, containsPhrase, findPhraseIndex, hasQualifier } from '../utils/text-normalizer';

export interface MasterNode {
  node_id: number;
  value: string;
  level: number;
  taxonomy_id: number;
}

export interface MatchResult {
  matched: boolean;
  master_node_id?: number;
  confidence: number;
  method: string;
  reasoning?: string;
}

export class NLPQualifierMatcher {
  private pool: Pool;
  private vocabularyExtractor: VocabularyExtractor;
  private vocabs?: TaxonomyVocabularies;

  constructor(pool: Pool) {
    this.pool = pool;
    this.vocabularyExtractor = new VocabularyExtractor(pool);
  }

  /**
   * Initialize vocabularies for master taxonomy
   */
  async initialize(masterTaxonomyId: number): Promise<void> {
    this.vocabs = await this.vocabularyExtractor.extract(masterTaxonomyId);
  }

  /**
   * Match customer value against master nodes
   */
  async match(customerValue: string, masterNodes: MasterNode[]): Promise<MatchResult> {
    if (!this.vocabs) {
      throw new Error('NLPQualifierMatcher not initialized. Call initialize() first.');
    }

    const tokens = tokenize(customerValue);
    if (tokens.length === 0) {
      return { matched: false, confidence: 0, method: 'nlp_empty' };
    }

    // 1. Try strong occupation match (highest confidence)
    const strongResult = this.matchStrongOccupation(tokens, masterNodes);
    if (strongResult.matched) {
      return strongResult;
    }

    // 2. Try qualified suffix (QUALIFIER + HEAD)
    const suffixResult = this.matchQualifiedSuffix(tokens, masterNodes);
    if (suffixResult.matched) {
      return suffixResult;
    }

    // 3. Try qualified prefix (HEAD + QUALIFIER)
    const prefixResult = this.matchQualifiedPrefix(tokens, masterNodes);
    if (prefixResult.matched) {
      return prefixResult;
    }

    return { matched: false, confidence: 0, method: 'nlp_no_match' };
  }

  /**
   * Match strong occupation (multi-word detailed occupation)
   */
  private matchStrongOccupation(tokens: string[], masterNodes: MasterNode[]): MatchResult {
    for (const head of this.vocabs!.strongHeads) {
      if (containsPhrase(tokens, head)) {
        // Find master node with this value
        const master = this.findMasterByValue(masterNodes, head);
        if (master) {
          return {
            matched: true,
            master_node_id: master.node_id,
            confidence: 95,
            method: 'nlp_strong_occupation',
            reasoning: `Strong occupation: ${head}`,
          };
        }
      }
    }

    return { matched: false, confidence: 0, method: 'nlp_strong_occupation' };
  }

  /**
   * Match qualified suffix (QUALIFIER + HEAD)
   */
  private matchQualifiedSuffix(tokens: string[], masterNodes: MasterNode[]): MatchResult {
    for (const head of this.vocabs!.qualifiedHeads) {
      const headIndex = findPhraseIndex(tokens, head);

      if (headIndex > 0) {  // Must have prefix
        const prefix = tokens.slice(0, headIndex).join(' ');

        if (hasQualifier(prefix, this.vocabs!.qualifiers)) {
          const fullPhrase = tokens.join(' ');
          const master = this.findMasterByValueFuzzy(masterNodes, fullPhrase);

          if (master) {
            return {
              matched: true,
              master_node_id: master.node_id,
              confidence: 90,
              method: 'nlp_qualified_suffix',
              reasoning: `Qualified suffix: ${prefix} + ${head}`,
            };
          }
        }
      }
    }

    return { matched: false, confidence: 0, method: 'nlp_qualified_suffix' };
  }

  /**
   * Match qualified prefix (HEAD + QUALIFIER)
   */
  private matchQualifiedPrefix(tokens: string[], masterNodes: MasterNode[]): MatchResult {
    for (const head of this.vocabs!.qualifiedHeads) {
      const headTokens = head.split(' ');
      const headIndex = findPhraseIndex(tokens, head);
      const headLength = headTokens.length;

      if (headIndex >= 0 && headIndex + headLength < tokens.length) {  // Must have suffix
        const suffix = tokens.slice(headIndex + headLength).join(' ');

        if (hasQualifier(suffix, this.vocabs!.qualifiers)) {
          const fullPhrase = tokens.join(' ');
          const master = this.findMasterByValueFuzzy(masterNodes, fullPhrase);

          if (master) {
            return {
              matched: true,
              master_node_id: master.node_id,
              confidence: 90,
              method: 'nlp_qualified_prefix',
              reasoning: `Qualified prefix: ${head} + ${suffix}`,
            };
          }
        }
      }
    }

    return { matched: false, confidence: 0, method: 'nlp_qualified_prefix' };
  }

  /**
   * Find master node by exact value match
   */
  private findMasterByValue(masterNodes: MasterNode[], value: string): MasterNode | null {
    const normalized = normalize(value);
    for (const node of masterNodes) {
      if (normalize(node.value) === normalized) {
        return node;
      }
    }
    return null;
  }

  /**
   * Find master node by fuzzy value match (contains)
   */
  private findMasterByValueFuzzy(masterNodes: MasterNode[], value: string): MasterNode | null {
    const normalized = normalize(value);

    // Try exact first
    for (const node of masterNodes) {
      if (normalize(node.value) === normalized) {
        return node;
      }
    }

    // Try contains
    for (const node of masterNodes) {
      const nodeValue = normalize(node.value);
      if (nodeValue.includes(normalized) || normalized.includes(nodeValue)) {
        return node;
      }
    }

    return null;
  }
}
