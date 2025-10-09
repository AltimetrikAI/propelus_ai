/**
 * Shared Constants for Propelus AI Taxonomy Framework
 *
 * These constants are used across all Lambda functions and services
 * to ensure consistency in data handling and business logic.
 */

// ============================================================================
// N/A Node Constants (Martin's Approach)
// ============================================================================

/**
 * Reserved node type ID for N/A placeholder nodes
 *
 * N/A nodes fill gaps in taxonomy hierarchies when professions skip levels.
 * Example: Level 1 → N/A (Level 2) → Level 3
 *
 * IMPORTANT:
 * - Never create N/A nodes manually
 * - Always use NANodeHandler.findOrCreateNANode()
 * - Filter N/A nodes in display queries: WHERE node_type_id != NA_NODE_TYPE_ID
 * - Include N/A nodes in LLM context for structural understanding
 */
export const NA_NODE_TYPE_ID = -1;

/**
 * Value for N/A placeholder nodes
 * This text appears in the database but should be filtered in UI displays
 */
export const NA_NODE_VALUE = 'N/A';

/**
 * Profession value for N/A placeholder nodes
 */
export const NA_PROFESSION_VALUE = 'N/A';

// ============================================================================
// Node Status Constants
// ============================================================================

export const NODE_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive'
} as const;

export type NodeStatus = typeof NODE_STATUS[keyof typeof NODE_STATUS];

// ============================================================================
// Taxonomy Type Constants
// ============================================================================

export const TAXONOMY_TYPE = {
  MASTER: 'master',
  CUSTOMER: 'customer'
} as const;

export type TaxonomyType = typeof TAXONOMY_TYPE[keyof typeof TAXONOMY_TYPE];

// ============================================================================
// Mapping Status Constants
// ============================================================================

export const MAPPING_STATUS = {
  ACTIVE: 'active',
  PENDING_REVIEW: 'pending_review',
  REJECTED: 'rejected',
  INACTIVE: 'inactive'
} as const;

export type MappingStatus = typeof MAPPING_STATUS[keyof typeof MAPPING_STATUS];

// ============================================================================
// Load Status Constants
// ============================================================================

export const LOAD_STATUS = {
  PENDING: 'pending',
  PROCESSING: 'processing',
  COMPLETED: 'completed',
  FAILED: 'failed'
} as const;

export type LoadStatus = typeof LOAD_STATUS[keyof typeof LOAD_STATUS];

// ============================================================================
// Confidence Thresholds
// ============================================================================

/**
 * Confidence score thresholds for mapping decisions
 * Based on CONFIDENCE_SCORING_AND_HUMAN_REVIEW.md
 */
export const CONFIDENCE_THRESHOLDS = {
  /** Perfect match - deterministic rules */
  PERFECT: 100,

  /** Auto-approve threshold (configurable) */
  AUTO_APPROVE: parseFloat(process.env.AUTO_APPROVAL_THRESHOLD || '90'),

  /** Human review required below this */
  HUMAN_REVIEW: parseFloat(process.env.HUMAN_REVIEW_THRESHOLD || '70'),

  /** Reject below this threshold */
  REJECTION: parseFloat(process.env.REJECTION_THRESHOLD || '60')
} as const;

// ============================================================================
// Master Taxonomy Constants
// ============================================================================

/**
 * Reserved IDs for special taxonomies
 */
export const SPECIAL_TAXONOMY_IDS = {
  /** Master taxonomy - Propelus single source of truth */
  MASTER: -1,

  /** Reserved for system use */
  SYSTEM: -999
} as const;

/**
 * Reserved customer ID for master taxonomy
 */
export const MASTER_CUSTOMER_ID = -1;

// ============================================================================
// Hierarchy Level Constants
// ============================================================================

/**
 * Standard hierarchy levels for master taxonomy
 * Note: Customer taxonomies may have different levels
 */
