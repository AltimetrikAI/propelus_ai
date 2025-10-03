/**
 * S3 Event Processor
 * Handles files uploaded to S3
 */
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { S3Event, LambdaResponse, BronzeIngestionResult, LoadDetails } from '@propelus/shared';
import { createLogger } from '@propelus/shared';
import { downloadS3File, determineFileType, parseFile } from '../utils/file-parser';
import { determineDataType, extractNodeTypes, extractAttributes } from '../utils/data-classifier';
import {
  createLoadDetailsRecord,
  createDataSourceRecord,
  updateSourceStatus,
  storeBronzeTaxonomiesV042,
  storeBronzeProfessions,
} from '../database/bronze-repository';
import { triggerSilverProcessing } from '../utils/sqs-client';

const logger = createLogger({ module: 's3-processor' });
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

export async function processS3Event(event: S3Event): Promise<LambdaResponse> {
  const results: BronzeIngestionResult[] = [];

  for (const record of event.Records || []) {
    const bucket = record.s3.bucket.name;
    const key = record.s3.object.key;

    logger.info('Processing S3 file', { bucket, key });

    // Create source tracking record
    const sourceId = await createDataSourceRecord({
      sourceType: 'file',
      sourceName: key,
      filePath: `s3://${bucket}/${key}`,
      fileSizeBytes: record.s3.object.size,
    });

    try {
      // Download and process file
      const fileContent = await downloadS3File(s3Client, bucket, key);
      const fileType = determineFileType(key);
      const data = await parseFile(fileContent, fileType);

      // Determine data type (taxonomy or profession)
      const dataType = determineDataType(data);

      // Create enhanced load details record (v0.42)
      const customerId = data[0]?.customer_id || -1;
      const taxonomyId = data[0]?.taxonomy_id || 1;

      const loadDetails: LoadDetails = {
        'Load Type': 'File',
        'Request Type': 'S3 FILE UPLOAD',
        'Request ID': `s3_${key}_${new Date().toISOString()}`,
        'Request Status': 'Success',
        'Number Of Rows': String(data.length),
        Nodes: extractNodeTypes(data, dataType),
        Attributes: extractAttributes(data, dataType),
      };

      const loadId = await createLoadDetailsRecord({
        customerId,
        taxonomyId,
        loadDetails,
        loadType: 'New',
      });

      // Store in Bronze layer using enhanced function
      if (dataType === 'taxonomy') {
        await storeBronzeTaxonomiesV042(data, loadId, customerId);
      } else {
        await storeBronzeProfessions(data, sourceId, customerId);
      }

      // Update source status
      await updateSourceStatus(sourceId, 'completed', data.length);

      // Trigger Silver processing
      await triggerSilverProcessing(sourceId);

      results.push({
        file: key,
        load_id: dataType === 'taxonomy' ? loadId : undefined,
        source_id: sourceId,
        records: data.length,
        status: 'success',
      });
    } catch (error) {
      logger.error(`Error processing file ${key}`, error instanceof Error ? error : String(error));
      await updateSourceStatus(sourceId, 'failed', undefined, error instanceof Error ? error.message : String(error));
      results.push({
        file: key,
        source_id: sourceId,
        records: 0,
        status: 'failed',
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ results }),
  };
}
