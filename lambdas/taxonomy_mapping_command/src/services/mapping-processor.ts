/**
 * Mapping Processor Service
 * Handles creation, update, and deactivation of mappings
 */

import { PoolClient } from 'pg';
import {
  CustomerNode,
  MatchResult,
  NodeProcessingResult,
  ExistingMapping,
  MappingInsert,
  MappingVersionInsert,
} from '../types';

export class MappingProcessor {
  /**
   * Process a single customer node mapping
   * Handles new/update load types differently
   */
  async processNodeMapping(
    client: PoolClient,
    customerNode: CustomerNode,
    matchResult: MatchResult | undefined,
    loadType: 'new' | 'update'
  ): Promise<NodeProcessingResult> {
    try {
      // Check if mapping already exists
      const existingMapping = await this.getExistingMapping(
        client,
        customerNode.node_id
      );

      // Handle no match case
      if (!matchResult || !matchResult.matched) {
        return await this.handleNoMatch(
          client,
          customerNode,
          existingMapping,
          loadType
        );
      }

      // Handle successful match
      return await this.handleMatch(
        client,
        customerNode,
        matchResult,
        existingMapping,
        loadType
      );
    } catch (error) {
      console.error(
        `Error processing node ${customerNode.node_id}:`,
        error
      );
      return {
        customer_node_id: customerNode.node_id,
        action_taken: 'no_match',
        error: error instanceof Error ? error.message : String(error),
      };
    }
  }

  /**
   * Get existing active mapping for a customer node
   */
  private async getExistingMapping(
    client: PoolClient,
    customerNodeId: number
  ): Promise<ExistingMapping | null> {
    const result = await client.query<ExistingMapping>(`
      SELECT
        mapping_id,
        master_node_id,
        node_id as child_node_id,
        confidence,
        status,
        mapping_rule_id
      FROM silver_mapping_taxonomies
      WHERE node_id = $1
        AND status = 'active'
      LIMIT 1
    `, [customerNodeId]);

    return result.rows.length > 0 ? result.rows[0] : null;
  }

  /**
   * Handle case when no match is found
   */
  private async handleNoMatch(
    client: PoolClient,
    customerNode: CustomerNode,
    existingMapping: ExistingMapping | null,
    loadType: 'new' | 'update'
  ): Promise<NodeProcessingResult> {
    // For 'new' loads, no match means no mapping created
    if (loadType === 'new') {
      return {
        customer_node_id: customerNode.node_id,
        action_taken: 'no_match',
      };
    }

    // For 'update' loads, deactivate existing mapping if present
    if (existingMapping) {
      await this.deactivateMapping(client, existingMapping.mapping_id);
      return {
        customer_node_id: customerNode.node_id,
        action_taken: 'deactivated',
        mapping_id: existingMapping.mapping_id,
      };
    }

    return {
      customer_node_id: customerNode.node_id,
      action_taken: 'no_match',
    };
  }

