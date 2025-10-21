/**
 * Bronze Layer Database Repository
 * Database operations for Bronze layer tables
 */
import {
  getRepository,
  BronzeLoadDetails,
  BronzeTaxonomies,
  BronzeProfessions,
  BronzeDataSources,
  LoadDetails,
  ImportStatus,
} from '@propelus/shared';

interface CreateLoadDetailsParams {
  customerId: string;
  taxonomyId: number;
  loadDetails: LoadDetails;
  loadType: string;
}

interface CreateDataSourceParams {
  sourceType: string;
  sourceName: string;
  customerId?: number;
  filePath?: string;
  fileSizeBytes?: number;
  requestId?: string;
}

/**
 * Create comprehensive load tracking record per Data Model v0.42
 */
export async function createLoadDetailsRecord(params: CreateLoadDetailsParams): Promise<number> {
  const { customerId, taxonomyId, loadDetails, loadType } = params;

  const repository = getRepository(BronzeLoadDetails);

  const loadDetailsRecord = repository.create({
    customer_id: customerId,
    taxonomy_id: taxonomyId,
    load_details: loadDetails,
    type: loadType,
    load_date: new Date(),
  });

  const saved = await repository.save(loadDetailsRecord);
  return saved.load_id;
}

/**
 * Create a record in bronze_data_sources table (legacy support)
 */
export async function createDataSourceRecord(params: CreateDataSourceParams): Promise<number> {
  const { sourceType, sourceName, customerId, filePath, fileSizeBytes, requestId } = params;

  const repository = getRepository(BronzeDataSources);

  const dataSource = repository.create({
    customer_id: customerId || -1,
    source_type: sourceType,
    source_name: sourceName,
    file_path: filePath,
    file_size_bytes: fileSizeBytes,
    request_id: requestId,
    import_status: 'processing',
    created_at: new Date(),
  });

  const saved = await repository.save(dataSource);
  return saved.source_id;
}

/**
 * Update the status of a data source
 */
export async function updateSourceStatus(
  sourceId: number,
  status: ImportStatus,
  recordCount?: number,
  errorMessage?: string,
): Promise<void> {
  const repository = getRepository(BronzeDataSources);

  await repository.update(sourceId, {
    import_status: status,
    record_count: recordCount,
    error_message: errorMessage,
    processed_at: new Date(),
  });
}

/**
 * Store taxonomy data with enhanced load tracking per Data Model v0.42
 */
export async function storeBronzeTaxonomiesV042(
  data: Record<string, any>[],
  loadId: number,
  customerId?: number,
): Promise<void> {
  const repository = getRepository(BronzeTaxonomies);

  const records = data.map((row) => {
    const rowCustomerId = customerId || row.customer_id;
    const taxonomyId = row.taxonomy_id || 1;
    const loadType = row.update_flag ? 'updated' : 'new';

    return repository.create({
      customer_id: rowCustomerId,
      taxonomy_id: taxonomyId,
      row_json: row,
      load_date: new Date(),
      type: loadType,
      load_id: loadId,
    });
  });

  await repository.save(records);
}

/**
 * Store taxonomy data in bronze_taxonomies table (legacy support)
 */
export async function storeBronzeTaxonomies(
  data: Record<string, any>[],
  sourceId: number,
  customerId?: number,
): Promise<void> {
  const repository = getRepository(BronzeTaxonomies);

  const records = data.map((row) => {
    const rowCustomerId = customerId || row.customer_id;
    const loadType = row.update_flag ? 'updated' : 'new';

    return repository.create({
      customer_id: rowCustomerId,
      row_json: row,
      load_date: new Date(),
      type: loadType,
      // Note: load_id is optional for legacy support
    });
  });

  await repository.save(records);
}

/**
 * Store profession data in bronze_professions table
 */
export async function storeBronzeProfessions(
  data: Record<string, any>[],
  sourceId: number,
  customerId?: number,
): Promise<void> {
  const repository = getRepository(BronzeProfessions);

  const records = data.map((row) => {
    const rowCustomerId = customerId || row.customer_id;
    const loadType = row.update_flag ? 'updated' : 'new';

    return repository.create({
      customer_id: rowCustomerId,
      row_json: row,
      load_date: new Date(),
      type: loadType,
    });
  });

  await repository.save(records);
}
