/**
 * Constants and Status Values
 */

/**
 * Load Status Values
 */
export const LoadStatus = {
  IN_PROGRESS: 'in progress',
  COMPLETED: 'completed',
  FAILED: 'failed',
  PARTIALLY_COMPLETED: 'partially completed',
} as const;

/**
 * Row Status Values
 */
export const RowStatus = {
  COMPLETED: 'completed',
  FAILED: 'failed',
} as const;

/**
 * Record Status Values
 */
export const RecordStatus = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
} as const;

/**
 * Master Taxonomy Identifiers
 */
export const MasterTaxonomy = {
  CUSTOMER_ID: '-1',
  TAXONOMY_ID: '-1',
} as const;
