/**
 * Bronze Layer TypeScript Types
 * Updated: January 21, 2025
 * Matches database schema after migrations 013-014, 026
 * Migration 026: customer_id changed from number to string (VARCHAR(255))
 */

/**
 * Load status enum for bronze_load_details
 */
export type LoadStatus = 'completed' | 'partially completed' | 'failed' | 'in progress';

/**
 * Load type enum
 */
export type LoadType = 'new' | 'update';

/**
 * Taxonomy type enum
 */
export type TaxonomyType = 'master' | 'customer';

/**
 * Row load status enum for bronze_taxonomies
 */
export type RowLoadStatus = 'completed' | 'in progress' | 'failed';

/**
 * bronze_load_details table interface
 * Stores a row for every data load for each taxonomy data set ingested
 */
export interface BronzeLoadDetails {
  load_id: number;
  customer_id: string;
  taxonomy_id: number;
  load_details: Record<string, any>; // JSONB
  load_date: Date;
  load_start?: Date;
  load_end?: Date;
  load_status: LoadStatus;
  load_active: boolean;
  load_type: LoadType;
  taxonomy_type: TaxonomyType;
}

/**
 * bronze_taxonomies table interface
 * Raw ingestion of taxonomy data set per customer (row by row)
 */
export interface BronzeTaxonomies {
  row_id: number;
  load_id: number;
  customer_id: string;
  taxonomy_id: number;
  row_json: Record<string, any>; // JSON
  load_date?: Date;
  row_load_status: RowLoadStatus;
  row_active: boolean;
}

/**
 * Insert payload for bronze_load_details (fields with defaults omitted)
 */
export interface BronzeLoadDetailsInsert {
  customer_id: string;
  taxonomy_id: number;
  load_details: Record<string, any>;
  load_start?: Date;
  load_type: LoadType;
  taxonomy_type: TaxonomyType;
  load_status?: LoadStatus; // defaults to 'in progress'
  load_active?: boolean; // defaults to true
}

/**
 * Insert payload for bronze_taxonomies
 */
export interface BronzeTaxonomiesInsert {
  load_id: number;
  customer_id: string;
  taxonomy_id: number;
  row_json: Record<string, any>;
  row_load_status?: RowLoadStatus; // defaults to 'in progress'
  row_active?: boolean; // defaults to true
}

/**
 * Update payload for bronze_load_details
 */
export interface BronzeLoadDetailsUpdate {
  load_end?: Date;
  load_status?: LoadStatus;
  load_active?: boolean;
  load_details?: Record<string, any>;
}

/**
 * Update payload for bronze_taxonomies
 */
export interface BronzeTaxonomiesUpdate {
  row_load_status?: RowLoadStatus;
  row_active?: boolean;
}

/**
 * Query filter for bronze_load_details
 */
export interface BronzeLoadDetailsFilter {
  load_id?: number;
  customer_id?: string;
  taxonomy_id?: number;
  load_status?: LoadStatus;
  load_active?: boolean;
  load_type?: LoadType;
  taxonomy_type?: TaxonomyType;
  load_date_from?: Date;
  load_date_to?: Date;
}

/**
 * Query filter for bronze_taxonomies
 */
export interface BronzeTaxonomiesFilter {
  row_id?: number;
  load_id?: number;
  customer_id?: string;
  taxonomy_id?: number;
  row_load_status?: RowLoadStatus;
  row_active?: boolean;
}
