/**
 * Mapping Rules Lambda Handler
 *
 * Applies mapping rules to match customer taxonomies to master taxonomy.
 * Uses exact matching, fuzzy matching, and AI semantic matching.
 */

import { Context, SQSEvent } from 'aws-lambda';
import { AppDataSource } from '../../../shared/database/connection';
import { logger } from '../../../shared/utils/logger';
import { MappingEngine } from './services/mapping-engine';
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge';
import { Pool } from 'pg';

interface LambdaResponse {
  statusCode: number;
  body: string;
}

let isInitialized = false;
let pool: Pool;

async function initializeDatabase(): Promise<void> {
  if (!isInitialized) {
    await AppDataSource.initialize();

    // Create PostgreSQL pool for NLP matcher
    pool = new Pool({
      host: process.env.PGHOST,
      port: parseInt(process.env.PGPORT || '5432'),
      database: process.env.PGDATABASE,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : false,
      max: 2,
    });

    // Set search_path
    pool.on('connect', async (client) => {
      try {
        await client.query(`SET search_path = ${process.env.PGSCHEMA || 'taxonomy_schema'}, public`);
      } catch (err) {
        logger.error('Error setting search_path', { error: err });
      }
    });

    isInitialized = true;
    logger.info('Database connection initialized');
  }
}

/**
 * Main Lambda handler
 * Triggered by EventBridge after Silver processing completes
 */
export async function handler(event: SQSEvent, context: Context): Promise<LambdaResponse> {
  logger.info('Mapping Rules Lambda invoked', {
    requestId: context.requestId,
    messageCount: event.Records.length,
  });

  try {
    await initializeDatabase();

    const mappingEngine = new MappingEngine(pool);
    const results = [];

    for (const record of event.Records) {
      try {
        const message = JSON.parse(record.body);
        logger.info('Processing mapping request', { messageId: record.messageId, message });

        const { customer_id, taxonomy_id, node_ids } = message;

        // Process mappings for specified nodes or all nodes
        const result = await mappingEngine.processMappings(customer_id, taxonomy_id, node_ids);

        results.push({
          messageId: record.messageId,
          customer_id,
          taxonomy_id,
          success: true,
          ...result,
        });

        // Send success event
        await sendMappingEvent('mapping.completed', {
          customer_id,
          taxonomy_id,
          ...result,
        });

        logger.info('Mapping completed successfully', { result });
      } catch (error) {
        logger.error('Error processing mapping', {
          messageId: record.messageId,
          error: error instanceof Error ? error.message : String(error),
        });

        results.push({
          messageId: record.messageId,
          success: false,
          error: error instanceof Error ? error.message : String(error),
        });

        // Send failure event
        await sendMappingEvent('mapping.failed', {
          messageId: record.messageId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Mapping processing completed',
        results,
        successCount: results.filter((r) => r.success).length,
        failedCount: results.filter((r) => !r.success).length,
      }),
    };
  } catch (error) {
    logger.error('Mapping Rules Lambda failed', {
      error: error instanceof Error ? error.message : String(error),
    });

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Mapping processing failed',
        error: error instanceof Error ? error.message : String(error),
      }),
    };
  }
}

/**
 * Send mapping events to EventBridge
 */
async function sendMappingEvent(detailType: string, detail: any): Promise<void> {
  const eventBridge = new EventBridgeClient({});

  try {
    await eventBridge.send(
      new PutEventsCommand({
        Entries: [
          {
            Source: 'propelus.taxonomy.mapping-rules',
            DetailType: detailType,
            Detail: JSON.stringify(detail),
            EventBusName: process.env.EVENT_BUS_NAME || 'default',
          },
        ],
      })
    );
  } catch (error) {
    logger.error('Failed to send EventBridge event', {
      detailType,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
