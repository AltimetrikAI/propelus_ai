/**
 * Data Classification Utilities
 * Determines data type and extracts metadata
 */
import { DataType } from '@propelus/shared';

/**
 * Determine if data is taxonomy or profession based on columns
 */
export function determineDataType(data: Record<string, any>[]): DataType {
  if (!data || data.length === 0) {
    return 'unknown';
  }

  const firstRow = data[0];
  const keys = new Set(Object.keys(firstRow));

  // Check for taxonomy indicators
  const taxonomyIndicators = ['parent_id', 'level', 'node_type', 'hierarchy'];
  const hasTaxonomyIndicators = taxonomyIndicators.some((indicator) => keys.has(indicator));

  if (hasTaxonomyIndicators) {
    return 'taxonomy';
  }

  // Check for profession indicators
  const professionIndicators = ['state', 'profession_code', 'license_type'];
  const hasProfessionIndicators = professionIndicators.some((indicator) => keys.has(indicator));

  if (hasProfessionIndicators) {
    return 'profession';
  }

  // Default to profession if unclear
  return 'profession';
}

/**
 * Extract node types from data for load details tracking
 */
export function extractNodeTypes(data: Record<string, any>[], dataType: DataType): any {
  if (dataType !== 'taxonomy' || !data || data.length === 0) {
    return {};
  }

  const sampleRow = data[0];
  const nodeTypes = new Set<string>();

  // Common taxonomy fields that indicate hierarchy levels
  const hierarchyFields = [
    'industry',
    'profession_group',
    'broad_occupation',
    'detailed_occupation',
    'occupation_specialty',
    'profession',
  ];

  for (const field of hierarchyFields) {
    const matchingKey = Object.keys(sampleRow).find(
      (key) => key.toLowerCase() === field.toLowerCase(),
    );
    if (matchingKey) {
      nodeTypes.add(field.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()));
    }
  }

  // If no clear hierarchy, assume basic profession structure
  if (nodeTypes.size === 0) {
    nodeTypes.add('Profession');
  }

  return Array.from(nodeTypes);
}

/**
 * Extract attributes from data for load details tracking
 */
export function extractAttributes(data: Record<string, any>[], dataType: DataType): any {
  if (!data || data.length === 0) {
    return {};
  }

  const sampleRow = data[0];
  const attributes: Record<string, string> = {};

  // Common attribute fields
  const attributeFields: Record<string, string> = {
    state: 'State',
    profession_abbreviation: 'Profession abbreviation',
    license_type: 'License type',
    status: 'Allowed occupation status',
    issuing_authority: 'Issuing authority',
  };

  for (const [fieldKey, fieldName] of Object.entries(attributeFields)) {
    // Check if any variation of the field exists in the data
    const matchingKey = Object.keys(sampleRow).find(
      (dataKey) => dataKey.toLowerCase().includes(fieldKey.toLowerCase()),
    );
    if (matchingKey) {
      attributes[fieldName] = matchingKey;
    }
  }

  return attributes;
}
