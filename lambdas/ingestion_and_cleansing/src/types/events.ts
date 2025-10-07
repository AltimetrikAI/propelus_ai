/**
 * Lambda Event Type Definitions
 */

export type SourceType = 's3' | 'api';
export type TaxonomyType = 'master' | 'customer';

/**
 * S3 Event - Triggered by file upload
 */
export interface S3Event {
  source: 's3';
  taxonomyType: TaxonomyType;
  bucket: string;
  key: string;  // Format: customer-<CID>__taxonomy-<TID>__<name>.xlsx
}

/**
 * API Event - Direct payload ingestion
 */
export interface ApiEvent {
  source: 'api';
  taxonomyType: TaxonomyType;
  payload: {
    customer_id: string;
    taxonomy_id: string;
    taxonomy_name: string;
    layout: any;  // LayoutMaster | LayoutCustomer
    rows: any[];
  };
}

/**
 * Union type for all Lambda events
 */
export type LambdaEvent = S3Event | ApiEvent;
