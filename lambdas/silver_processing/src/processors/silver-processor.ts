/**
 * Silver Processor
 *
 * Core business logic for transforming Bronze data into structured Silver taxonomies.
 * Handles data normalization, NLP processing, and taxonomy structuring.
 */

import { AppDataSource } from '../../../../shared/database/connection';
import { logger } from '../../../../shared/utils/logger';
import { BronzeTaxonomies, BronzeLoadDetails } from '../../../../shared/database/entities/bronze.entity';
import {
  SilverTaxonomies,
  SilverTaxonomiesNodes,
  SilverTaxonomiesNodesAttributes,
  SilverProfessions,
  SilverProfessionsAttributes,
} from '../../../../shared/database/entities/silver.entity';
import { ProcessingLog } from '../../../../shared/database/entities/silver.entity';
import { NLPService } from '../services/nlp-service';
import { TaxonomyStructurer } from '../services/taxonomy-structurer';

export interface ProcessingResult {
  taxonomiesProcessed: number;
  nodesCreated: number;
  professionsCreated: number;
  errors: string[];
}

export class SilverProcessor {
  private nlpService: NLPService;
  private taxonomyStructurer: TaxonomyStructurer;

  constructor() {
    this.nlpService = new NLPService();
    this.taxonomyStructurer = new TaxonomyStructurer();
  }

  /**
   * Process bronze load and create silver layer data
   */
  async processBronzeLoad(
    loadId: number,
    customerId: string,
    taxonomyId: number
  ): Promise<ProcessingResult> {
    const startTime = Date.now();
    const result: ProcessingResult = {
      taxonomiesProcessed: 0,
      nodesCreated: 0,
      professionsCreated: 0,
      errors: [],
    };

    try {
      logger.info('Starting silver processing', { loadId, customerId, taxonomyId });

      // Create processing log entry
      const processingLog = await this.createProcessingLog(loadId, 'silver_processing', 'started');

      // Get bronze records for this load
      const bronzeRecords = await AppDataSource.getRepository(BronzeTaxonomies).find({
        where: { load_id: loadId, customer_id: customerId },
      });

      logger.info(`Found ${bronzeRecords.length} bronze records to process`);

      // Get or create Silver taxonomy
      const silverTaxonomy = await this.getOrCreateSilverTaxonomy(customerId, taxonomyId);

      for (const bronzeRecord of bronzeRecords) {
        try {
          // Process each bronze record
          await this.processBronzeRecord(bronzeRecord, silverTaxonomy, result);
        } catch (error) {
          const errorMsg = `Failed to process bronze record ${bronzeRecord.id}: ${
            error instanceof Error ? error.message : String(error)
          }`;
          logger.error(errorMsg);
          result.errors.push(errorMsg);
        }
      }

      // Update processing log
      const processingTime = Date.now() - startTime;
      await this.updateProcessingLog(
        processingLog.log_id,
        'completed',
        bronzeRecords.length,
        result.errors.length,
        processingTime
      );

      logger.info('Silver processing completed', {
        loadId,
        processingTimeMs: processingTime,
        result,
      });

      return result;
    } catch (error) {
      logger.error('Silver processing failed', {
        loadId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  /**
   * Process individual bronze record
   */
  private async processBronzeRecord(
    bronzeRecord: BronzeTaxonomies,
    silverTaxonomy: SilverTaxonomies,
    result: ProcessingResult
  ): Promise<void> {
    const rowData = bronzeRecord.row_json;

    // Extract profession information using NLP
    const professionInfo = this.nlpService.extractProfessionInfo(rowData);

    // Create or update profession record
    const profession = await this.createOrUpdateProfession(
      bronzeRecord.customer_id,
      professionInfo.name,
      professionInfo.attributes
    );
    result.professionsCreated++;

    // Structure data into taxonomy nodes
    const nodes = await this.taxonomyStructurer.structureData(
      rowData,
      silverTaxonomy,
      professionInfo
    );

    result.nodesCreated += nodes.length;
    result.taxonomiesProcessed++;
  }

  /**
   * Get existing or create new Silver taxonomy
   */
  private async getOrCreateSilverTaxonomy(
    customerId: string,
    taxonomyId: number
  ): Promise<SilverTaxonomies> {
    const repo = AppDataSource.getRepository(SilverTaxonomies);

    let taxonomy = await repo.findOne({
      where: { taxonomy_id: taxonomyId, customer_id: customerId },
    });

    if (!taxonomy) {
      taxonomy = repo.create({
        customer_id: customerId,
        name: `Customer ${customerId} Taxonomy`,
        type: 'customer',
        status: 'active',
        taxonomy_version: 1,
      });
      await repo.save(taxonomy);
      logger.info('Created new Silver taxonomy', { taxonomyId: taxonomy.taxonomy_id });
    }

    return taxonomy;
  }

  /**
   * Create or update profession record
   */
  private async createOrUpdateProfession(
    customerId: string,
    professionName: string,
    attributes: Record<string, any>
  ): Promise<SilverProfessions> {
    const repo = AppDataSource.getRepository(SilverProfessions);

    // Check if profession exists
    let profession = await repo.findOne({
      where: { customer_id: customerId, name: professionName },
    });

    if (!profession) {
      // Create new profession
      profession = repo.create({
        customer_id: customerId,
        name: professionName,
      });
      await repo.save(profession);
      logger.info('Created new profession', { professionId: profession.profession_id, name: professionName });
    }

    // Update profession attributes
    await this.updateProfessionAttributes(profession.profession_id, attributes);

    return profession;
  }

  /**
   * Update profession attributes
   */
  private async updateProfessionAttributes(
    professionId: number,
    attributes: Record<string, any>
  ): Promise<void> {
    const repo = AppDataSource.getRepository(SilverProfessionsAttributes);

    for (const [name, value] of Object.entries(attributes)) {
      const attr = repo.create({
        profession_id: professionId,
        name,
        value: typeof value === 'string' ? value : JSON.stringify(value),
      });
      await repo.save(attr);
    }
  }

  /**
   * Create processing log entry
   */
  private async createProcessingLog(
    sourceId: number,
    stage: string,
    status: string
  ): Promise<ProcessingLog> {
    const repo = AppDataSource.getRepository(ProcessingLog);
    const log = repo.create({
      source_id: sourceId,
      stage,
      status,
    });
    return await repo.save(log);
  }

  /**
   * Update processing log
   */
  private async updateProcessingLog(
    logId: number,
    status: string,
    recordsProcessed: number,
    recordsFailed: number,
    processingTimeMs: number
  ): Promise<void> {
    const repo = AppDataSource.getRepository(ProcessingLog);
    await repo.update(logId, {
      status,
      records_processed: recordsProcessed,
      records_failed: recordsFailed,
      processing_time_ms: processingTimeMs,
    });
  }
}
