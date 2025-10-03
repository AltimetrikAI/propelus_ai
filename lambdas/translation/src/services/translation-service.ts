/**
 * Translation Service
 *
 * Handles translation logic using existing mappings and AI when needed.
 */

import { AppDataSource } from '../../../../shared/database/connection';
import { logger } from '../../../../shared/utils/logger';
import {
  SilverTaxonomies,
  SilverTaxonomiesNodes,
} from '../../../../shared/database/entities/silver.entity';
import { SilverMappingTaxonomies } from '../../../../shared/database/entities/mapping.entity';
import { GoldTaxonomiesMapping } from '../../../../shared/database/entities/gold.entity';
import { CacheService } from '../cache/cache-service';
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';

export interface TranslationResult {
  source: {
    taxonomy: string;
    code: string;
    attributes?: Record<string, any>;
  };
  target: {
    taxonomy: string;
    codes: string[];
    nodes: Array<{
      nodeId: number;
      value: string;
      level: number;
      confidence: number;
    }>;
  };
  mappingMethod: 'existing' | 'ai_translation' | 'not_found';
  confidence: number;
  ambiguous: boolean;
  alternatives?: Array<{
    code: string;
    confidence: number;
  }>;
}

export class TranslationService {
  private cacheService: CacheService;
  private bedrockClient: BedrockRuntimeClient;

  constructor(cacheService: CacheService) {
    this.cacheService = cacheService;
    this.bedrockClient = new BedrockRuntimeClient({
      region: process.env.AWS_REGION || 'us-east-1',
    });
  }

