/**
 * Rule Loader Service
 * Loads and caches mapping rules for the current invocation
 */

import { query } from '../database/connection';
import { MappingRule, RuleAssignment } from '../types';

export class RuleLoader {
  private rulesCache: Map<number, MappingRule> = new Map();
  private assignmentsCache: Map<string, RuleAssignment[]> = new Map();

  /**
   * Load all applicable rule assignments for a node type pair
   * Sorted by priority (lower number = higher priority)
   */
  async loadRuleAssignments(
    masterNodeTypeId: number,
    childNodeTypeId: number
  ): Promise<RuleAssignment[]> {
    const cacheKey = `${masterNodeTypeId}_${childNodeTypeId}`;

    // Check cache first
    if (this.assignmentsCache.has(cacheKey)) {
      return this.assignmentsCache.get(cacheKey)!;
    }

    // Query database
    const result = await query<any>(`
      SELECT
        ra.mapping_rule_assignment_id,
        ra.mapping_rule_id,
        ra.master_node_type_id,
        ra.node_type_id as child_node_type_id,
        ra.priority,
        ra.enabled,
        r.name as rule_name,
        r.enabled as rule_enabled,
        r.pattern,
        r.attributes,
        r.flags,
        r.action,
        r.command,
        r.AI_mapping_flag,
        r.Human_mapping_flag
      FROM silver_mapping_taxonomies_rules_assignment ra
      INNER JOIN silver_mapping_taxonomies_rules r
        ON ra.mapping_rule_id = r.mapping_rule_id
      WHERE ra.master_node_type_id = $1
        AND ra.node_type_id = $2
        AND ra.enabled = true
        AND r.enabled = true
        AND r.AI_mapping_flag = false
      ORDER BY ra.priority ASC
    `, [masterNodeTypeId, childNodeTypeId]);

    const assignments: RuleAssignment[] = result.rows.map((row) => ({
      mapping_rule_assignment_id: row.mapping_rule_assignment_id,
      mapping_rule_id: row.mapping_rule_id,
      master_node_type_id: row.master_node_type_id,
      child_node_type_id: row.child_node_type_id,
      priority: row.priority,
      enabled: row.enabled,
      rule: {
        mapping_rule_id: row.mapping_rule_id,
        name: row.rule_name,
        enabled: row.rule_enabled,
        pattern: row.pattern,
        attributes: row.attributes,
        flags: row.flags,
        action: row.action,
        command: row.command,
        AI_mapping_flag: row.AI_mapping_flag,
        Human_mapping_flag: row.Human_mapping_flag,
      },
    }));

    // Cache the results
    this.assignmentsCache.set(cacheKey, assignments);

    return assignments;
  }

  /**
   * Load a specific rule by ID
   */
  async loadRule(ruleId: number): Promise<MappingRule | null> {
    // Check cache first
    if (this.rulesCache.has(ruleId)) {
      return this.rulesCache.get(ruleId)!;
    }

    // Query database
    const result = await query<any>(`
      SELECT
        mapping_rule_id,
        name,
        enabled,
        pattern,
        attributes,
        flags,
        action,
        command,
        AI_mapping_flag,
        Human_mapping_flag
      FROM silver_mapping_taxonomies_rules
      WHERE mapping_rule_id = $1
    `, [ruleId]);

    if (result.rows.length === 0) {
      return null;
    }

    const row = result.rows[0];
    const rule: MappingRule = {
      mapping_rule_id: row.mapping_rule_id,
      name: row.name,
      enabled: row.enabled,
      pattern: row.pattern,
      attributes: row.attributes,
      flags: row.flags,
      action: row.action,
      command: row.command,
      AI_mapping_flag: row.AI_mapping_flag,
      Human_mapping_flag: row.Human_mapping_flag,
    };

    // Cache the result
    this.rulesCache.set(ruleId, rule);

    return rule;
  }

  /**
   * Clear caches (call between loads if needed)
   */
  clearCache(): void {
    this.rulesCache.clear();
    this.assignmentsCache.clear();
  }
}
