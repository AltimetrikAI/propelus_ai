/**
 * API Event Processor - Corresponds to §2.1
 * Handles API payload ingestion
 *
 * NOTE: HTTP fetch not implemented - API payload should be injected via Lambda event
 * In VPC environments without NAT, outbound HTTP calls may be blocked.
 */
import { ApiEvent, ApiPayload, Layout } from '../types';
import { extractApiIds } from '../parsers/api-parser';
import { getApiLayout } from '../parsers/layout-parser';
import { normalize } from '../utils/normalization';

export interface ApiProcessorResult {
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
  taxonomyDescription?: string;
  rows: any[];
  layout: Layout;
}

/**
 * Process API event and extract all necessary data
 * Corresponds to algorithm §2.1
 *
 * IMPORTANT: This expects the API payload to be directly in the event
 * NOT fetching from external URL (to avoid VPC/NAT issues)
 */
export async function processApiEvent(event: ApiEvent & { payload?: ApiPayload }): Promise<ApiProcessorResult> {
  const { taxonomyType, payload } = event;

  // Validate payload is provided
  if (!payload) {
    throw new Error(
      'API payload must be provided in event. ' +
      'HTTP fetch not implemented to avoid VPC/NAT gateway issues. ' +
      'Inject payload via API Gateway integration or direct Lambda invocation.'
    );
  }

  // Extract IDs and rows from API payload (§2.1)
  const extracted = extractApiIds(payload);

  // Validate required fields
  if (!extracted.customerId) {
    throw new Error('API payload must contain customer_id (nested or flat)');
  }
  if (!extracted.taxonomyId) {
    throw new Error('API payload must contain taxonomy_id (nested or flat)');
  }

  // Parse layout from API payload (§2.1 - authoritative for API)
  const layout = getApiLayout(payload, taxonomyType);

  return {
    customerId: normalize(extracted.customerId),
    taxonomyId: normalize(extracted.taxonomyId),
    taxonomyName: normalize(extracted.taxonomyName || extracted.taxonomyId),
    taxonomyDescription: extracted.taxonomyDescription ? normalize(extracted.taxonomyDescription) : undefined,
    rows: extracted.rows,
    layout,
  };
}
