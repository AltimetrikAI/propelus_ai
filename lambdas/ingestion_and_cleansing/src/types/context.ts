/**
 * Load Context - Processing State
 */

import { TaxonomyType } from './events';
import { Layout } from './layout';

/**
 * Load Type - Determines processing behavior
 */
export type LoadType = 'new' | 'updated';

/**
 * Load Context - All information needed to process a load
 */
export interface LoadContext {
  loadId: number;
  customerId: string;
  taxonomyId: string;
  taxonomyName: string;
  taxonomyType: TaxonomyType;
  loadType: LoadType;
  layout: Layout;
  rows: any[];
}

/**
 * Dictionary Cache - In-memory cache for node/attribute type IDs
 */
export interface DictionaryCache {
  nodeTypes: Map<string, number>;     // lower(name) -> node_type_id
  attrTypes: Map<string, number>;     // lower(name) -> attribute_type_id
}
