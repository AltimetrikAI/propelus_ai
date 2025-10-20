/**
 * Node Matcher Service
 * Evaluates mapping rules against customer nodes to find master node matches
 */

import { query } from '../database/connection';
import { MappingRule, CustomerNode, MasterNode, MatchResult } from '../types';

export class NodeMatcher {
  /**
   * Find matching master node for a customer node using a specific rule
   */
  async findMatch(
    customerNode: CustomerNode,
    masterNodeTypeId: number,
    rule: MappingRule
  ): Promise<MatchResult> {
    const command = rule.command?.toLowerCase();

    try {
      // Route to appropriate matcher based on command
      switch (command) {
        case 'equals':
        case 'exact':
          return await this.matchEquals(customerNode, masterNodeTypeId, rule);

        case 'contains':
          return await this.matchContains(customerNode, masterNodeTypeId, rule);

        case 'startswith':
          return await this.matchStartsWith(customerNode, masterNodeTypeId, rule);

        case 'endswith':
          return await this.matchEndsWith(customerNode, masterNodeTypeId, rule);

        case 'regex':
          return await this.matchRegex(customerNode, masterNodeTypeId, rule);

        default:
          console.warn(`Unknown command: ${command}`);
          return this.noMatch(rule.mapping_rule_id);
      }
    } catch (error) {
      console.error(`Error matching with rule ${rule.mapping_rule_id}:`, error);
      return this.noMatch(rule.mapping_rule_id);
    }
  }

  /**
   * Exact match (case-insensitive)
   */
  private async matchEquals(
    customerNode: CustomerNode,
    masterNodeTypeId: number,
    rule: MappingRule
  ): Promise<MatchResult> {
    const result = await query<MasterNode>(`
      SELECT node_id, value
      FROM silver_taxonomies_nodes
      WHERE node_type_id = $1
        AND status = 'active'
        AND LOWER(value) = LOWER($2)
      LIMIT 1
    `, [masterNodeTypeId, customerNode.value]);

    if (result.rows.length > 0) {
      return {
        matched: true,
        master_node_id: result.rows[0].node_id,
        confidence: 100, // Command rules always 100
        rule_id: rule.mapping_rule_id,
        method: 'equals',
      };
    }

    return this.noMatch(rule.mapping_rule_id);
  }

  /**
   * Contains match
   */
  private async matchContains(
    customerNode: CustomerNode,
    masterNodeTypeId: number,
    rule: MappingRule
  ): Promise<MatchResult> {
    const pattern = rule.pattern || customerNode.value;

    const result = await query<MasterNode>(`
      SELECT node_id, value
      FROM silver_taxonomies_nodes
      WHERE node_type_id = $1
        AND status = 'active'
        AND LOWER(value) LIKE LOWER($2)
      LIMIT 1
    `, [masterNodeTypeId, `%${pattern}%`]);

    if (result.rows.length > 0) {
      return {
        matched: true,
        master_node_id: result.rows[0].node_id,
        confidence: 100,
        rule_id: rule.mapping_rule_id,
        method: 'contains',
      };
    }

    return this.noMatch(rule.mapping_rule_id);
  }

  /**
   * Starts with match
   */
  private async matchStartsWith(
    customerNode: CustomerNode,
    masterNodeTypeId: number,
    rule: MappingRule
  ): Promise<MatchResult> {
    const pattern = rule.pattern || customerNode.value;

    const result = await query<MasterNode>(`
      SELECT node_id, value
      FROM silver_taxonomies_nodes
      WHERE node_type_id = $1
        AND status = 'active'
        AND LOWER(value) LIKE LOWER($2)
      LIMIT 1
    `, [masterNodeTypeId, `${pattern}%`]);

    if (result.rows.length > 0) {
      return {
        matched: true,
        master_node_id: result.rows[0].node_id,
        confidence: 100,
        rule_id: rule.mapping_rule_id,
        method: 'startswith',
      };
    }

    return this.noMatch(rule.mapping_rule_id);
  }

  /**
   * Ends with match
   */
  private async matchEndsWith(
    customerNode: CustomerNode,
    masterNodeTypeId: number,
    rule: MappingRule
  ): Promise<MatchResult> {
    const pattern = rule.pattern || customerNode.value;

    const result = await query<MasterNode>(`
      SELECT node_id, value
      FROM silver_taxonomies_nodes
      WHERE node_type_id = $1
        AND status = 'active'
        AND LOWER(value) LIKE LOWER($2)
      LIMIT 1
    `, [masterNodeTypeId, `%${pattern}`]);

    if (result.rows.length > 0) {
      return {
        matched: true,
        master_node_id: result.rows[0].node_id,
        confidence: 100,
        rule_id: rule.mapping_rule_id,
        method: 'endswith',
      };
    }

    return this.noMatch(rule.mapping_rule_id);
  }

  /**
   * Regex match
   */
  private async matchRegex(
    customerNode: CustomerNode,
    masterNodeTypeId: number,
    rule: MappingRule
  ): Promise<MatchResult> {
    if (!rule.pattern) {
      return this.noMatch(rule.mapping_rule_id);
    }

    const result = await query<MasterNode>(`
      SELECT node_id, value
      FROM silver_taxonomies_nodes
      WHERE node_type_id = $1
        AND status = 'active'
        AND value ~* $2
      LIMIT 1
    `, [masterNodeTypeId, rule.pattern]);

    if (result.rows.length > 0) {
      return {
        matched: true,
        master_node_id: result.rows[0].node_id,
        confidence: 100,
        rule_id: rule.mapping_rule_id,
        method: 'regex',
      };
    }

    return this.noMatch(rule.mapping_rule_id);
  }

  /**
   * Helper to create a no-match result
   */
  private noMatch(ruleId: number): MatchResult {
    return {
      matched: false,
      confidence: 0,
      rule_id: ruleId,
      method: 'none',
    };
  }
}
