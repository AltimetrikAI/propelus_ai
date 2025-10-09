/**
 * AI Semantic Matcher
 *
 * Uses AWS Bedrock (Claude or Llama) for semantic matching.
 * Understands context and meaning beyond string similarity.
 */

import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';
import { Pool } from 'pg';
import { logger } from '../../../../shared/utils/logger';
import { HierarchyQueries } from '@propelus/shared';
import { SilverTaxonomiesNodes } from '../../../../shared/database/entities/silver.entity';
import { MappingDecision } from '../services/mapping-engine';

interface BedrockResponse {
  masterNodeId: number | null;
  confidence: number;
  reasoning: string;
}

export class AISemanticMatcher {
  private bedrockClient: BedrockRuntimeClient;
  private modelId: string;
  private pool: Pool;
  private hierarchyQueries: HierarchyQueries;

  constructor() {
    this.bedrockClient = new BedrockRuntimeClient({
      region: process.env.AWS_REGION || 'us-east-1',
    });
    // Use Claude 3 Sonnet by default, can be configured via env var
    this.modelId = process.env.BEDROCK_MODEL_ID || 'anthropic.claude-3-sonnet-20240229-v1:0';

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
   * Find semantic match using AI
   */
  async findMatch(
    childNode: SilverTaxonomiesNodes,
    masterNodes: SilverTaxonomiesNodes[]
  ): Promise<MappingDecision | null> {
    logger.info('Attempting AI semantic match', { childNodeId: childNode.node_id });

    try {
      // Filter master nodes to same type for better matching
      const relevantMasterNodes = masterNodes.filter(
        (node) => node.node_type_id === childNode.node_type_id
      );

      if (relevantMasterNodes.length === 0) {
        logger.warn('No relevant master nodes found for AI matching', {
          nodeTypeId: childNode.node_type_id,
        });
        return null;
      }

      // Limit to top candidates to avoid token limits
      const candidates = relevantMasterNodes.slice(0, 20);

      // Build prompt for AI with hierarchy context
      const prompt = await this.buildMatchingPrompt(childNode, candidates);

      // Call Bedrock
      const response = await this.invokeBedrockModel(prompt);

      if (response.masterNodeId && response.confidence >= 0.5) {
        logger.info('AI semantic match found', {
          childNodeId: childNode.node_id,
          masterNodeId: response.masterNodeId,
          confidence: response.confidence,
          reasoning: response.reasoning,
        });

        return {
          masterNodeId: response.masterNodeId,
          childNodeId: childNode.node_id,
          confidence: response.confidence,
          matchType: 'ai_semantic',
          ruleId: 3, // AI semantic match rule
        };
      }

      logger.info('No AI semantic match found', { childNodeId: childNode.node_id });
      return null;
    } catch (error) {
      logger.error('AI semantic matching failed', {
        childNodeId: childNode.node_id,
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Build prompt for AI matching with hierarchy context
   */
  private async buildMatchingPrompt(
    childNode: SilverTaxonomiesNodes,
    masterNodes: SilverTaxonomiesNodes[]
  ): Promise<string> {
    // Get child node hierarchy path
    const childPath = await this.hierarchyQueries.getFullPath(childNode.node_id);
    const childPathFormatted = this.hierarchyQueries.formatPathForLLM(childPath);

    // Get master node hierarchy paths
    const masterNodesWithPaths = await Promise.all(
      masterNodes.map(async (node, idx) => {
        const masterPath = await this.hierarchyQueries.getFullPath(node.node_id);
        const masterPathFormatted = this.hierarchyQueries.formatPathForLLM(masterPath);
        return `${idx + 1}. ID: ${node.node_id}
   Path: ${masterPathFormatted}
   Value: "${node.value}", Profession: "${node.profession || 'N/A'}"`;
      })
    );

    const masterNodesDescription = masterNodesWithPaths.join('\n\n');

    return `You are a healthcare profession taxonomy mapping expert. Your task is to find the best semantic match for a given profession from a list of master taxonomy nodes.

Child Node to Match:
- ID: ${childNode.node_id}
- Hierarchy Path: ${childPathFormatted}
- Value: "${childNode.value}"
- Profession: "${childNode.profession || 'N/A'}"
- Level: ${childNode.level}

Master Taxonomy Candidates:
${masterNodesDescription}

IMPORTANT NOTES:
- "[SKIP]" in paths indicates N/A placeholder levels where hierarchy gaps exist
- Focus on the SEMANTIC MEANING of non-[SKIP] values
- Consider the LEVEL STRUCTURE when matching (L1, L2, etc.)
- Healthcare professions may have abbreviations and synonyms

Instructions:
1. Analyze the semantic meaning and hierarchy context of the child node
2. Consider healthcare profession context, abbreviations, and synonyms
3. Find the best matching master node based on both value and hierarchy position
4. Provide a confidence score (0.0 - 1.0) based on semantic similarity
5. Explain your reasoning

Respond ONLY with valid JSON in this exact format:
{
  "masterNodeId": <number or null>,
  "confidence": <0.0 to 1.0>,
  "reasoning": "<brief explanation>"
}

Example:
{
  "masterNodeId": 123,
  "confidence": 0.85,
  "reasoning": "RN matches Registered Nurse with high confidence at same hierarchy level"
}`;
  }

  /**
   * Invoke Bedrock model
   */
  private async invokeBedrockModel(prompt: string): Promise<BedrockResponse> {
    try {
      // Prepare request based on model type
      const request = this.prepareModelRequest(prompt);

      const command = new InvokeModelCommand({
        modelId: this.modelId,
        contentType: 'application/json',
        accept: 'application/json',
        body: JSON.stringify(request),
      });

      const response = await this.bedrockClient.send(command);

      // Parse response
      const responseBody = JSON.parse(new TextDecoder().decode(response.body));

      return this.parseModelResponse(responseBody);
    } catch (error) {
      logger.error('Bedrock invocation failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  /**
   * Prepare request for specific model
   */
  private prepareModelRequest(prompt: string): any {
    if (this.modelId.includes('claude')) {
      // Claude model format
      return {
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 1024,
        temperature: 0.1, // Low temperature for consistent matching
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
      };
    } else if (this.modelId.includes('llama')) {
      // Llama model format
      return {
        prompt: prompt,
        max_gen_len: 512,
        temperature: 0.1,
        top_p: 0.9,
      };
    }

    // Default format
    return {
      prompt: prompt,
      max_tokens: 1024,
      temperature: 0.1,
    };
  }

  /**
   * Parse model response
   */
  private parseModelResponse(responseBody: any): BedrockResponse {
    let responseText = '';

    if (responseBody.content && Array.isArray(responseBody.content)) {
      // Claude format
      responseText = responseBody.content[0]?.text || '';
    } else if (responseBody.generation) {
      // Llama format
      responseText = responseBody.generation;
    } else if (responseBody.completions && responseBody.completions[0]) {
      // Generic format
      responseText = responseBody.completions[0].data?.text || '';
    } else {
      throw new Error('Unable to parse model response format');
    }

    // Extract JSON from response
    const jsonMatch = responseText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      logger.warn('No JSON found in AI response', { responseText });
      return {
        masterNodeId: null,
        confidence: 0,
        reasoning: 'Failed to parse AI response',
      };
    }

    try {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        masterNodeId: parsed.masterNodeId,
        confidence: parsed.confidence,
        reasoning: parsed.reasoning,
      };
    } catch (error) {
      logger.error('Failed to parse JSON from AI response', { jsonMatch: jsonMatch[0] });
      return {
        masterNodeId: null,
        confidence: 0,
        reasoning: 'Invalid JSON in AI response',
      };
    }
  }
}
