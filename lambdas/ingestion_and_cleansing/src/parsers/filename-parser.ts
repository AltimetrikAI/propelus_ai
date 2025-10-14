/**
 * Filename Parser (Algorithm §2.1) - v1.0
 * Extracts taxonomy_type, customer_id, and taxonomy_id from S3 key
 *
 * New format (v1.0): (Master|Customer) <customer_id> <taxonomy_id> [optional text].xlsx
 * Examples:
 *   - "Master -1 -1.xlsx"
 *   - "Customer 123 456 Healthcare Taxonomy.xlsx"
 *   - "master 100 200.xlsx"
 *
 * Note: taxonomy_name is extracted from the Excel sheet name, not the filename
 */

import { normalize } from '../utils/normalization';
import { TaxonomyType } from '../types/events';

export interface FilenameInfo {
  taxonomyType: TaxonomyType;
  customerId: number;
  taxonomyId: number;
  // taxonomyName is extracted from sheet name, not filename
}

/**
 * Parse taxonomy metadata from S3 key (v1.0)
 * §2.1: Extract taxonomy_type, customer_id, taxonomy_id from filename
 * Regex: ^(?i)(Master|Customer)\s+(-?\d+)\s+(-?\d+)(?:\s+.+)?(?:\.xlsx)?$
 */
export function parseIdsFromKey(key: string): FilenameInfo {
  // Get filename from path
  const fileName = key.split('/').pop() || key;

  // Remove extension
  const stem = fileName.replace(/\.xlsx?$/i, '');

  /**
   * Pattern breakdown:
   * - ^(?i) - start, case-insensitive
   * - (Master|Customer) - capture taxonomy type
   * - \s+ - one or more spaces
   * - (-?\d+) - capture customer_id (signed integer)
   * - \s+ - one or more spaces
   * - (-?\d+) - capture taxonomy_id (signed integer)
   * - (?:\s+.+)? - optional additional text (non-capturing)
   * - $ - end
   */
  const pattern = /^(master|customer)\s+(-?\d+)\s+(-?\d+)(?:\s+.+)?$/i;
  const match = stem.match(pattern);

  if (!match) {
    throw new Error(
      `Filename must match pattern '(Master|Customer) <customer_id> <taxonomy_id> [optional].xlsx'.\n` +
      `Examples: "Master -1 -1.xlsx" or "Customer 123 456 Healthcare.xlsx".\n` +
      `Got: ${fileName}`
    );
  }

  const [, taxonomyTypeRaw, customerIdStr, taxonomyIdStr] = match;

  // Parse and validate
  const taxonomyType = taxonomyTypeRaw.toLowerCase() as TaxonomyType;
  const customerId = parseInt(customerIdStr, 10);
  const taxonomyId = parseInt(taxonomyIdStr, 10);

  if (taxonomyType !== 'master' && taxonomyType !== 'customer') {
    throw new Error(`Invalid taxonomy type: ${taxonomyTypeRaw}. Must be 'Master' or 'Customer'.`);
  }

  if (isNaN(customerId)) {
    throw new Error(`Invalid customer_id: ${customerIdStr}. Must be an integer.`);
  }

  if (isNaN(taxonomyId)) {
    throw new Error(`Invalid taxonomy_id: ${taxonomyIdStr}. Must be an integer.`);
  }

  return {
    taxonomyType,
    customerId,
    taxonomyId,
  };
}
