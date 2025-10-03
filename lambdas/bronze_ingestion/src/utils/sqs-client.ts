/**
 * SQS Client Utilities
 * Triggers downstream processing
 */
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { createLogger } from '@propelus/shared';

const logger = createLogger({ module: 'sqs-client' });
const sqsClient = new SQSClient({ region: process.env.AWS_REGION || 'us-east-1' });
const SILVER_PROCESSING_QUEUE = process.env.SILVER_PROCESSING_QUEUE;

/**
 * Send message to SQS to trigger Silver layer processing
 */
export async function triggerSilverProcessing(sourceId: number): Promise<void> {
  if (!SILVER_PROCESSING_QUEUE) {
    logger.warn('SQS_QUEUE_URL not configured, skipping Silver trigger');
    return;
  }

  const message = {
    source_id: sourceId,
    timestamp: new Date().toISOString(),
    action: 'process_silver',
  };

  try {
    const command = new SendMessageCommand({
      QueueUrl: SILVER_PROCESSING_QUEUE,
      MessageBody: JSON.stringify(message),
    });

    const response = await sqsClient.send(command);
    logger.info(`Triggered Silver processing for source_id ${sourceId}`, {
      messageId: response.MessageId,
    });
  } catch (error) {
    logger.error('Failed to trigger Silver processing', error instanceof Error ? error : String(error));
  }
}