export const MASTER_TAXONOMY_LEVELS = {
  INDUSTRY: 1,
  PROFESSIONAL_GROUP: 2,
  OCCUPATION: 3,
  SPECIALTY: 4,
  OCCUPATION_STATUS: 5,
  PROFESSION: 6
} as const;

// ============================================================================
// Layer Constants (Bronze/Silver/Gold)
// ============================================================================

export const DATA_LAYER = {
  BRONZE: 'bronze',
  SILVER: 'silver',
  GOLD: 'gold'
} as const;

export type DataLayer = typeof DATA_LAYER[keyof typeof DATA_LAYER];

// ============================================================================
// Mapping Rule Types
// ============================================================================

export const MAPPING_RULE_TYPE = {
  EXACT: 'exact',
  REGEX: 'regex',
  FUZZY: 'fuzzy',
  AI_SEMANTIC: 'ai_semantic',
  CONTEXT: 'context'
} as const;

export type MappingRuleType = typeof MAPPING_RULE_TYPE[keyof typeof MAPPING_RULE_TYPE];

// ============================================================================
// Priority Levels for Mapping Rules
// ============================================================================

export const MAPPING_RULE_PRIORITY = {
  /** Context rules (overrides, special cases) */
  CONTEXT_RULES: { MIN: 1, MAX: 10 },

  /** Exact match rules */
  EXACT_MATCH: { MIN: 11, MAX: 30 },

  /** Pattern/Regex rules */
  PATTERN_MATCH: { MIN: 31, MAX: 50 },

  /** Fuzzy matching rules */
  FUZZY_MATCH: { MIN: 51, MAX: 80 },

  /** AI/LLM semantic matching */
  AI_SEMANTIC: { MIN: 81, MAX: 100 }
} as const;

// ============================================================================
// AWS Bedrock Configuration
// ============================================================================

export const BEDROCK_CONFIG = {
  MODEL_ID: process.env.BEDROCK_MODEL_ID || 'anthropic.claude-3-sonnet-20240229-v1:0',
  MAX_TOKENS: parseInt(process.env.BEDROCK_MAX_TOKENS || '4096'),
  TEMPERATURE: parseFloat(process.env.BEDROCK_TEMPERATURE || '0.1'),
  REGION: process.env.BEDROCK_REGION || process.env.AWS_REGION || 'us-east-1'
} as const;

// ============================================================================
// Processing Limits
// ============================================================================

export const PROCESSING_LIMITS = {
  MAX_BATCH_SIZE: parseInt(process.env.MAX_BATCH_SIZE || '1000'),
  MAX_PROCESSING_TIME_MS: parseInt(process.env.MAX_PROCESSING_TIME_MS || '1800000'), // 30 min
  MAX_RETRY_ATTEMPTS: parseInt(process.env.MAX_RETRY_ATTEMPTS || '3'),
  RETRY_BACKOFF_MS: parseInt(process.env.RETRY_BACKOFF_MS || '60000') // 1 min
} as const;

// ============================================================================
// Cache Configuration
// ============================================================================

export const CACHE_CONFIG = {
  TRANSLATION_TTL_SECONDS: parseInt(process.env.TRANSLATION_CACHE_TTL_SECONDS || '3600'), // 1 hour
  ENABLE_CACHING: process.env.ENABLE_TRANSLATION_CACHING === 'true'
} as const;

// ============================================================================
// Validation Constants
// ============================================================================

/**
 * Maximum depth of taxonomy hierarchy to prevent infinite loops
 */
export const MAX_HIERARCHY_DEPTH = 20;

/**
 * Maximum length for node values
 */
export const MAX_NODE_VALUE_LENGTH = 500;

/**
 * Maximum length for profession names
 */
export const MAX_PROFESSION_LENGTH = 1000;

// ============================================================================
// Error Codes
// ============================================================================

