/**
 * Lambda Handler - Combined Bronze Ingestion & Silver Processing
 * Main entry point for taxonomy data ingestion and cleansing
 *
 * Runtime: Node.js 20.x / 22.x (TypeScript 5, ES2020)
 * Architecture: Single atomic transaction (Bronze → Silver)
 *
 * This Lambda ingests taxonomy data from API or S3 Excel into Aurora PostgreSQL.
 * Implements the full algorithm from §0 through §8 in a single transaction.
 */

import { LambdaEvent, S3Event, ApiEvent } from './types';
import { createDatabasePool } from './database/connection';
import { processS3Event } from './processors/s3-processor';
import { processApiEvent } from './processors/api-processor';
import { orchestrateLoad } from './processors/load-orchestrator';
import { v4 as uuidv4 } from 'uuid';

/**
 * Main Lambda Handler
 * Entry point for AWS Lambda invocation
 *
 * @param event - LambdaEvent (API or S3 source)
 * @param context - AWS Lambda Context (not used currently)
 * @returns Orchestration result with load_id and status
 */
export const handler = async (event: LambdaEvent, context?: any) => {
  // Create database connection pool (reused in warm containers)
  const pool = createDatabasePool();

  // Generate request ID for tracing
  const requestId = uuidv4();

  try {
    // Determine event source and process accordingly (§2)
    let processorResult: any;
    let sourceDetails: any;

    if (event.source === 's3') {
      // S3 Excel ingestion path (§2.2)
      const s3Event = event as S3Event;
      processorResult = await processS3Event(s3Event);
      sourceDetails = {
        "Load Type": "FILE",
        "Request Type": "GET TAXONOMY",
        "File": `${s3Event.bucket}/${s3Event.key}`,
        "Request Status": "Started"
      };
    } else if (event.source === 'api') {
      // API ingestion path (§2.1)
      const apiEvent = event as ApiEvent;
      processorResult = await processApiEvent(apiEvent as any);
      sourceDetails = {
        "Load Type": "API",
        "Request Type": "GET TAXONOMY",
        "Request ID": requestId,
        "Request Status": "Started"
      };
    } else {
      throw new Error(`Unsupported event source: ${(event as any).source}`);
    }

    // Orchestrate the full load process (§1-§8)
    const result = await orchestrateLoad(pool, {
      taxonomyType: event.taxonomyType,
      customerId: processorResult.customerId,
      taxonomyId: processorResult.taxonomyId,
      taxonomyName: processorResult.taxonomyName,
      rows: processorResult.rows,
      layout: processorResult.layout,
      sourceType: event.source,
      sourceDetails,
    });

    return result;

  } catch (error: any) {
    console.error('Lambda handler failed:', error);
    throw error; // Re-throw to mark Lambda as failed
  } finally {
    // Close database connection pool
    await pool.end();
  }
};
