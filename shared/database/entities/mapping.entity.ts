/**
 * Mapping Layer Database Entities
 * Taxonomy and profession mapping rules and relationships
 */
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { SilverTaxonomiesNodes } from './silver.entity';

// ============================================
// TAXONOMY MAPPING MODELS
// ============================================

@Entity('silver_mapping_taxonomies_rules_types')
export class SilverMappingTaxonomiesRulesTypes {
  @PrimaryGeneratedColumn()
  mapping_rule_type_id!: number;

  @Column({ length: 100 })
  name!: string;

  @Column({ length: 100 })
  command!: string;

  @Column({ default: false })
  ai_mapping_flag!: boolean;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @OneToMany(() => SilverMappingTaxonomiesRules, (rule) => rule.rule_type)
  rules!: SilverMappingTaxonomiesRules[];
}

@Entity('silver_mapping_taxonomies_rules')
export class SilverMappingTaxonomiesRules {
  @PrimaryGeneratedColumn()
  mapping_rule_id!: number;

  @Column()
  mapping_rule_type_id!: number;

  @Column({ length: 255 })
  name!: string;

  @Column({ default: true })
  enabled!: boolean;

  @Column('text', { nullable: true })
  pattern?: string;

  @Column('jsonb', { nullable: true })
  attributes?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  flags?: Record<string, any>;

  @Column('text', { nullable: true })
  action?: string;

  @Column({ length: 255, nullable: true })
  command?: string;

  @Column({ default: false })
  AI_mapping_flag!: boolean;

  @Column({ default: false })
  Human_mapping_flag!: boolean;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverMappingTaxonomiesRulesTypes, (ruleType) => ruleType.rules)
  @JoinColumn({ name: 'mapping_rule_type_id' })
  rule_type!: SilverMappingTaxonomiesRulesTypes;

  @OneToMany(() => SilverMappingTaxonomiesRulesAssigment, (assignment) => assignment.rule)
  assignments!: SilverMappingTaxonomiesRulesAssigment[];
}

@Entity('silver_mapping_taxonomies_rules_assigment')
export class SilverMappingTaxonomiesRulesAssigment {
  @PrimaryGeneratedColumn()
  mapping_rule_assigment_id!: number;

  @Column()
  mapping_rule_id!: number;

  @Column()
  master_node_type_id!: number;

  @Column()
  Child_node_type_id!: number;

  @Column()
  priority!: number;

  @Column({ default: true })
  enabled!: boolean;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverMappingTaxonomiesRules, (rule) => rule.assignments)
  @JoinColumn({ name: 'mapping_rule_id' })
  rule!: SilverMappingTaxonomiesRules;
}

@Entity('silver_mapping_taxonomies')
export class SilverMappingTaxonomies {
  @PrimaryGeneratedColumn()
  mapping_id!: number;

  @Column()
  mapping_rule_id!: number;

  @Column()
  master_node_id!: number;

  @Column()
  child_node_id!: number;

  @Column('decimal', { precision: 5, scale: 2, nullable: true })
  confidence?: number;

  @Column({ length: 20, default: 'active' })
  status!: string;

  @Column({ length: 255, nullable: true })
  user?: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  // NEW: September 29, 2025 - Remapping support
  @Column({ default: true })
  is_active!: boolean;

  @Column({ default: 1 })
  mapping_version!: number;

  @Column({ nullable: true })
  superseded_by_mapping_id?: number;

  @Column({ type: 'timestamp', nullable: true })
  remapped_at?: Date;

  @ManyToOne(() => SilverTaxonomiesNodes)
  @JoinColumn({ name: 'master_node_id' })
  master_node!: SilverTaxonomiesNodes;

  @ManyToOne(() => SilverTaxonomiesNodes)
  @JoinColumn({ name: 'child_node_id' })
  child_node!: SilverTaxonomiesNodes;
}

// ============================================
// TAXONOMY MAPPING VERSIONS
// ============================================

@Entity('silver_mapping_taxonomies_versions')
export class SilverMappingTaxonomiesVersions {
  @PrimaryGeneratedColumn()
  mapping_version_id!: number;

  @Column()
  master_taxonomy_id!: number;

  @Column()
  child_taxonomy_id!: number;

  @Column()
  mapping_version_number!: number;

  @Column({ length: 255 })
  change_type!: string; // 'mappings added', 'mappings deleted', 'mappings modified', etc.

  @Column('jsonb', { nullable: true })
  affected_mappings?: any[]; // List of {mapping_id, master_node_id, child_node_id, change: 'new'|'deleted'|'modified'}

  @Column({ default: false })
  remapping_flag!: boolean;

  @Column('text', { nullable: true })
  remapping_reason?: string;

  @Column({ default: 0 })
  total_mappings_processed!: number;

  @Column({ default: 0 })
  total_mappings_changed!: number;

  @Column({ default: 0 })
  total_mappings_unchanged!: number;

  @Column({ default: 0 })
  total_mappings_failed!: number;

  @Column({ default: 0 })
  total_mappings_new!: number;

  @Column({ length: 50, nullable: true })
  remapping_proces_status?: string; // 'in progress', 'completed', 'failed', or NULL

  @Column('text', { nullable: true })
  version_notes?: string;

  @Column({ type: 'timestamp' })
  version_from_date!: Date;

  @Column({ type: 'timestamp', nullable: true })
  version_to_date?: Date;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @Column()
  load_id!: number; // FK to bronze_load_details
}

