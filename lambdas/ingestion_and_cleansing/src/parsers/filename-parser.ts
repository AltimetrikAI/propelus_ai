/**
 * Filename Parser (Algorithm §2.1) - v2.0
 * Extracts taxonomy_type, customer_id, and taxonomy_id from S3 key
 *
 * Updated format (v2.0): (Master|Customer) <customer_id> <taxonomy_id> [optional text].xlsx
 *
 * Customer ID format (v2.0):
 *   - String format: "subsystem-clientid" (e.g., "evercheck-719")
 *   - Legacy numeric format: "123" (backward compatible)
 *
 * Examples:
 *   - "Master -1 -1.xlsx"
 *   - "Customer evercheck-719 456 Healthcare Taxonomy.xlsx"
 *   - "Customer 123 456 Healthcare Taxonomy.xlsx" (legacy)
 *   - "master 100 200.xlsx"
 *
 * Note: taxonomy_name is extracted from the Excel sheet name, not the filename
 */

import { normalize } from '../utils/normalization';
import { TaxonomyType } from '../types/events';

export interface FilenameInfo {
  taxonomyType: TaxonomyType;
  customerId: string;  // Changed from number to string (v2.0)
  taxonomyId: string;  // Changed from number to string for consistency
  // taxonomyName is extracted from sheet name, not filename
}

/**
 * Parse taxonomy metadata from S3 key (v2.0)
 * §2.1: Extract taxonomy_type, customer_id, taxonomy_id from filename
 *
 * Updated regex to support string customer_id format: "subsystem-clientid" or legacy numeric
 */
export function parseIdsFromKey(key: string): FilenameInfo {
  // Get filename from path
  const fileName = key.split('/').pop() || key;

  // Remove extension
  const stem = fileName.replace(/\.xlsx?$/i, '');

  /**
   * Pattern breakdown (v2.0):
   * - ^(?i) - start, case-insensitive
   * - (Master|Customer) - capture taxonomy type
   * - \s+ - one or more spaces
   * - ([a-z0-9]+-[a-z0-9]+|-?\d+) - capture customer_id:
   *     * New format: "subsystem-clientid" (e.g., "evercheck-719")
   *     * Legacy format: signed integer (e.g., "123" or "-1")
   * - \s+ - one or more spaces
   * - (-?\d+|[a-z0-9]+) - capture taxonomy_id (numeric or alphanumeric string)
   * - (?:\s+.+)? - optional additional text (non-capturing)
   * - $ - end
   */
  const pattern = /^(master|customer)\s+([a-z0-9]+-[a-z0-9]+|-?\d+)\s+(-?\d+|[a-z0-9]+)(?:\s+.+)?$/i;
  const match = stem.match(pattern);

  if (!match) {
    throw new Error(
      `Filename must match pattern '(Master|Customer) <customer_id> <taxonomy_id> [optional].xlsx'.\n` +
      `Customer ID formats: "subsystem-clientid" (e.g., "evercheck-719") or numeric (e.g., "123").\n` +
      `Examples: "Customer evercheck-719 456.xlsx" or "Customer 123 456 Healthcare.xlsx".\n` +
      `Got: ${fileName}`
    );
  }

  const [, taxonomyTypeRaw, customerIdStr, taxonomyIdStr] = match;

  // Parse and validate
  const taxonomyType = taxonomyTypeRaw.toLowerCase() as TaxonomyType;
  const customerId = customerIdStr;  // Keep as string
  const taxonomyId = taxonomyIdStr;  // Keep as string

  if (taxonomyType !== 'master' && taxonomyType !== 'customer') {
    throw new Error(`Invalid taxonomy type: ${taxonomyTypeRaw}. Must be 'Master' or 'Customer'.`);
  }

  // Validate customer_id format (either subsystem-clientid or numeric)
  const customerIdPattern = /^([a-z0-9]+-[a-z0-9]+|-?\d+)$/i;
  if (!customerIdPattern.test(customerId)) {
    throw new Error(
      `Invalid customer_id: ${customerId}. ` +
      `Must be format "subsystem-clientid" (e.g., "evercheck-719") or numeric (e.g., "123").`
    );
  }

  return {
    taxonomyType,
    customerId,
    taxonomyId,
  };
}