export const ERROR_CODES = {
  // N/A Node Errors
  NA_NODE_CREATION_FAILED: 'NA_NODE_CREATION_FAILED',
  NA_CHAIN_INVALID: 'NA_CHAIN_INVALID',

  // Hierarchy Errors
  HIERARCHY_TOO_DEEP: 'HIERARCHY_TOO_DEEP',
  PARENT_NOT_FOUND: 'PARENT_NOT_FOUND',
  CIRCULAR_REFERENCE: 'CIRCULAR_REFERENCE',

  // Mapping Errors
  MAPPING_NOT_FOUND: 'MAPPING_NOT_FOUND',
  CONFIDENCE_TOO_LOW: 'CONFIDENCE_TOO_LOW',
  AMBIGUOUS_MAPPING: 'AMBIGUOUS_MAPPING',

  // Validation Errors
  INVALID_TAXONOMY: 'INVALID_TAXONOMY',
  INVALID_NODE_TYPE: 'INVALID_NODE_TYPE',
  INVALID_LEVEL: 'INVALID_LEVEL',

  // Database Errors
  DB_CONNECTION_FAILED: 'DB_CONNECTION_FAILED',
  DB_QUERY_FAILED: 'DB_QUERY_FAILED',
  DB_TRANSACTION_FAILED: 'DB_TRANSACTION_FAILED'
} as const;

export type ErrorCode = typeof ERROR_CODES[keyof typeof ERROR_CODES];

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Check if a node type ID represents an N/A placeholder
 */
export function isNANodeType(nodeTypeId: number): boolean {
  return nodeTypeId === NA_NODE_TYPE_ID;
}

/**
 * Check if a value represents an N/A placeholder
 */
export function isNAValue(value: string): boolean {
  return value === NA_NODE_VALUE;
}

/**
 * Check if confidence score requires human review
 */
export function requiresHumanReview(confidence: number): boolean {
  return confidence < CONFIDENCE_THRESHOLDS.AUTO_APPROVE &&
         confidence >= CONFIDENCE_THRESHOLDS.REJECTION;
}

/**
 * Check if confidence score should be auto-approved
 */
export function shouldAutoApprove(confidence: number): boolean {
  return confidence >= CONFIDENCE_THRESHOLDS.AUTO_APPROVE;
}

/**
 * Check if confidence score should be rejected
 */
export function shouldReject(confidence: number): boolean {
  return confidence < CONFIDENCE_THRESHOLDS.REJECTION;
}

/**
 * Get mapping status based on confidence score
 */
export function getMappingStatusFromConfidence(confidence: number): MappingStatus {
  if (shouldAutoApprove(confidence)) {
    return MAPPING_STATUS.ACTIVE;
  } else if (requiresHumanReview(confidence)) {
    return MAPPING_STATUS.PENDING_REVIEW;
  } else {
    return MAPPING_STATUS.REJECTED;
  }
}

// ============================================================================
// Export All
// ============================================================================

export default {
  NA_NODE_TYPE_ID,
  NA_NODE_VALUE,
  NA_PROFESSION_VALUE,
  NODE_STATUS,
  TAXONOMY_TYPE,
  MAPPING_STATUS,
  LOAD_STATUS,
  CONFIDENCE_THRESHOLDS,
  SPECIAL_TAXONOMY_IDS,
  MASTER_CUSTOMER_ID,
  MASTER_TAXONOMY_LEVELS,
  DATA_LAYER,
  MAPPING_RULE_TYPE,
  MAPPING_RULE_PRIORITY,
  BEDROCK_CONFIG,
  PROCESSING_LIMITS,
  CACHE_CONFIG,
  MAX_HIERARCHY_DEPTH,
  MAX_NODE_VALUE_LENGTH,
  MAX_PROFESSION_LENGTH,
  ERROR_CODES,
  // Helper functions
  isNANodeType,
  isNAValue,
  requiresHumanReview,
  shouldAutoApprove,
  shouldReject,
  getMappingStatusFromConfidence
};