// ============================================
// PROFESSION MAPPING MODELS
// ============================================

@Entity('silver_mapping_professions_rules_types')
export class SilverMappingProfessionsRulesTypes {
  @PrimaryGeneratedColumn()
  mapping_rule_type_id!: number;

  @Column({ length: 100 })
  name!: string;

  @Column({ length: 100 })
  command!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @OneToMany(() => SilverMappingProfessionsRules, (rule) => rule.rule_type)
  rules!: SilverMappingProfessionsRules[];
}

@Entity('silver_mapping_professions_rules')
export class SilverMappingProfessionsRules {
  @PrimaryGeneratedColumn()
  mapping_rule_id!: number;

  @Column()
  mapping_rule_type_id!: number;

  @Column({ length: 255 })
  name!: string;

  @Column({ default: true })
  enabled!: boolean;

  @Column('text', { nullable: true })
  pattern?: string;

  @Column('jsonb', { nullable: true })
  attributes?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  flags?: Record<string, any>;

  @Column('text', { nullable: true })
  action?: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverMappingProfessionsRulesTypes, (ruleType) => ruleType.rules)
  @JoinColumn({ name: 'mapping_rule_type_id' })
  rule_type!: SilverMappingProfessionsRulesTypes;

  @OneToMany(() => SilverMappingProfessionsRulesAssignment, (assignment) => assignment.rule)
  assignments!: SilverMappingProfessionsRulesAssignment[];
}

@Entity('silver_mapping_professions_rules_assignment')
export class SilverMappingProfessionsRulesAssignment {
  @PrimaryGeneratedColumn()
  mapping_rule_assignment_id!: number;

  @Column()
  mapping_rule_id!: number;

  @Column()
  node_type_id!: number;

  @Column()
  priority!: number;

  @Column({ default: true })
  enabled!: boolean;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverMappingProfessionsRules, (rule) => rule.assignments)
  @JoinColumn({ name: 'mapping_rule_id' })
  rule!: SilverMappingProfessionsRules;
}

@Entity('silver_mapping_professions')
export class SilverMappingProfessions {
  @PrimaryGeneratedColumn()
  mapping_id!: number;

  @Column()
  mapping_rule_id!: number;

  @Column()
  node_id!: number;

  @Column()
  profession_id!: number;

  @Column({ length: 20, default: 'active' })
  status!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  // NEW: September 29, 2025 - Remapping support
  @Column({ default: true })
  is_active!: boolean;

  @Column({ default: 1 })
  mapping_version!: number;

  @Column({ nullable: true })
  superseded_by_mapping_id?: number;

  @Column({ type: 'timestamp', nullable: true })
  remapped_at?: Date;
}

// ============================================
// CONTEXT AND TRANSLATION MODELS
// ============================================

@Entity('silver_context_rules')
export class SilverContextRules {
  @PrimaryGeneratedColumn()
  rule_id!: number;

  @Column({ length: 255 })
  rule_name!: string;

  @Column({ length: 50, nullable: true })
  rule_type?: string;

  @Column('text')
  pattern!: string;

  @Column({ length: 100, nullable: true })
  context_key?: string;

  @Column('text', { nullable: true })
  context_value?: string;

  @Column({ nullable: true })
  authority_id?: number;

  @Column({ default: 100 })
  priority!: number;

  @Column({ default: false })
  override_state!: boolean;

  @Column({ default: true })
  is_active!: boolean;

  @Column('text', { nullable: true })
  notes?: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;
}

@Entity('silver_attribute_combinations')
export class SilverAttributeCombinations {
  @PrimaryGeneratedColumn()
  combination_id!: number;

  @Column()
  customer_id!: number;

  @Column({ length: 2, nullable: true })
  state_code?: string;

  @Column({ length: 100, nullable: true })
  profession_code?: string;

  @Column('text', { nullable: true })
  profession_description?: string;

  @Column({ length: 255, nullable: true })
  issuing_authority?: string;

  @Column('jsonb', { nullable: true })
  additional_attributes?: Record<string, any>;

  @Column({ length: 64, unique: true, nullable: true })
  combination_hash?: string;

  @CreateDateColumn()
  first_seen_date!: Date;

  @UpdateDateColumn()
  last_seen_date!: Date;

  @Column({ default: 1 })
  occurrence_count!: number;

  @Column({ nullable: true })
  mapped_node_id?: number;

  @Column('decimal', { precision: 5, scale: 2, nullable: true })
  mapping_confidence?: number;

  @Column({ length: 20, nullable: true })
  mapping_status?: string;
}

@Entity('silver_translation_patterns')
export class SilverTranslationPatterns {
  @PrimaryGeneratedColumn()
  pattern_id!: number;

  @Column({ nullable: true })
  source_taxonomy_id?: number;

  @Column({ nullable: true })
  target_taxonomy_id?: number;

  @Column({ length: 100, nullable: true })
  source_code?: string;

  @Column('jsonb', { nullable: true })
  source_attributes?: Record<string, any>;

  @Column({ nullable: true })
  result_count?: number;

  @Column('jsonb', { nullable: true })
  result_codes?: any[];

  @Column({ default: false })
  is_ambiguous!: boolean;

  @Column({ length: 50, nullable: true })
  resolution_method?: string;

  @CreateDateColumn()
  first_requested!: Date;

  @UpdateDateColumn()
  last_requested!: Date;

  @Column({ default: 1 })
  request_count!: number;
}