  /**
   * Translate from source taxonomy to target taxonomy
   */
  async translate(
    sourceTaxonomy: string,
    targetTaxonomy: string,
    sourceCode: string,
    attributes: Record<string, any>
  ): Promise<TranslationResult> {
    logger.info('Starting translation', {
      sourceTaxonomy,
      targetTaxonomy,
      sourceCode,
      attributes,
    });

    try {
      // Get source and target taxonomies
      const source = await this.getTaxonomy(sourceTaxonomy);
      const target = await this.getTaxonomy(targetTaxonomy);

      if (!source || !target) {
        throw new Error('Source or target taxonomy not found');
      }

      // Find source node
      const sourceNode = await this.findNodeByCode(source.taxonomy_id, sourceCode, attributes);

      if (!sourceNode) {
        logger.warn('Source node not found', { sourceCode });
        return this.createNotFoundResult(sourceTaxonomy, targetTaxonomy, sourceCode, attributes);
      }

      // Try to find existing mapping
      const existingMapping = await this.findExistingMapping(
        sourceNode.node_id,
        target.taxonomy_id
      );

      if (existingMapping && existingMapping.length > 0) {
        logger.info('Using existing mapping', { mappingCount: existingMapping.length });
        return this.createResultFromMapping(
          sourceTaxonomy,
          targetTaxonomy,
          sourceCode,
          attributes,
          existingMapping,
          'existing'
        );
      }

      // Use AI for translation if no existing mapping
      logger.info('No existing mapping, using AI translation');
      const aiResult = await this.translateWithAI(sourceNode, target.taxonomy_id);

      return {
        source: {
          taxonomy: sourceTaxonomy,
          code: sourceCode,
          attributes,
        },
        target: {
          taxonomy: targetTaxonomy,
          codes: aiResult.codes,
          nodes: aiResult.nodes,
        },
        mappingMethod: 'ai_translation',
        confidence: aiResult.confidence,
        ambiguous: aiResult.ambiguous,
        alternatives: aiResult.alternatives,
      };
    } catch (error) {
      logger.error('Translation failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  /**
   * Get taxonomy by name or ID
   */
  private async getTaxonomy(taxonomyIdentifier: string): Promise<SilverTaxonomies | null> {
    const repo = AppDataSource.getRepository(SilverTaxonomies);

    // Try by taxonomy_id first
    if (/^\d+$/.test(taxonomyIdentifier)) {
      return await repo.findOne({
        where: { taxonomy_id: parseInt(taxonomyIdentifier) },
      });
    }

    // Try by name
    return await repo.findOne({
      where: { name: taxonomyIdentifier, status: 'active' },
    });
  }

  /**
   * Find node by code and attributes
   */
  private async findNodeByCode(
    taxonomyId: number,
    code: string,
    attributes: Record<string, any>
  ): Promise<SilverTaxonomiesNodes | null> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodes);

    // Try exact match first
    let node = await repo.findOne({
      where: { taxonomy_id: taxonomyId, value: code },
      relations: ['attributes'],
    });

    if (node) return node;

    // Try matching by profession
    node = await repo.findOne({
      where: { taxonomy_id: taxonomyId, profession: code },
      relations: ['attributes'],
    });

    return node;
  }

  /**
   * Find existing mapping from source to target
   */
  private async findExistingMapping(
    sourceNodeId: number,
    targetTaxonomyId: number
  ): Promise<Array<{ node: SilverTaxonomiesNodes; confidence: number }>> {
    const mappingRepo = AppDataSource.getRepository(SilverMappingTaxonomies);
    const nodeRepo = AppDataSource.getRepository(SilverTaxonomiesNodes);

    // Find mappings
    const mappings = await mappingRepo.find({
      where: { child_node_id: sourceNodeId, is_active: true, status: 'active' },
    });

    const results = [];

    for (const mapping of mappings) {
      const targetNode = await nodeRepo.findOne({
        where: { node_id: mapping.master_node_id, taxonomy_id: targetTaxonomyId },
      });

      if (targetNode) {
        results.push({
          node: targetNode,
          confidence: mapping.confidence ? parseFloat(String(mapping.confidence)) : 0.8,
        });
      }
    }

    return results;
  }

  /**
   * Translate using AI
   */
  private async translateWithAI(
    sourceNode: SilverTaxonomiesNodes,
    targetTaxonomyId: number
  ): Promise<any> {
    // Get target taxonomy nodes for context
    const targetNodes = await AppDataSource.getRepository(SilverTaxonomiesNodes).find({
      where: { taxonomy_id: targetTaxonomyId },
      take: 50, // Limit for token size
    });

    const prompt = `Translate the following healthcare profession from source taxonomy to target taxonomy:

Source Node:
- Value: ${sourceNode.value}
- Profession: ${sourceNode.profession || 'N/A'}
- Level: ${sourceNode.level}

Target Taxonomy has ${targetNodes.length} nodes including:
${targetNodes.slice(0, 10).map((n) => `- ${n.value} (Level ${n.level})`).join('\n')}

Provide the most appropriate translation(s). Respond with JSON:
{
  "codes": ["<target_code>"],
  "confidence": 0.85,
  "ambiguous": false,
  "alternatives": [{"code": "<alternative>", "confidence": 0.65}]
}`;

    const modelId = process.env.BEDROCK_MODEL_ID || 'anthropic.claude-3-sonnet-20240229-v1:0';

    const command = new InvokeModelCommand({
      modelId,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 1024,
        temperature: 0.2,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    const response = await this.bedrockClient.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    const text = responseBody.content[0]?.text || '';
    const jsonMatch = text.match(/\{[\s\S]*\}/);

    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        codes: parsed.codes || [],
        nodes: [],
        confidence: parsed.confidence || 0.5,
        ambiguous: parsed.ambiguous || false,
        alternatives: parsed.alternatives || [],
      };
    }

    return {
      codes: [],
      nodes: [],
      confidence: 0,
      ambiguous: false,
      alternatives: [],
    };
  }

  /**
   * Create result from existing mapping
   */
  private createResultFromMapping(
    sourceTaxonomy: string,
    targetTaxonomy: string,
    sourceCode: string,
    attributes: Record<string, any>,
    mappings: Array<{ node: SilverTaxonomiesNodes; confidence: number }>,
    method: 'existing' | 'ai_translation'
  ): TranslationResult {
    return {
      source: {
        taxonomy: sourceTaxonomy,
        code: sourceCode,
        attributes,
      },
      target: {
        taxonomy: targetTaxonomy,
        codes: mappings.map((m) => m.node.value),
        nodes: mappings.map((m) => ({
          nodeId: m.node.node_id,
          value: m.node.value,
          level: m.node.level,
          confidence: m.confidence,
        })),
      },
      mappingMethod: method,
      confidence: mappings[0]?.confidence || 0,
      ambiguous: mappings.length > 1,
      alternatives:
        mappings.length > 1
          ? mappings.slice(1).map((m) => ({
              code: m.node.value,
              confidence: m.confidence,
            }))
          : undefined,
    };
  }

  /**
   * Create not found result
   */
  private createNotFoundResult(
    sourceTaxonomy: string,
    targetTaxonomy: string,
    sourceCode: string,
    attributes: Record<string, any>
  ): TranslationResult {
    return {
      source: {
        taxonomy: sourceTaxonomy,
        code: sourceCode,
        attributes,
      },
      target: {
        taxonomy: targetTaxonomy,
        codes: [],
        nodes: [],
      },
      mappingMethod: 'not_found',
      confidence: 0,
      ambiguous: false,
    };
  }
}
