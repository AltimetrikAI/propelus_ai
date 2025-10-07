/**
 * Stream Utilities
 * For handling S3 streams and buffers
 */

import { Readable } from 'stream';

/**
 * Convert a readable stream to a buffer
 */
export function streamToBuffer(stream: Readable): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: any[] = [];

    stream.on('data', (chunk) => chunks.push(chunk));
    stream.on('end', () => resolve(Buffer.concat(chunks)));
    stream.on('error', reject);
  });
}

/**
 * Convert buffer to string with encoding
 */
export function bufferToString(buffer: Buffer, encoding: BufferEncoding = 'utf-8'): string {
  return buffer.toString(encoding);
}
