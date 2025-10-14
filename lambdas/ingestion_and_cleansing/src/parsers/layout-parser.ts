/**
 * Layout Parser (Algorithm §2.2, §4) - v1.0
 * Detects layout structure from Excel headers with explicit node levels
 */

import { normalize } from '../utils/normalization';
import { TaxonomyType } from '../types/events';
import { Layout, LayoutMaster, LayoutCustomer, NodeLevel } from '../types/layout';

/**
 * Parse Excel headers into layout structure (v1.0)
 * §4: Detect node columns with explicit levels "(node 0)", "(node 1)", etc.
 * §2.3: Detect profession column "(Profession)" - not a node, but an attribute
 * Attribute columns end with "(attribute)" or are any non-node/non-profession column
 */
export function parseExcelLayout(headers: string[], taxonomyType: TaxonomyType): Layout {
  const nodeLevels: NodeLevel[] = [];
  const attributeColumns: string[] = [];
  let professionColumn: string | null = null;

  // Process headers
  for (const header of headers) {
    const normalized = normalize(header);

    if (taxonomyType === 'master') {
      // Master taxonomy: look for (node n), (profession), and (attribute) markers

      // Check for node columns with explicit level: "(node 0)", "(node 1)", etc.
      const nodeMatch = normalized.match(/^(.+?)\s*\(node\s+(\d+)\)\s*$/i);
      if (nodeMatch) {
        const nodeName = nodeMatch[1].trim();
        const level = parseInt(nodeMatch[2], 10);
        nodeLevels.push({ level, name: nodeName });
        continue;
      }

      // Check for profession column (not a node, but stored for profession field)
      const professionMatch = normalized.match(/^(.+?)\s*\(profession\)\s*$/i);
      if (professionMatch) {
        professionColumn = professionMatch[1].trim();
        attributeColumns.push(professionColumn); // Include in attributes list
        continue;
      }

      // Check for explicit attribute markers
      const attributeMatch = normalized.match(/^(.+?)\s*\(attribute\)\s*$/i);
      if (attributeMatch) {
        const attrName = attributeMatch[1].trim();
        attributeColumns.push(attrName);
        continue;
      }

      // Any other column is implicitly an attribute
      attributeColumns.push(normalized);
    } else {
      // Customer taxonomy: look for (profession) marker
      if (/\(profession\)\s*$/i.test(normalized)) {
        professionColumn = normalized.replace(/\(profession\)\s*$/i, '').trim();
      }
    }
  }

  // Validate and return layout
  if (taxonomyType === 'master') {
    if (nodeLevels.length === 0) {
      throw new Error(
        'Master taxonomy Excel must have at least one column with format "Name (node N)" ' +
        'where N is the explicit level number (e.g., "Industry (node 0)")'
      );
    }

    if (!professionColumn) {
      throw new Error(
        'Master taxonomy Excel must have exactly one column ending with "(Profession)" ' +
        'to identify the profession string for each row'
      );
    }

    // Sort node levels by level number for consistency
    nodeLevels.sort((a, b) => a.level - b.level);

    // Extract just the node names in level order for Nodes array
    const nodeNames = nodeLevels.map(nl => nl.name);

    return {
      Nodes: nodeNames,
      Attributes: attributeColumns,
      ProfessionColumn: professionColumn,
      NodeLevels: nodeLevels,
    } as LayoutMaster;
  } else {
    if (!professionColumn) {
      throw new Error('Customer taxonomy Excel must have exactly one column ending with "(profession)"');
    }

    return {
      'Proffesion column': {
        Profession: professionColumn,
      },
    } as LayoutCustomer;
  }
}