  /**
   * Handle case when a match is found
   */
  private async handleMatch(
    client: PoolClient,
    customerNode: CustomerNode,
    matchResult: MatchResult,
    existingMapping: ExistingMapping | null,
    loadType: 'new' | 'update'
  ): Promise<NodeProcessingResult> {
    // For 'new' loads, always create new mapping
    if (loadType === 'new') {
      const mappingId = await this.createMapping(client, {
        mapping_rule_id: matchResult.rule_id,
        master_node_id: matchResult.master_node_id!,
        child_node_id: customerNode.node_id,
        confidence: matchResult.confidence,
        status: 'active',
        user: 'lambda_command_mapping',
      });

      // Create version 1
      await this.createMappingVersion(client, mappingId, 1);

      return {
        customer_node_id: customerNode.node_id,
        match_result: matchResult,
        action_taken: 'created',
        mapping_id: mappingId,
      };
    }

    // For 'update' loads
    if (existingMapping) {
      // Check if mapping changed
      if (existingMapping.master_node_id === matchResult.master_node_id) {
        // Same mapping - no action needed
        return {
          customer_node_id: customerNode.node_id,
          match_result: matchResult,
          action_taken: 'unchanged',
          mapping_id: existingMapping.mapping_id,
        };
      }

      // Mapping changed - deactivate old, create new
      await this.deactivateMapping(client, existingMapping.mapping_id);
      await this.closeMappingVersion(client, existingMapping.mapping_id);

      const newMappingId = await this.createMapping(client, {
        mapping_rule_id: matchResult.rule_id,
        master_node_id: matchResult.master_node_id!,
        child_node_id: customerNode.node_id,
        confidence: matchResult.confidence,
        status: 'active',
        user: 'lambda_command_mapping',
      });

      // Determine next version number
      const nextVersion = await this.getNextVersionNumber(
        client,
        existingMapping.mapping_id
      );
      await this.createMappingVersion(client, newMappingId, nextVersion);

      return {
        customer_node_id: customerNode.node_id,
        match_result: matchResult,
        action_taken: 'updated',
        mapping_id: newMappingId,
      };
    }

    // No existing mapping on update - create new
    const mappingId = await this.createMapping(client, {
      mapping_rule_id: matchResult.rule_id,
      master_node_id: matchResult.master_node_id!,
      child_node_id: customerNode.node_id,
      confidence: matchResult.confidence,
      status: 'active',
      user: 'lambda_command_mapping',
    });

    await this.createMappingVersion(client, mappingId, 1);

    return {
      customer_node_id: customerNode.node_id,
      match_result: matchResult,
      action_taken: 'created',
      mapping_id: mappingId,
    };
  }

  /**
   * Create a new mapping
   */
  private async createMapping(
    client: PoolClient,
    mapping: MappingInsert
  ): Promise<number> {
    const result = await client.query<{ mapping_id: number }>(`
      INSERT INTO silver_mapping_taxonomies (
        mapping_rule_id,
        master_node_id,
        node_id,
        confidence,
        status,
        "user",
        created_at,
        last_updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING mapping_id
    `, [
      mapping.mapping_rule_id,
      mapping.master_node_id,
      mapping.child_node_id,
      mapping.confidence,
      mapping.status,
      mapping.user,
    ]);

    return result.rows[0].mapping_id;
  }

  /**
   * Deactivate an existing mapping
   */
  private async deactivateMapping(
    client: PoolClient,
    mappingId: number
  ): Promise<void> {
    await client.query(`
      UPDATE silver_mapping_taxonomies
      SET status = 'inactive',
          last_updated_at = CURRENT_TIMESTAMP
      WHERE mapping_id = $1
    `, [mappingId]);
  }

  /**
   * Create mapping version record
   */
  private async createMappingVersion(
    client: PoolClient,
    mappingId: number,
    versionNumber: number
  ): Promise<void> {
    await client.query(`
      INSERT INTO silver_mapping_taxonomies_versions (
        mapping_id,
        mapping_version_number,
        version_from_date,
        created_at,
        last_updated_at
      )
      VALUES ($1, $2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `, [mappingId, versionNumber]);
  }

  /**
   * Close mapping version (set version_to_date)
   */
  private async closeMappingVersion(
    client: PoolClient,
    mappingId: number
  ): Promise<void> {
    await client.query(`
      UPDATE silver_mapping_taxonomies_versions
      SET version_to_date = CURRENT_TIMESTAMP,
          superseded_at = CURRENT_TIMESTAMP,
          last_updated_at = CURRENT_TIMESTAMP
      WHERE mapping_id = $1
        AND version_to_date IS NULL
    `, [mappingId]);
  }

  /**
   * Get next version number for a mapping
   */
  private async getNextVersionNumber(
    client: PoolClient,
    mappingId: number
  ): Promise<number> {
    const result = await client.query<{ max_version: number }>(`
      SELECT COALESCE(MAX(mapping_version_number), 0) + 1 as max_version
      FROM silver_mapping_taxonomies_versions
      WHERE mapping_id = $1
    `, [mappingId]);

    return result.rows[0].max_version;
  }
}
