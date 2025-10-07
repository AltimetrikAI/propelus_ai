/**
 * Filename Parser (Algorithm §2.2)
 * Extracts customer_id and taxonomy_id from S3 key
 *
 * Expected format: customer-<CID>__taxonomy-<TID>__<name>.(xlsx|xls)
 */

import { normalize } from '../utils/normalization';

export interface FilenameInfo {
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
}

/**
 * Parse customer_id and taxonomy_id from S3 key
 * §2.2: Extract from filename pattern
 */
export function parseIdsFromKey(key: string): FilenameInfo {
  // Get filename from path
  const fileName = key.split('/').pop() || key;

  // Remove extension
  const stem = fileName.replace(/\.[^.]+$/, '');

  // Match pattern: customer-<cid>__taxonomy-<tid>__<rest>
  const pattern = /customer-([^_]+)__taxonomy-([^_]+)__(.+)/i;
  const match = stem.match(pattern);

  if (!match) {
    throw new Error(
      `Filename must match pattern 'customer-<id>__taxonomy-<id>__<name>'. Got: ${fileName}`
    );
  }

  const [, customerId, taxonomyId, name] = match;

  return {
    customerId: normalize(customerId),
    taxonomyId: normalize(taxonomyId),
    taxonomyName: normalize(name),
  };
}
