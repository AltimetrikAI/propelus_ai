/**
 * Translation Lambda Handler
 *
 * Provides real-time translation between taxonomies using AI.
 * Includes caching layer for performance optimization.
 */

import { Context, APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { AppDataSource } from '../../../shared/database/connection';
import { logger } from '../../../shared/utils/logger';
import { TranslationService } from './services/translation-service';
import { CacheService } from './cache/cache-service';

interface TranslationRequest {
  source_taxonomy: string;
  target_taxonomy: string;
  source_code: string;
  attributes?: Record<string, any>;
}

let isInitialized = false;

async function initializeServices(): Promise<void> {
  if (!isInitialized) {
    await AppDataSource.initialize();
    isInitialized = true;
    logger.info('Services initialized');
  }
}

/**
 * Main Lambda handler
 * Handles API Gateway requests for translation
 */
export async function handler(
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> {
  logger.info('Translation Lambda invoked', {
    requestId: context.requestId,
    path: event.path,
    method: event.httpMethod,
  });

  try {
    await initializeServices();

    // Parse request body
    if (!event.body) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const request: TranslationRequest = JSON.parse(event.body);

    // Validate request
    const validation = validateRequest(request);
    if (!validation.valid) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: validation.error }),
      };
    }

    // Initialize services
    const cacheService = new CacheService();
    const translationService = new TranslationService(cacheService);

    // Check cache first
    const cacheKey = `translation:${request.source_taxonomy}:${request.target_taxonomy}:${request.source_code}:${JSON.stringify(request.attributes || {})}`;
    const cached = await cacheService.get(cacheKey);

    if (cached) {
      logger.info('Translation served from cache', { cacheKey });

      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...cached,
          cached: true,
        }),
      };
    }

    // Perform translation
    const result = await translationService.translate(
      request.source_taxonomy,
      request.target_taxonomy,
      request.source_code,
      request.attributes || {}
    );

    // Cache result
    await cacheService.set(cacheKey, result, 3600); // Cache for 1 hour

    logger.info('Translation completed', { result });

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...result,
        cached: false,
      }),
    };
  } catch (error) {
    logger.error('Translation Lambda failed', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });

    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'Translation failed',
        message: error instanceof Error ? error.message : String(error),
      }),
    };
  }
}

/**
 * Validate translation request
 */
function validateRequest(request: TranslationRequest): { valid: boolean; error?: string } {
  if (!request.source_taxonomy) {
    return { valid: false, error: 'source_taxonomy is required' };
  }

  if (!request.target_taxonomy) {
    return { valid: false, error: 'target_taxonomy is required' };
  }

  if (!request.source_code) {
    return { valid: false, error: 'source_code is required' };
  }

  return { valid: true };
}
