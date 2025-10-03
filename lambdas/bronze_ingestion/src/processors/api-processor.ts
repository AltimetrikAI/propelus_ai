/**
 * API Event Processor
 * Handles data sent via API Gateway
 */
import { APIGatewayEvent, LambdaResponse, IngestionData } from '@propelus/shared';
import { createLogger } from '@propelus/shared';
import {
  createDataSourceRecord,
  updateSourceStatus,
  storeBronzeTaxonomies,
  storeBronzeProfessions,
} from '../database/bronze-repository';
import { triggerSilverProcessing } from '../utils/sqs-client';

const logger = createLogger({ module: 'api-processor' });

export async function processApiEvent(event: APIGatewayEvent): Promise<LambdaResponse> {
  try {
    const body: IngestionData = JSON.parse(event.body || '{}');
    const { customer_id, data, type = 'profession' } = body;

    if (!customer_id || !data || !Array.isArray(data)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing required fields: customer_id, data' }),
      };
    }

    // Create source tracking record
    const sourceId = await createDataSourceRecord({
      sourceType: 'api',
      sourceName: `API_${type}_${new Date().toISOString()}`,
      customerId: customer_id,
      requestId: event.requestContext?.requestId,
    });

    // Store in Bronze layer
    if (type === 'taxonomy') {
      await storeBronzeTaxonomies(data, sourceId, customer_id);
    } else {
      await storeBronzeProfessions(data, sourceId, customer_id);
    }

    // Update source status
    await updateSourceStatus(sourceId, 'completed', data.length);

    // Trigger Silver processing
    await triggerSilverProcessing(sourceId);

    return {
      statusCode: 200,
      body: JSON.stringify({
        source_id: sourceId,
        records_processed: data.length,
        status: 'success',
      }),
    };
  } catch (error) {
    logger.error('Error processing API event', error instanceof Error ? error : String(error));
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
    };
  }
}
