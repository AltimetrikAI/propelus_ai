/**
 * Translation Service
 *
 * Handles translation logic using existing mappings and AI when needed.
 */

import { Pool } from 'pg';
import { AppDataSource } from '../../../../shared/database/connection';
import { logger } from '../../../../shared/utils/logger';
import { HierarchyQueries, NA_NODE_TYPE_ID } from '@propelus/shared';
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
    path?: string;  // Display path (N/A filtered)
    attributes?: Record<string, any>;
  };
  target: {
    taxonomy: string;
    codes: string[];
    nodes: Array<{
      nodeId: number;
      value: string;
      path: string;  // Display path (N/A filtered)
      level: number;
      confidence: number;
    }>;
  };
  mappingMethod: 'existing' | 'ai_translation' | 'not_found';
  confidence: number;
  ambiguous: boolean;
  alternatives?: Array<{
    code: string;
    path: string;  // Display path (N/A filtered)
    confidence: number;
  }>;
}

export class TranslationService {
  private cacheService: CacheService;
  private bedrockClient: BedrockRuntimeClient;
  private pool: Pool;
  private hierarchyQueries: HierarchyQueries;

  constructor(cacheService: CacheService) {
    this.cacheService = cacheService;
    this.bedrockClient = new BedrockRuntimeClient({
      region: process.env.AWS_REGION || 'us-east-1',
    });

    // Initialize database pool for hierarchy queries
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'propelus_taxonomy',
      user: process.env.DB_USER || 'propelus_admin',
      password: process.env.DB_PASSWORD,
    });

    this.hierarchyQueries = new HierarchyQueries(this.pool);
  }

  /**
   * Cleanup database connections (call when Lambda is shutting down)
   */
  async cleanup(): Promise<void> {
    await this.pool.end();
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
        return await this.createResultFromMapping(
          sourceTaxonomy,
          targetTaxonomy,
          sourceCode,
          attributes,
          sourceNode,
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
   * Find node by code and attributes (excluding N/A placeholders)
   */
  private async findNodeByCode(
    taxonomyId: number,
    code: string,
    attributes: Record<string, any>
  ): Promise<SilverTaxonomiesNodes | null> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodes);

    // Try exact match first (exclude N/A nodes)
    let node = await repo
      .createQueryBuilder('node')
      .where('node.taxonomy_id = :taxonomyId', { taxonomyId })
      .andWhere('node.value = :code', { code })
      .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
      .leftJoinAndSelect('node.attributes', 'attributes')
      .getOne();

    if (node) return node;

    // Try matching by profession (exclude N/A nodes)
    node = await repo
      .createQueryBuilder('node')
      .where('node.taxonomy_id = :taxonomyId', { taxonomyId })
      .andWhere('node.profession = :code', { code })
      .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
      .leftJoinAndSelect('node.attributes', 'attributes')
      .getOne();

    return node;
  }

  /**
   * Find existing mapping from source to target (excluding N/A placeholders)
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
      // Exclude N/A placeholder nodes from translation results
      const targetNode = await nodeRepo
        .createQueryBuilder('node')
        .where('node.node_id = :nodeId', { nodeId: mapping.master_node_id })
        .andWhere('node.taxonomy_id = :taxonomyId', { taxonomyId: targetTaxonomyId })
        .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
        .getOne();

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
   * Translate using AI with hierarchy context
   */
  private async translateWithAI(
    sourceNode: SilverTaxonomiesNodes,
    targetTaxonomyId: number
  ): Promise<any> {
    // Get source node hierarchy path
    const sourcePath = await this.hierarchyQueries.getFullPath(sourceNode.node_id);
    const sourcePathFormatted = this.hierarchyQueries.formatPathForLLM(sourcePath);

    // Get target taxonomy nodes for context (exclude N/A placeholders)
    const targetNodes = await AppDataSource.getRepository(SilverTaxonomiesNodes)
      .createQueryBuilder('node')
      .where('node.taxonomy_id = :taxonomyId', { taxonomyId: targetTaxonomyId })
      .andWhere('node.node_type_id != :naNodeTypeId', { naNodeTypeId: NA_NODE_TYPE_ID })
      .take(50) // Limit for token size
      .getMany();

    // Get hierarchy paths for sample target nodes
    const targetSamples = await Promise.all(
      targetNodes.slice(0, 10).map(async (node) => {
        const path = await this.hierarchyQueries.getFullPath(node.node_id);
        const pathFormatted = this.hierarchyQueries.formatPathForLLM(path);
        return `- Path: ${pathFormatted}\n  Value: ${node.value} (Level ${node.level})`;
      })
    );

    const prompt = `Translate the following healthcare profession from source taxonomy to target taxonomy:

Source Node:
- Hierarchy Path: ${sourcePathFormatted}
- Value: ${sourceNode.value}
- Profession: ${sourceNode.profession || 'N/A'}
- Level: ${sourceNode.level}

Target Taxonomy has ${targetNodes.length} active nodes. Sample nodes:
${targetSamples.join('\n\n')}

IMPORTANT NOTES:
- "[SKIP]" in paths indicates N/A placeholder levels where hierarchy gaps exist
- Focus on the SEMANTIC MEANING of non-[SKIP] values
- Consider the LEVEL STRUCTURE when matching (L1, L2, etc.)

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
   * Create result from existing mapping with display paths
   */
  private async createResultFromMapping(
    sourceTaxonomy: string,
    targetTaxonomy: string,
    sourceCode: string,
    attributes: Record<string, any>,
    sourceNode: SilverTaxonomiesNodes,
    mappings: Array<{ node: SilverTaxonomiesNodes; confidence: number }>,
    method: 'existing' | 'ai_translation'
  ): Promise<TranslationResult> {
    // Get source display path (N/A filtered)
    const sourcePath = await this.hierarchyQueries.getDisplayPath(sourceNode.node_id);

    // Get target display paths for all mappings
    const nodesWithPaths = await Promise.all(
      mappings.map(async (m) => ({
        nodeId: m.node.node_id,
        value: m.node.value,
        path: await this.hierarchyQueries.getDisplayPath(m.node.node_id),
        level: m.node.level,
        confidence: m.confidence,
      }))
    );

    // Get alternatives with paths
    const alternatives = mappings.length > 1
      ? await Promise.all(
          mappings.slice(1).map(async (m) => ({
            code: m.node.value,
            path: await this.hierarchyQueries.getDisplayPath(m.node.node_id),
            confidence: m.confidence,
          }))
        )
      : undefined;

    return {
      source: {
        taxonomy: sourceTaxonomy,
        code: sourceCode,
        path: sourcePath,
        attributes,
      },
      target: {
        taxonomy: targetTaxonomy,
        codes: mappings.map((m) => m.node.value),
        nodes: nodesWithPaths,
      },
      mappingMethod: method,
      confidence: mappings[0]?.confidence || 0,
      ambiguous: mappings.length > 1,
      alternatives,
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
