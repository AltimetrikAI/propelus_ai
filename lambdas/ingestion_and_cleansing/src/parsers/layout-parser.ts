/**
 * Layout Parser (Algorithm §2.2, §4)
 * Detects layout structure from Excel headers
 */

import { normalize } from '../utils/normalization';
import { TaxonomyType } from '../types/events';
import { Layout, LayoutMaster, LayoutCustomer } from '../types/layout';

/**
 * Parse Excel headers into layout structure
 * §4: Detect node columns (ending with "(node)") and attribute columns (ending with "(attribute)")
 * or profession column (ending with "(profession)") for customer taxonomies
 */
export function parseExcelLayout(headers: string[], taxonomyType: TaxonomyType): Layout {
  const nodeColumns: string[] = [];
  const attributeColumns: string[] = [];
  let professionColumn: string | null = null;

  // Process headers
  for (const header of headers) {
    const normalized = normalize(header);

    if (taxonomyType === 'master') {
      // Master taxonomy: look for (node) and (attribute) markers
      if (/\(node\)\s*$/i.test(normalized)) {
        const nodeName = normalized.replace(/\(node\)\s*$/i, '').trim();
        nodeColumns.push(nodeName);
      } else if (/\(attribute\)\s*$/i.test(normalized)) {
        const attrName = normalized.replace(/\(attribute\)\s*$/i, '').trim();
        attributeColumns.push(attrName);
      }
    } else {
      // Customer taxonomy: look for (profession) marker
      if (/\(profession\)\s*$/i.test(normalized)) {
        professionColumn = normalized.replace(/\(profession\)\s*$/i, '').trim();
      }
    }
  }

  // Validate and return layout
  if (taxonomyType === 'master') {
    if (nodeColumns.length === 0) {
      throw new Error('Master taxonomy Excel must have at least one column ending with "(node)"');
    }

    return {
      Nodes: nodeColumns,
      Attributes: attributeColumns,
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
