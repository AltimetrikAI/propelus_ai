/**
 * Versioning Service
 * Manages taxonomy version records and updates remapping counters
 */

import { PoolClient } from 'pg';
import { VersionCounters, NodeProcessingResult } from '../types';

export class VersioningService {
  /**
   * Get or create taxonomy version for a load
   * Returns version_id
   */
  async ensureTaxonomyVersion(
    client: PoolClient,
    taxonomyId: number,
    loadId: number,
    loadType: 'new' | 'update'
  ): Promise<number> {
    // Check if version already exists for this load
    const existing = await client.query<{ taxonomy_version_id: number }>(`
      SELECT taxonomy_version_id
      FROM silver_taxonomies_versions
      WHERE taxonomy_id = $1 AND load_id = $2
    `, [taxonomyId, loadId]);

    if (existing.rows.length > 0) {
      return existing.rows[0].taxonomy_version_id;
    }

    // Get next version number
    const versionNumber = await this.getNextVersionNumber(client, taxonomyId);

    // Close previous version if exists (update loads only)
    if (loadType === 'update' && versionNumber > 1) {
      await this.closePreviousVersion(client, taxonomyId);
    }

    // Create new version
    const result = await client.query<{ taxonomy_version_id: number }>(`
      INSERT INTO silver_taxonomies_versions (
        taxonomy_id,
        taxonomy_version_number,
        remapping_flag,
        remapping_reason,
        remapping_proces_status,
        version_from_date,
        load_id,
        created_at,
        last_updated_at
      )
      VALUES (
        $1, $2, $3, $4, $5, CURRENT_TIMESTAMP, $6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
      RETURNING taxonomy_version_id
    `, [
      taxonomyId,
      versionNumber,
      loadType === 'update', // remapping_flag
      loadType === 'update' ? 'taxonomy update' : null, // remapping_reason
      loadType === 'update' ? 'in progress' : null, // status
      loadId,
    ]);

    return result.rows[0].taxonomy_version_id;
  }

  /**
   * Update version counters based on processing results
   */
  async updateVersionCounters(
    client: PoolClient,
    versionId: number,
    results: NodeProcessingResult[]
  ): Promise<void> {
    const counters = this.calculateCounters(results);

    await client.query(`
      UPDATE silver_taxonomies_versions
      SET
        total_mappings_processed = $2,
        total_mappings_changed = $3,
        total_mappings_unchanged = $4,
        total_mappings_failed = $5,
        total_mappings_new = $6,
        remapping_proces_status = $7,
        last_updated_at = CURRENT_TIMESTAMP
      WHERE taxonomy_version_id = $1
    `, [
      versionId,
      counters.total_mappings_processed,
      counters.total_mappings_changed,
      counters.total_mappings_unchanged,
      counters.total_mappings_failed,
      counters.total_mappings_new,
      'done', // Mark as done after processing
    ]);
  }

  /**
   * Calculate counters from processing results
   */
  private calculateCounters(results: NodeProcessingResult[]): VersionCounters {
    const counters: VersionCounters = {
      total_mappings_processed: results.length,
      total_mappings_changed: 0,
      total_mappings_unchanged: 0,
      total_mappings_failed: 0,
      total_mappings_new: 0,
    };

    for (const result of results) {
      switch (result.action_taken) {
        case 'created':
          counters.total_mappings_new++;
          break;
        case 'updated':
        case 'deactivated':
          counters.total_mappings_changed++;
          break;
        case 'unchanged':
          counters.total_mappings_unchanged++;
          break;
        case 'no_match':
          if (result.error) {
            counters.total_mappings_failed++;
          }
          // If no error, just means no match found (not a failure)
          break;
      }
    }

    return counters;
  }

  /**
   * Get next version number for a taxonomy
   */
  private async getNextVersionNumber(
    client: PoolClient,
    taxonomyId: number
  ): Promise<number> {
    const result = await client.query<{ max_version: number }>(`
      SELECT COALESCE(MAX(taxonomy_version_number), 0) + 1 as max_version
      FROM silver_taxonomies_versions
      WHERE taxonomy_id = $1
    `, [taxonomyId]);

    return result.rows[0].max_version;
  }

  /**
   * Close previous version (set version_to_date)
   */
  private async closePreviousVersion(
    client: PoolClient,
    taxonomyId: number
  ): Promise<void> {
    await client.query(`
      UPDATE silver_taxonomies_versions
      SET version_to_date = CURRENT_TIMESTAMP,
          last_updated_at = CURRENT_TIMESTAMP
      WHERE taxonomy_id = $1
        AND version_to_date IS NULL
    `, [taxonomyId]);
  }

  /**
   * Mark version as failed
   */
  async markVersionFailed(
    client: PoolClient,
    versionId: number,
    error: string
  ): Promise<void> {
    await client.query(`
      UPDATE silver_taxonomies_versions
      SET remapping_proces_status = 'failed',
          version_notes = $2,
          last_updated_at = CURRENT_TIMESTAMP
      WHERE taxonomy_version_id = $1
    `, [versionId, `Error: ${error}`]);
  }
}
