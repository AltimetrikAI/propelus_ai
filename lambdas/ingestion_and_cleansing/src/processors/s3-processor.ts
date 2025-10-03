/**
 * S3 Excel Event Processor - Corresponds to §2.2
 * Handles Excel file ingestion from S3 events
 */
import { S3Event, Layout } from '../types';
import { readExcelFromS3 } from '../parsers/excel-parser';
import { parseIdsFromKey } from '../parsers/filename-parser';
import { parseExcelLayout } from '../parsers/layout-parser';

export interface S3ProcessorResult {
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
  rows: any[];
  layout: Layout;
}

/**
 * Process S3 Excel event and extract all necessary data
 * Corresponds to algorithm §2.2
 */
export async function processS3Event(event: S3Event): Promise<S3ProcessorResult> {
  const { bucket, key, taxonomyType } = event;

  // Parse customer_id and taxonomy_id from filename (§2.2)
  const ids = parseIdsFromKey(key);

  // Read Excel file from S3 (§2.2)
  const { headers, rows, sheetName } = await readExcelFromS3(bucket, key);

  // Parse layout from Excel headers based on bracket markers (§2.2)
  const layout = parseExcelLayout(headers, taxonomyType);

  // Use sheet name or file stem as taxonomy name fallback
  const taxonomyName = ids.taxonomyName || sheetName;

  return {
    customerId: ids.customerId,
    taxonomyId: ids.taxonomyId,
    taxonomyName,
    rows,
    layout,
  };
}
