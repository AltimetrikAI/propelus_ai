/**
 * Database Entities Index
 * Central export for all TypeORM entities
 */

// Bronze Layer
export * from './bronze.entity';

// Silver Layer
export * from './silver.entity';

// Mapping Layer
export * from './mapping.entity';

// Gold Layer
export * from './gold.entity';

// Audit Logs
export * from './audit.entity';

// Export all entities as an array for TypeORM config
import {
  BronzeLoadDetails,
  BronzeTaxonomies,
  BronzeProfessions,
  BronzeDataSources,
} from './bronze.entity';

import {
  SilverTaxonomies,
  SilverTaxonomiesNodesTypes,
  SilverTaxonomiesAttributeTypes,
  SilverTaxonomiesNodes,
  SilverTaxonomiesNodesAttributes,
  SilverTaxonomiesVersions,
  SilverProfessions,
  SilverProfessionsAttributes,
  SilverAttributeTypes,
  ProcessingLog,
} from './silver.entity';

import {
  SilverMappingTaxonomiesRulesTypes,
  SilverMappingTaxonomiesRules,
  SilverMappingTaxonomiesRulesAssigment,
  SilverMappingTaxonomies,
  SilverMappingTaxonomiesVersions,
  SilverMappingProfessionsRulesTypes,
  SilverMappingProfessionsRules,
  SilverMappingProfessionsRulesAssignment,
  SilverMappingProfessions,
  SilverContextRules,
  SilverAttributeCombinations,
  SilverTranslationPatterns,
} from './mapping.entity';

import {
  GoldMappingTaxonomies,
  GoldMappingProfessions,
  GoldMappingTaxonomiesLog,
} from './gold.entity';

import {
  SilverTaxonomiesLog,
  SilverTaxonomiesNodesTypesLog,
  SilverTaxonomiesNodesLog,
  SilverTaxonomiesNodesAttributesLog,
  SilverTaxonomiesAttributeTypesLog,
  SilverMappingTaxonomiesRulesLog,
  SilverMappingRulesAssignmentLog,
  SilverTaxonomiesVersionHistory,
  SilverRemappingLog,
  AuditLogEnhanced,
  MasterTaxonomyVersions,
  APIContracts,
} from './audit.entity';

export const entities = [
  // Bronze
  BronzeLoadDetails,
  BronzeTaxonomies,
  BronzeProfessions,
  BronzeDataSources,
  // Silver
  SilverTaxonomies,
  SilverTaxonomiesNodesTypes,
  SilverTaxonomiesAttributeTypes,
  SilverTaxonomiesNodes,
  SilverTaxonomiesNodesAttributes,
  SilverTaxonomiesVersions,
  SilverProfessions,
  SilverProfessionsAttributes,
  SilverAttributeTypes,
  ProcessingLog,
  // Mapping
  SilverMappingTaxonomiesRulesTypes,
  SilverMappingTaxonomiesRules,
  SilverMappingTaxonomiesRulesAssigment,
  SilverMappingTaxonomies,
  SilverMappingTaxonomiesVersions,
  SilverMappingProfessionsRulesTypes,
  SilverMappingProfessionsRules,
  SilverMappingProfessionsRulesAssignment,
  SilverMappingProfessions,
  SilverContextRules,
  SilverAttributeCombinations,
  SilverTranslationPatterns,
  // Gold
  GoldMappingTaxonomies,
  GoldMappingProfessions,
  GoldMappingTaxonomiesLog,
  // Audit
  SilverTaxonomiesLog,
  SilverTaxonomiesNodesTypesLog,
  SilverTaxonomiesNodesLog,
  SilverTaxonomiesNodesAttributesLog,
  SilverTaxonomiesAttributeTypesLog,
  SilverMappingTaxonomiesRulesLog,
  SilverMappingRulesAssignmentLog,
  SilverTaxonomiesVersionHistory,
  SilverRemappingLog,
  AuditLogEnhanced,
  MasterTaxonomyVersions,
  APIContracts,
];
