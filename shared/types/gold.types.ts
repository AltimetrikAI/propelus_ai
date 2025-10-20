/**
 * Gold Layer TypeScript Types
 * Updated: January 26, 2025
 * Matches database schema after migration 024
 */

// ============================================================================
// GOLD MAPPING TAXONOMIES
// ============================================================================

/**
 * gold_mapping_taxonomies table interface
 * Final approved mappings between taxonomies
 * Contains only active, non-AI mappings mirrored from silver_mapping_taxonomies
 */
export interface GoldMappingTaxonomy {
  mapping_id: number;
  master_node_id: number;
  child_node_id: number;
  created_at: Date;
  last_updated_at: Date;
}

/**
 * Insert payload for gold_mapping_taxonomies
 */
export interface GoldMappingTaxonomyInsert {
  mapping_id: number;
  master_node_id: number;
  child_node_id: number;
}

/**
 * Query filter for gold_mapping_taxonomies
 */
export interface GoldMappingTaxonomyFilter {
  mapping_id?: number;
  master_node_id?: number;
  child_node_id?: number;
  created_after?: Date;
  updated_after?: Date;
}

// ============================================================================
// SYNC OPERATIONS
// ============================================================================

/**
 * Result of gold sync operation
 */
export interface GoldSyncResult {
  inserted_count: number;
  deleted_count: number;
  sync_summary: string;
}

/**
 * Gold sync candidate (view: v_gold_sync_candidates)
 */
export interface GoldSyncCandidate {
  mapping_id: number;
  master_node_id: number;
  child_node_id: number;
  confidence: number;
  status: string;
  user?: string;
  AI_mapping_flag: boolean;
  Human_mapping_flag: boolean;
  sync_status: 'missing_in_gold' | 'exists_in_gold';
}

/**
 * Orphaned gold mapping (view: v_gold_orphaned_mappings)
 */
export interface GoldOrphanedMapping {
  mapping_id: number;
  master_node_id: number;
  child_node_id: number;
  created_at: Date;
  last_updated_at: Date;
  orphan_reason: 'missing_in_silver' | 'inactive_in_silver' | 'ai_mapping_in_silver' | 'other';
}

// ============================================================================
// BATCH OPERATIONS
// ============================================================================

/**
 * Batch upsert payload for gold mappings
 */
export interface GoldMappingBatchUpsert {
  mappings: GoldMappingTaxonomyInsert[];
}

/**
 * Batch delete payload for gold mappings
 */
export interface GoldMappingBatchDelete {
  mapping_ids: number[];
}

/**
 * Result of batch operation
 */
export interface GoldBatchOperationResult {
  successful: number;
  failed: number;
  errors?: Array<{
    mapping_id: number;
    error: string;
  }>;
}
