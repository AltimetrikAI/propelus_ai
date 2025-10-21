/**
 * Shared TypeScript Types and Interfaces
 */

// Lambda Event Types
export interface S3Event {
  Records: Array<{
    s3: {
      bucket: { name: string };
      object: { key: string; size?: number };
    };
  }>;
}

export interface APIGatewayEvent {
  httpMethod: string;
  body?: string;
  requestContext?: {
    requestId?: string;
  };
}

// Data Model Types
export interface LoadDetails {
  'Load Type': string;
  'Request Type': string;
  'Request ID': string;
  'Request Status': string;
  'Number Of Rows': string;
  Nodes: Record<string, any>;
  Attributes: Record<string, any>;
}

export interface BronzeIngestionResult {
  file?: string;
  load_id?: number;
  source_id?: number;
  records: number;
  status: 'success' | 'failed';
  error?: string;
}

export interface LambdaResponse {
  statusCode: number;
  body: string;
  headers?: Record<string, string>;
}

// Translation Types
export interface TranslationRequest {
  source_taxonomy: string;
  target_taxonomy: string;
  source_code: string;
  attributes?: Record<string, any>;
}

export interface TranslationResponse {
  source_code: string;
  target_codes: string[];
  confidence: number;
  method: string;
  is_ambiguous: boolean;
}

// Mapping Types
export interface MappingRule {
  mapping_rule_id: number;
  name: string;
  enabled: boolean;
  pattern?: string;
  attributes?: Record<string, any>;
  confidence: number;
}

export interface MappingResult {
  node_id: number;
  confidence: number;
  method: string;
  rule_id?: number;
}

// File Processing Types
export type FileType = 'csv' | 'json' | 'excel' | 'unknown';
export type DataType = 'taxonomy' | 'profession' | 'unknown';

// Status Types
export type ImportStatus = 'pending' | 'processing' | 'completed' | 'failed';
export type ProcessingStage =
  | 'bronze_ingestion'
  | 'silver_processing'
  | 'mapping_rules'
  | 'translation'
  | 'gold_promotion';

// Ingestion Types
export interface IngestionData {
  customer_id: string;  // Updated to string (VARCHAR 255) - v4.1.0
  taxonomy_id?: number;
  data: Record<string, any>[];
  type?: DataType;
}

// Logger Interface
export interface Logger {
  info(message: string, meta?: Record<string, any>): void;
  error(message: string, error?: Error | string, meta?: Record<string, any>): void;
  warn(message: string, meta?: Record<string, any>): void;
  debug(message: string, meta?: Record<string, any>): void;
}
