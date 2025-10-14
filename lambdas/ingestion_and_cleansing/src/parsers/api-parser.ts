/**
 * API Parser (v1.0)
 * Extracts data from API event payloads with layout validation
 */

import { ApiEvent, TaxonomyType } from '../types/events';
import { Layout, LayoutMaster } from '../types/layout';

export interface ApiData {
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
  layout: Layout;
  rows: any[];
}

/**
 * Extract data from API event payload (v1.0)
 * Validates Master taxonomy layout includes required ProfessionColumn field
 */
export function parseApiPayload(event: ApiEvent): ApiData {
  const { payload, taxonomyType } = event;

  if (!payload) {
    throw new Error('API event missing payload');
  }

  if (!payload.customer_id) {
    throw new Error('API payload missing customer_id');
  }

  if (!payload.taxonomy_id) {
    throw new Error('API payload missing taxonomy_id');
  }

  if (!payload.layout) {
    throw new Error('API payload missing layout');
  }

  if (!payload.rows || !Array.isArray(payload.rows)) {
    throw new Error('API payload missing or invalid rows');
  }

  // v1.0: Validate Master taxonomy layout structure
  if (taxonomyType === 'master') {
    validateMasterLayout(payload.layout);
  }

  return {
    customerId: payload.customer_id,
    taxonomyId: payload.taxonomy_id,
    taxonomyName: payload.taxonomy_name || 'Unnamed Taxonomy',
    layout: payload.layout,
    rows: payload.rows,
  };
}

/**
 * Validate Master taxonomy layout (v1.0)
 * §2.3.1: Master layout must include Nodes, Attributes, ProfessionColumn, and NodeLevels
 */
function validateMasterLayout(layout: any): asserts layout is LayoutMaster {
  if (!layout.Nodes || !Array.isArray(layout.Nodes)) {
    throw new Error(
      'Master taxonomy layout must include "Nodes" array. ' +
      'Example: { Nodes: ["Industry", "Group"], ... }'
    );
  }

  if (!layout.Attributes || !Array.isArray(layout.Attributes)) {
    throw new Error(
      'Master taxonomy layout must include "Attributes" array. ' +
      'Example: { Attributes: ["Taxonomy Code", "Notes"], ... }'
    );
  }

  if (!layout.ProfessionColumn || typeof layout.ProfessionColumn !== 'string') {
    throw new Error(
      'Master taxonomy layout must include "ProfessionColumn" field (v1.0 requirement). ' +
      'This field specifies the column containing the profession string for each row. ' +
      'Example: { ProfessionColumn: "Profession Name", ... }'
    );
  }

  if (!layout.NodeLevels || !Array.isArray(layout.NodeLevels)) {
    throw new Error(
      'Master taxonomy layout must include "NodeLevels" array with explicit level mappings (v1.0 requirement). ' +
      'Example: { NodeLevels: [{ level: 0, name: "Industry" }, { level: 1, name: "Group" }], ... }'
    );
  }

  // Validate each NodeLevel entry
  for (const nl of layout.NodeLevels) {
    if (typeof nl.level !== 'number') {
      throw new Error(
        `NodeLevel entry missing "level" number: ${JSON.stringify(nl)}`
      );
    }
    if (!nl.name || typeof nl.name !== 'string') {
      throw new Error(
        `NodeLevel entry missing "name" string: ${JSON.stringify(nl)}`
      );
    }
  }

  // Validate ProfessionColumn is included in Attributes list
  if (!layout.Attributes.includes(layout.ProfessionColumn)) {
    throw new Error(
      `ProfessionColumn "${layout.ProfessionColumn}" must also be present in Attributes array`
    );
  }
}
