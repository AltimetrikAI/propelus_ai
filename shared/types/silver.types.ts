/**
 * Silver Layer TypeScript Types
 * Updated: January 21, 2025
 * Matches database schema after migrations 015-023, 026
 * Migration 026: customer_id changed from number to string (VARCHAR(255))
 */

/**
 * Common status enum for Silver layer tables
 */
export type SilverStatus = 'active' | 'inactive';

/**
 * Remapping process status enum
 */
export type RemappingProcessStatus = 'in progress' | 'completed' | 'failed' | null;

// ============================================================================
// TAXONOMIES
// ============================================================================

/**
 * silver_taxonomies table interface
 */
export interface SilverTaxonomy {
  taxonomy_id: number;
  customer_id: string;
  name: string;
  description?: string;
  type: 'master' | 'customer';
  status: SilverStatus;
  created_at: Date;
  last_updated_at: Date;
  load_id?: number;
}

/**
 * silver_taxonomies_nodes_types table interface
 */
export interface SilverTaxonomyNodeType {
  node_type_id: number;
  name: string;
  status: SilverStatus;
  level?: number;
  created_at: Date;
  last_updated_at: Date;
  load_id?: number;
}

/**
 * silver_taxonomies_nodes table interface
 */
export interface SilverTaxonomyNode {
  node_id: number;
  node_type_id: number;
  taxonomy_id: number;
  parent_node_id?: number;
  value: string;
  profession?: string;
  level: number;
  status: SilverStatus;
  created_at: Date;
  last_updated_at: Date;
  load_id?: number;
  row_id?: number;
}

/**
 * silver_taxonomies_attribute_types table interface
 */
export interface SilverTaxonomyAttributeType {
  attribute_type_id: number;
  name: string;
  status: SilverStatus;
  created_at: Date;
  last_updated_at: Date;
  load_id?: number;
}

/**
 * silver_taxonomies_nodes_attributes table interface
 */
export interface SilverTaxonomyNodeAttribute {
  node_attribute_type_id: number;
  attribute_type_id: number;
  node_id: number;
  value: string;
  status: SilverStatus;
  created_at: Date;
  last_updated_at: Date;
  load_id?: number;
  row_id?: number;
}

// ============================================================================
// VERSIONING
// ============================================================================

/**
 * silver_taxonomies_versions table interface
 */
export interface SilverTaxonomyVersion {
  taxonomy_version_id: number;
  taxonomy_id: number;
  taxonomy_version_number: number;
  change_type?: string;
  affected_nodes?: Record<string, any>; // JSONB
  affected_attributes?: Record<string, any>; // JSONB
  remapping_flag: boolean;
  remapping_reason?: string;
  total_mappings_processed: number;
  total_mappings_changed: number;
  total_mappings_unchanged: number;
  total_mappings_failed: number;
  total_mappings_new: number;
  remapping_proces_status?: RemappingProcessStatus;
  version_notes?: string;
  version_from_date: Date;
  version_to_date?: Date;
  created_at: Date;
  last_updated_at: Date;
  load_id?: number;
}

/**
 * silver_mapping_taxonomies_versions table interface
 */
export interface SilverMappingTaxonomyVersion {
  mapping_version_id: number;
  mapping_id: number;
  mapping_version_number: number;
  version_from_date: Date;
  version_to_date?: Date;
  superseded_by_mapping_id?: number;
  superseded_at?: Date;
  created_at: Date;
  last_updated_at: Date;
}

// ============================================================================
// MAPPING RULES
// ============================================================================

/**
 * silver_mapping_taxonomies_rules table interface
 */
export interface SilverMappingTaxonomyRule {
  mapping_rule_id: number;
  mapping_rule_type_id?: number;
  name: string;
  enabled: boolean;
  pattern?: string;
  attributes?: Record<string, any>; // JSONB
  flags?: Record<string, any>; // JSONB
  action?: string;
  command?: string;
  AI_mapping_flag: boolean;
  Human_mapping_flag: boolean;
  created_at: Date;
  last_updated_at: Date;
}

/**
 * silver_mapping_taxonomies_rules_assignment table interface
 */
export interface SilverMappingTaxonomyRuleAssignment {
  mapping_rule_assignment_id: number;
  mapping_rule_id: number;
  master_node_type_id: number;
  node_type_id: number; // child node type
  priority: number;
  enabled: boolean;
  created_at: Date;
  last_updated_at: Date;
}

/**
 * silver_mapping_taxonomies table interface
 */
export interface SilverMappingTaxonomy {
  mapping_id: number;
  mapping_rule_id?: number;
  master_node_id: number;
  node_id: number; // child node id
  confidence: number;
  status: SilverStatus;
  user?: string;
  created_at: Date;
  last_updated_at: Date;
}

// ============================================================================
// INSERT PAYLOADS
// ============================================================================

export interface SilverTaxonomyNodeInsert {
  node_type_id: number;
  taxonomy_id: number;
  parent_node_id?: number;
  value: string;
  profession?: string;
  level: number;
  status?: SilverStatus;
  load_id?: number;
  row_id?: number;
}

export interface SilverTaxonomyNodeAttributeInsert {
  attribute_type_id: number;
  node_id: number;
  value: string;
  status?: SilverStatus;
  load_id?: number;
  row_id?: number;
}

export interface SilverTaxonomyVersionInsert {
  taxonomy_id: number;
  taxonomy_version_number: number;
  change_type?: string;
  affected_nodes?: Record<string, any>;
  affected_attributes?: Record<string, any>;
  remapping_flag?: boolean;
  remapping_reason?: string;
  version_notes?: string;
  load_id?: number;
}

export interface SilverMappingTaxonomyInsert {
  mapping_rule_id?: number;
  master_node_id: number;
  node_id: number;
  confidence: number;
  status?: SilverStatus;
  user?: string;
}

export interface SilverMappingTaxonomyVersionInsert {
  mapping_id: number;
  mapping_version_number: number;
  superseded_by_mapping_id?: number;
  superseded_at?: Date;
}

// ============================================================================
// UPDATE PAYLOADS
// ============================================================================

export interface SilverTaxonomyVersionUpdate {
  remapping_flag?: boolean;
  remapping_reason?: string;
  total_mappings_processed?: number;
  total_mappings_changed?: number;
  total_mappings_unchanged?: number;
  total_mappings_failed?: number;
  total_mappings_new?: number;
  remapping_proces_status?: RemappingProcessStatus;
  version_notes?: string;
  version_to_date?: Date;
}

export interface SilverMappingTaxonomyUpdate {
  status?: SilverStatus;
  user?: string;
  confidence?: number;
}

export interface SilverMappingTaxonomyVersionUpdate {
  version_to_date?: Date;
  superseded_by_mapping_id?: number;
  superseded_at?: Date;
}

// ============================================================================
// QUERY FILTERS
// ============================================================================

export interface SilverTaxonomyNodeFilter {
  node_id?: number;
  taxonomy_id?: number;
  node_type_id?: number;
  parent_node_id?: number;
  level?: number;
  status?: SilverStatus;
  profession?: string;
}

export interface SilverMappingTaxonomyFilter {
  mapping_id?: number;
  master_node_id?: number;
  node_id?: number;
  status?: SilverStatus;
  confidence_min?: number;
  confidence_max?: number;
  rule_id?: number;
}

export interface SilverTaxonomyVersionFilter {
  taxonomy_id?: number;
  version_number?: number;
  is_current?: boolean; // version_to_date IS NULL
  remapping_flag?: boolean;
}
