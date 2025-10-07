/**
 * Excel Parser
 * Reads Excel files from S3 and extracts data
 */

import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import * as XLSX from 'xlsx';
import { streamToBuffer } from '../utils/stream';
import { Readable } from 'stream';

export interface ExcelData {
  headers: string[];
  rows: any[];
}

/**
 * Read Excel file from S3
 */
export async function readExcelFromS3(bucket: string, key: string): Promise<ExcelData> {
  const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

  try {
    // Get object from S3
    const command = new GetObjectCommand({ Bucket: bucket, Key: key });
    const response = await s3Client.send(command);

    if (!response.Body) {
      throw new Error(`No body returned from S3 for ${bucket}/${key}`);
    }

    // Convert stream to buffer
    const buffer = await streamToBuffer(response.Body as Readable);

    // Parse Excel
    const workbook = XLSX.read(buffer, { type: 'buffer' });

    // Get first sheet
    const sheetName = workbook.SheetNames[0];
    if (!sheetName) {
      throw new Error('Excel file has no sheets');
    }

    const worksheet = workbook.Sheets[sheetName];

    // Convert to JSON with headers
    const data = XLSX.utils.sheet_to_json(worksheet, { header: 1 }) as any[][];

    if (data.length === 0) {
      throw new Error('Excel file is empty');
    }

    // Extract headers and rows
    const headers = data[0] as string[];
    const rows = data.slice(1).map((row) => {
      const obj: any = {};
      headers.forEach((header, index) => {
        obj[header] = row[index];
      });
      return obj;
    });

    return { headers, rows };
  } catch (error: any) {
    throw new Error(`Failed to read Excel from S3: ${error.message}`);
  }
}
