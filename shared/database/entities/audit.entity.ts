/**
 * Audit Log Database Entities
 * Comprehensive audit logging for all layers
 */
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

// ============================================
// AUDIT LOG MODELS - v0.5 COMPREHENSIVE LOGGING
// ============================================

@Entity('silver_taxonomies_log')
export class SilverTaxonomiesLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  taxonomy_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  new_row?: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string; // insert, update, delete

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

@Entity('silver_taxonomies_nodes_types_log')
export class SilverTaxonomiesNodesTypesLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  node_type_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb')
  new_row!: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string;

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

@Entity('silver_taxonomies_nodes_log')
export class SilverTaxonomiesNodesLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  node_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb')
  new_row!: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string;

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

@Entity('silver_taxonomies_nodes_attributes_log')
export class SilverTaxonomiesNodesAttributesLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  node_attribute_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb')
  new_row!: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string;

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

@Entity('silver_taxonomies_attribute_types_log')
export class SilverTaxonomiesAttributeTypesLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  attribute_type_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb')
  new_row!: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string;

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

@Entity('silver_mapping_taxonomies_rules_log')
export class SilverMappingTaxonomiesRulesLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  mapping_rule_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb')
  new_row!: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string;

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

@Entity('silver_mapping_rules_assignment_log')
export class SilverMappingRulesAssignmentLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  mapping_rule_assignment_id!: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb')
  new_row!: Record<string, any>;

  @Column({ length: 20 })
  operation_type!: string;

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}

// ============================================
// VERSION TRACKING AND REMAPPING (September 29, 2025)
// ============================================

@Entity('silver_taxonomies_version_history')
export class SilverTaxonomiesVersionHistory {
  @PrimaryGeneratedColumn()
  version_history_id!: number;

  @Column()
  taxonomy_id!: number;

  @Column()
  previous_version!: number;

  @Column()
  new_version!: number;

  @Column({ length: 50 })
  change_type!: string;

  @Column('jsonb', { nullable: true })
  affected_nodes?: number[];

  @Column('text', { nullable: true })
  change_description?: string;

  @Column({ length: 255, nullable: true })
  changed_by?: string;

  @CreateDateColumn()
  changed_at!: Date;
}

@Entity('silver_remapping_log')
export class SilverRemappingLog {
  @PrimaryGeneratedColumn()
  remapping_id!: number;

  @Column()
  taxonomy_id!: number;

  @Column({ length: 100 })
  trigger_reason!: string;

  @Column()
  from_version!: number;

  @Column()
  to_version!: number;

  @Column({ nullable: true })
  total_mappings_processed?: number;

  @Column({ nullable: true })
  mappings_changed?: number;

  @Column({ nullable: true })
  mappings_unchanged?: number;

  @Column({ nullable: true })
  mappings_failed?: number;

  @CreateDateColumn()
  processing_started_at!: Date;

  @Column({ type: 'timestamp', nullable: true })
  processing_completed_at?: Date;

  @Column({ length: 20, default: 'in_progress' })
  processing_status!: string;

  @Column({ length: 255, nullable: true })
  triggered_by?: string;

  @Column('text', { nullable: true })
  notes?: string;
}

@Entity('audit_log_enhanced')
export class AuditLogEnhanced {
  @PrimaryGeneratedColumn()
  log_id!: number;

  @Column({ length: 100 })
  table_name!: string;

  @Column({ nullable: true })
  record_id?: number;

  @Column({ length: 20, nullable: true })
  operation?: string; // 'insert', 'update', 'delete', 'merge'

  @Column('jsonb', { nullable: true })
  old_values?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  new_values?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  changed_fields?: string[];

  @Column({ length: 255, nullable: true })
  user_id?: string;

  @Column({ length: 100, nullable: true })
  user_role?: string;

  @Column({ length: 100, nullable: true })
  source_system?: string;

  @Column('uuid', { nullable: true })
  correlation_id?: string;

  @CreateDateColumn()
  created_at!: Date;
}

// ============================================
// MASTER TAXONOMY VERSIONS
// ============================================

@Entity('master_taxonomy_versions')
export class MasterTaxonomyVersions {
  @PrimaryGeneratedColumn()
  version_id!: number;

  @Column({ length: 20, unique: true })
  version_number!: string;

  @Column('text', { nullable: true })
  description?: string;

  @Column({ nullable: true })
  total_nodes?: number;

  @Column({ nullable: true })
  total_levels?: number;

  @Column({ length: 255, nullable: true })
  created_by?: string;

  @CreateDateColumn()
  created_at!: Date;

  @Column({ default: false })
  is_current!: boolean;

  @Column('jsonb', { nullable: true })
  change_summary?: Record<string, any>;
}

// ============================================
// API CONTRACTS
// ============================================

@Entity('api_contracts')
export class APIContracts {
  @PrimaryGeneratedColumn()
  contract_id!: number;

  @Column({ length: 100 })
  api_name!: string;

  @Column({ length: 20 })
  version!: string;

  @Column({ length: 255, nullable: true })
  endpoint_path?: string;

  @Column({ length: 10, nullable: true })
  method?: string; // 'GET', 'POST', 'PUT', 'DELETE', 'PATCH'

  @Column('jsonb', { nullable: true })
  request_schema?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  response_schema?: Record<string, any>;

  @Column({ default: true })
  is_active!: boolean;

  @CreateDateColumn()
  created_at!: Date;

  @Column({ type: 'timestamp', nullable: true })
  deprecated_at?: Date;
}
