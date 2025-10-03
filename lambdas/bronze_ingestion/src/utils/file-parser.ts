/**
 * File Parsing Utilities
 * Handles CSV, JSON, and Excel file parsing
 */
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { parse as csvParse } from 'csv-parse/sync';
import * as XLSX from 'xlsx';
import { FileType } from '@propelus/shared';

/**
 * Download file from S3
 */
export async function downloadS3File(
  s3Client: S3Client,
  bucket: string,
  key: string,
): Promise<Buffer> {
  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const response = await s3Client.send(command);
  const chunks: Uint8Array[] = [];

  if (response.Body) {
    for await (const chunk of response.Body as any) {
      chunks.push(chunk);
    }
  }

  return Buffer.concat(chunks);
}

/**
 * Determine file type from extension
 */
export function determineFileType(filename: string): FileType {
  const ext = filename.toLowerCase().split('.').pop() || '';

  if (ext === 'csv') {
    return 'csv';
  } else if (['json', 'jsonl'].includes(ext)) {
    return 'json';
  } else if (['xls', 'xlsx'].includes(ext)) {
    return 'excel';
  } else {
    return 'unknown';
  }
}

/**
 * Parse file content based on file type
 */
export async function parseFile(
  content: Buffer,
  fileType: FileType,
): Promise<Record<string, any>[]> {
  switch (fileType) {
    case 'csv':
      return parseCsv(content);
    case 'json':
      return parseJson(content);
    case 'excel':
      return parseExcel(content);
    default:
      throw new Error(`Unsupported file type: ${fileType}`);
  }
}

/**
 * Parse CSV content
 */
function parseCsv(content: Buffer): Record<string, any>[] {
  const text = content.toString('utf-8');
  return csvParse(text, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });
}

/**
 * Parse JSON content
 */
function parseJson(content: Buffer): Record<string, any>[] {
  const text = content.toString('utf-8');

  // Handle both single JSON object and JSONL format
  if (text.trim().startsWith('[')) {
    return JSON.parse(text);
  } else {
    // JSONL format
    return text
      .trim()
      .split('\n')
      .filter((line) => line.trim())
      .map((line) => JSON.parse(line));
  }
}

/**
 * Parse Excel content
 */
function parseExcel(content: Buffer): Record<string, any>[] {
  const workbook = XLSX.read(content, { type: 'buffer' });
  const sheetName = workbook.SheetNames[0];
  const worksheet = workbook.Sheets[sheetName];

  return XLSX.utils.sheet_to_json(worksheet);
}
