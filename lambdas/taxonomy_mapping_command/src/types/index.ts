/**
 * Types for Taxonomy Mapping Command Lambda
 * Implements Translation Constant Command Logic Algorithm
 */

// ============================================================================
// INPUT EVENT
// ============================================================================

/**
 * Lambda input event
 */
export interface MappingCommandEvent {
  load_id: number;
  customer_id: number;
  taxonomy_id: number;
  load_type: 'new' | 'update';
  taxonomy_type: 'master' | 'customer';
}

// ============================================================================
// RULE TYPES
// ============================================================================

/**
 * Mapping rule from database
 */
export interface MappingRule {
  mapping_rule_id: number;
  name: string;
  enabled: boolean;
  pattern?: string;
  attributes?: Record<string, any>;
  flags?: Record<string, any>;
  action?: string;
  command: string;
  AI_mapping_flag: boolean;
  Human_mapping_flag: boolean;
}

/**
 * Rule assignment with priority
 */
export interface RuleAssignment {
  mapping_rule_assignment_id: number;
  mapping_rule_id: number;
  master_node_type_id: number;
  child_node_type_id: number;
  priority: number;
  enabled: boolean;
  rule: MappingRule;
}

// ============================================================================
// NODE TYPES
// ============================================================================

/**
 * Customer (child) node to be mapped
 */
export interface CustomerNode {
  node_id: number;
  node_type_id: number;
  taxonomy_id: number;
  value: string;
  profession?: string;
  level: number;
  attributes: NodeAttribute[];
}

/**
 * Master taxonomy node (candidate for matching)
 */
export interface MasterNode {
  node_id: number;
  node_type_id: number;
  value: string;
  profession?: string;
  level: number;
  parent_node_id?: number;
  attributes: NodeAttribute[];
}

/**
 * Node attribute
 */
export interface NodeAttribute {
  attribute_type_id: number;
  attribute_name: string;
  value: string;
}

// ============================================================================
// MATCHING RESULTS
// ============================================================================

/**
 * Result of matching a customer node to master
 */
export interface MatchResult {
  matched: boolean;
  master_node_id?: number;
  confidence: number;
  rule_id: number;
  method: string;
}

/**
 * Result of processing a single customer node
 */
export interface NodeProcessingResult {
  customer_node_id: number;
  match_result?: MatchResult;
  action_taken: 'created' | 'updated' | 'deactivated' | 'unchanged' | 'no_match';
  mapping_id?: number;
  error?: string;
}

// ============================================================================
// VERSIONING TYPES
// ============================================================================

/**
 * Version tracking counters
 */
export interface VersionCounters {
  total_mappings_processed: number;
  total_mappings_changed: number;
  total_mappings_unchanged: number;
  total_mappings_failed: number;
  total_mappings_new: number;
}

/**
 * Change tracking for versioning
 */
export interface TaxonomyChanges {
  nodes_added: number[];
  nodes_deleted: number[];
  attributes_added: number[];
  attributes_deleted: number[];
}

// ============================================================================
// LAMBDA RESPONSE
// ============================================================================

/**
 * Lambda response
 */
export interface MappingCommandResponse {
  success: boolean;
  load_id: number;
  customer_id: number;
  taxonomy_id: number;
  results: {
    nodes_processed: number;
    mappings_created: number;
    mappings_updated: number;
    mappings_deactivated: number;
    mappings_unchanged: number;
    failures: number;
  };
  version_id?: number;
  errors?: string[];
  processing_time_ms: number;
}

// ============================================================================
// DATABASE TYPES
// ============================================================================

/**
 * Existing mapping from database
 */
export interface ExistingMapping {
  mapping_id: number;
  master_node_id: number;
  child_node_id: number;
  confidence: number;
  status: 'active' | 'inactive';
  mapping_rule_id?: number;
}

/**
 * Mapping to insert
 */
export interface MappingInsert {
  mapping_rule_id: number;
  master_node_id: number;
  child_node_id: number;
  confidence: number;
  status: 'active' | 'inactive';
  user: string;
}

/**
 * Mapping version to insert
 */
export interface MappingVersionInsert {
  mapping_id: number;
  mapping_version_number: number;
  version_from_date: Date;
}
