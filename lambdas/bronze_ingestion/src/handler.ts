/**
 * Bronze Layer Ingestion Lambda Handler
 * Processes raw data from S3/API into Bronze layer tables
 * Updated for Data Model v0.42 - Enhanced Load Tracking
 */
import { Context } from 'aws-lambda';
import { S3Event, APIGatewayEvent, LambdaResponse, BronzeIngestionResult } from '@propelus/shared';
import { createLogger } from '@propelus/shared';
import { processS3Event } from './processors/s3-processor';
import { processApiEvent } from './processors/api-processor';
import { initializeDatabase, closeDatabase } from '@propelus/shared';

const logger = createLogger({ service: 'bronze-ingestion' });

/**
 * Main Lambda handler for Bronze layer ingestion
 */
export async function handler(event: any, context: Context): Promise<LambdaResponse> {
  logger.info('Bronze ingestion Lambda invoked', { requestId: context.requestId });

  try {
    // Initialize database connection
    await initializeDatabase();

    // Determine event source and process accordingly
    if ('Records' in event && event.Records[0]?.s3) {
      // S3 trigger
      return await processS3Event(event as S3Event);
    } else if ('httpMethod' in event) {
      // API Gateway trigger
      return await processApiEvent(event as APIGatewayEvent);
    } else {
      // Direct invocation
      return await processDirectInvocation(event);
    }
  } catch (error) {
    logger.error('Error processing event', error instanceof Error ? error : String(error));
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
    };
  } finally {
    await closeDatabase();
  }
}

/**
 * Process direct Lambda invocation
 */
async function processDirectInvocation(event: any): Promise<LambdaResponse> {
  // Treat as API event
  return processApiEvent({
    httpMethod: 'POST',
    body: JSON.stringify(event),
  } as APIGatewayEvent);
}
