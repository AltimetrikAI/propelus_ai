/**
 * API Parser
 * Extracts data from API event payloads
 */

import { ApiEvent } from '../types/events';
import { Layout } from '../types/layout';

export interface ApiData {
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
  layout: Layout;
  rows: any[];
}

/**
 * Extract data from API event payload
 */
export function parseApiPayload(event: ApiEvent): ApiData {
  const { payload } = event;

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

  return {
    customerId: payload.customer_id,
    taxonomyId: payload.taxonomy_id,
    taxonomyName: payload.taxonomy_name || 'Unnamed Taxonomy',
    layout: payload.layout,
    rows: payload.rows,
  };
}
