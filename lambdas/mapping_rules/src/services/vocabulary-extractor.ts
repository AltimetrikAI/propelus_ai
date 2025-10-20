/**
 * Vocabulary Extractor Service
 * Extracts matching vocabularies from taxonomy hierarchy
 */

import { Pool } from 'pg';

export interface TaxonomyVocabularies {
  strongHeads: Set<string>;
  qualifiedHeads: Set<string>;
  qualifiers: Set<string>;
}

const GENERIC_TERMS = [
  'nurse',
  'therapist',
  'counselor',
  'counsellor',
  'specialist',
  'coordinator',
  'manager',
  'worker',
  'navigator',
  'assistant',
  'associate',
];

export class VocabularyExtractor {
  private pool: Pool;
  private cache: Map<number, TaxonomyVocabularies> = new Map();

  constructor(pool: Pool) {
    this.pool = pool;
  }

  /**
   * Extract vocabularies from master taxonomy
   */
  async extract(taxonomyId: number): Promise<TaxonomyVocabularies> {
    // Check cache
    if (this.cache.has(taxonomyId)) {
      return this.cache.get(taxonomyId)!;
    }

    // Query hierarchy
    const result = await this.pool.query(`
      SELECT
        n.node_id,
        n.value,
        n.level,
        n.parent_node_id,
        nt.name as node_type_name
      FROM silver_taxonomies_nodes n
      JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
      WHERE n.taxonomy_id = $1
        AND n.status = 'active'
        AND n.node_type_id != -1
      ORDER BY n.level ASC
    `, [taxonomyId]);

    const nodes = result.rows;

    // Build vocabularies
    const strongHeads = this.extractStrongHeads(nodes);
    const qualifiedHeads = this.extractQualifiedHeads(nodes);
    const qualifiers = this.extractQualifiers(nodes, strongHeads);

    const vocabs: TaxonomyVocabularies = {
      strongHeads,
      qualifiedHeads,
      qualifiers,
    };

    // Cache
    this.cache.set(taxonomyId, vocabs);

    return vocabs;
  }

  /**
   * Extract strong heads (multi-word detailed occupations)
   */
  private extractStrongHeads(nodes: any[]): Set<string> {
    const strongHeads = new Set<string>();

    for (const node of nodes) {
      // Level 4-5 detailed occupations with 2+ words
      if (node.level >= 4) {
        const normalized = node.value.toLowerCase().trim();
        const wordCount = normalized.split(/\s+/).length;

        if (wordCount >= 2) {
          strongHeads.add(normalized);
        }
      }
    }

    return strongHeads;
  }

  /**
   * Extract qualified heads (generic terms)
   */
  private extractQualifiedHeads(nodes: any[]): Set<string> {
    const qualifiedHeads = new Set<string>(GENERIC_TERMS);

    // Add tails from broad/detailed occupations that contain generic terms
    for (const node of nodes) {
      if (node.level >= 3) {
        const normalized = node.value.toLowerCase().trim();
        const tokens = normalized.split(/\s+/);

        // Check if contains generic term
        for (const term of GENERIC_TERMS) {
          if (normalized.includes(term)) {
            // Add last token
            if (tokens.length > 0) {
              qualifiedHeads.add(tokens[tokens.length - 1]);
            }
            // Add last 2 tokens
            if (tokens.length >= 2) {
              qualifiedHeads.add(tokens.slice(-2).join(' '));
            }
          }
        }
      }
    }

    return qualifiedHeads;
  }

  /**
   * Extract qualifiers (industry, minor groups, prefixes)
   */
  private extractQualifiers(nodes: any[], strongHeads: Set<string>): Set<string> {
    const qualifiers = new Set<string>();

    for (const node of nodes) {
      const normalized = node.value.toLowerCase().trim();

      // Industry and major/minor groups (levels 0-3)
      if (node.level <= 3) {
        qualifiers.add(normalized);
      }

      // Prefixes before strong heads
      for (const head of strongHeads) {
        if (normalized.endsWith(head) && normalized !== head) {
          const prefix = normalized.substring(0, normalized.length - head.length).trim();
          if (prefix) {
            qualifiers.add(prefix);
          }
        }
      }
    }

    return qualifiers;
  }

  /**
   * Clear cache for specific taxonomy
   */
  clearCache(taxonomyId?: number): void {
    if (taxonomyId) {
      this.cache.delete(taxonomyId);
    } else {
      this.cache.clear();
    }
  }
}
