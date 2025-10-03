/**
 * Silver Processing Lambda Handler
 *
 * Processes Bronze layer data and transforms it into structured Silver layer taxonomies.
 * Applies NLP techniques, data normalization, and taxonomy structuring.
 */

import { Context, SQSEvent } from 'aws-lambda';
import { AppDataSource } from '../../../shared/database/connection';
import { logger } from '../../../shared/utils/logger';
import { BronzeTaxonomies } from '../../../shared/database/entities/bronze.entity';
import { SilverProcessor } from './processors/silver-processor';
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge';

interface LambdaResponse {
  statusCode: number;
  body: string;
}

let isInitialized = false;

async function initializeDatabase(): Promise<void> {
  if (!isInitialized) {
    await AppDataSource.initialize();
    isInitialized = true;
    logger.info('Database connection initialized');
  }
}

/**
 * Main Lambda handler
 * Triggered by SQS messages from Bronze Ingestion Lambda
 */
export async function handler(event: SQSEvent, context: Context): Promise<LambdaResponse> {
  logger.info('Silver Processing Lambda invoked', {
    requestId: context.requestId,
    messageCount: event.Records.length,
  });

  try {
    await initializeDatabase();

    const processor = new SilverProcessor();
    const results = [];

    for (const record of event.Records) {
      try {
        const message = JSON.parse(record.body);
        logger.info('Processing SQS message', { messageId: record.messageId, message });

        // Extract load_id from message
        const { load_id, customer_id, taxonomy_id } = message;

        // Process bronze records for this load
        const result = await processor.processBronzeLoad(load_id, customer_id, taxonomy_id);

        results.push({
          messageId: record.messageId,
          load_id,
          success: true,
          ...result,
        });

        // Send success event to EventBridge
        await sendProcessingEvent('silver.processing.completed', {
          load_id,
          customer_id,
          taxonomy_id,
          ...result,
        });

        logger.info('Silver processing completed successfully', { load_id, result });
      } catch (error) {
        logger.error('Error processing SQS message', {
          messageId: record.messageId,
          error: error instanceof Error ? error.message : String(error),
        });

        results.push({
          messageId: record.messageId,
          success: false,
          error: error instanceof Error ? error.message : String(error),
        });

        // Send failure event
        await sendProcessingEvent('silver.processing.failed', {
          messageId: record.messageId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Silver processing completed',
        results,
        processedCount: results.filter((r) => r.success).length,
        failedCount: results.filter((r) => !r.success).length,
      }),
    };
  } catch (error) {
    logger.error('Silver Processing Lambda failed', {
      error: error instanceof Error ? error.message : String(error),
    });

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Silver processing failed',
        error: error instanceof Error ? error.message : String(error),
      }),
    };
  }
}

/**
 * Send processing events to EventBridge for workflow orchestration
 */
async function sendProcessingEvent(detailType: string, detail: any): Promise<void> {
  const eventBridge = new EventBridgeClient({});

  try {
    await eventBridge.send(
      new PutEventsCommand({
        Entries: [
          {
            Source: 'propelus.taxonomy.silver-processing',
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
