/**
 * Silver Layer Database Entities
 * Structured and validated data
 */
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToOne,
  JoinColumn,
} from 'typeorm';

// ============================================
// SILVER LAYER - TAXONOMY MODELS
// ============================================

@Entity('silver_taxonomies')
export class SilverTaxonomies {
  @PrimaryGeneratedColumn()
  taxonomy_id!: number;

  @Column({ nullable: true })
  customer_id?: number;

  @Column({ length: 255 })
  name!: string;

  @Column({ length: 20 })
  type!: string; // 'master' or 'customer'

  @Column({ length: 20, default: 'active' })
  status!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  // NEW: September 29, 2025 - Version tracking for remapping support
  @Column({ default: 1 })
  taxonomy_version!: number;

  @Column('text', { nullable: true })
  version_notes?: string;

  @Column({ type: 'timestamp', nullable: true })
  version_effective_date?: Date;

  @OneToMany(() => SilverTaxonomiesNodes, (node) => node.taxonomy)
  nodes!: SilverTaxonomiesNodes[];
}

@Entity('silver_taxonomies_nodes_types')
export class SilverTaxonomiesNodesTypes {
  @PrimaryGeneratedColumn()
  node_type_id!: number;

  @Column({ length: 100 })
  name!: string;

  @Column({ length: 20, default: 'active' })
  status!: string;

  @Column()
  level!: number;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @OneToMany(() => SilverTaxonomiesNodes, (node) => node.node_type)
  nodes!: SilverTaxonomiesNodes[];
}

@Entity('silver_taxonomies_attribute_types')
export class SilverTaxonomiesAttributeTypes {
  @PrimaryGeneratedColumn()
  attribute_type_id!: number;

  @Column({ length: 100, unique: true })
  name!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @OneToMany(() => SilverTaxonomiesNodesAttributes, (attr) => attr.attribute_type)
  node_attributes!: SilverTaxonomiesNodesAttributes[];
}

@Entity('silver_taxonomies_nodes')
export class SilverTaxonomiesNodes {
  @PrimaryGeneratedColumn()
  node_id!: number;

  @Column()
  node_type_id!: number;

  @Column()
  taxonomy_id!: number;

  @Column({ nullable: true })
  parent_node_id?: number;

  @Column('text')
  value!: string;

  @Column({ length: 500, nullable: true })
  profession?: string;

  @Column({ default: 1 })
  level!: number;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverTaxonomies, (taxonomy) => taxonomy.nodes)
  @JoinColumn({ name: 'taxonomy_id' })
  taxonomy!: SilverTaxonomies;

  @ManyToOne(() => SilverTaxonomiesNodesTypes, (nodeType) => nodeType.nodes)
  @JoinColumn({ name: 'node_type_id' })
  node_type!: SilverTaxonomiesNodesTypes;

  @ManyToOne(() => SilverTaxonomiesNodes, (node) => node.children)
  @JoinColumn({ name: 'parent_node_id' })
  parent?: SilverTaxonomiesNodes;

  @OneToMany(() => SilverTaxonomiesNodes, (node) => node.parent)
  children!: SilverTaxonomiesNodes[];

  @OneToMany(() => SilverTaxonomiesNodesAttributes, (attr) => attr.node)
  attributes!: SilverTaxonomiesNodesAttributes[];
}

@Entity('silver_taxonomies_nodes_attributes')
export class SilverTaxonomiesNodesAttributes {
  @PrimaryGeneratedColumn()
  Node_attribute_type_id!: number;

  @Column()
  Attribute_type_id!: number;

  @Column()
  node_id!: number;

  @Column({ length: 100 })
  name!: string;

  @Column('text')
  value!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverTaxonomiesNodes, (node) => node.attributes)
  @JoinColumn({ name: 'node_id' })
  node!: SilverTaxonomiesNodes;

  @ManyToOne(() => SilverTaxonomiesAttributeTypes, (attrType) => attrType.node_attributes)
  @JoinColumn({ name: 'Attribute_type_id' })
  attribute_type!: SilverTaxonomiesAttributeTypes;
}

// ============================================
// SILVER LAYER - PROFESSION MODELS
// ============================================

@Entity('silver_professions')
export class SilverProfessions {
  @PrimaryGeneratedColumn()
  profession_id!: number;

  @Column()
  customer_id!: number;

  @Column({ length: 500 })
  name!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @OneToMany(() => SilverProfessionsAttributes, (attr) => attr.profession)
  attributes!: SilverProfessionsAttributes[];
}

@Entity('silver_professions_attributes')
export class SilverProfessionsAttributes {
  @PrimaryGeneratedColumn()
  attribute_id!: number;

  @Column()
  profession_id!: number;

  @Column({ length: 100 })
  name!: string;

  @Column('text')
  value!: string;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  @ManyToOne(() => SilverProfessions, (profession) => profession.attributes)
  @JoinColumn({ name: 'profession_id' })
  profession!: SilverProfessions;
}

// ============================================
// SILVER LAYER - ATTRIBUTE TYPES
// ============================================

@Entity('silver_attribute_types')
export class SilverAttributeTypes {
  @PrimaryGeneratedColumn()
  attribute_type_id!: number;

  @Column({ length: 100, unique: true })
  attribute_name!: string;

  @Column('text', { nullable: true })
  description?: string;

  @Column({ length: 50, nullable: true })
  data_type?: string; // 'string', 'number', 'boolean', 'date', 'array'

  @Column({ default: false })
  is_required!: boolean;

  @Column({ length: 50, nullable: true })
  applies_to?: string; // 'node', 'profession', 'both'

  @CreateDateColumn()
  created_at!: Date;
}

// ============================================
// SILVER LAYER - PROCESSING LOG
// ============================================

@Entity('processing_log')
export class ProcessingLog {
  @PrimaryGeneratedColumn()
  log_id!: number;

  @Column({ nullable: true })
  source_id?: number;

  @Column({ length: 50, nullable: true })
  stage?: string; // 'bronze_ingestion', 'silver_processing', etc.

  @Column({ length: 50, nullable: true })
  status?: string; // 'started', 'completed', 'failed', 'skipped'

  @Column({ nullable: true })
  records_processed?: number;

  @Column({ nullable: true })
  records_failed?: number;

  @Column({ nullable: true })
  processing_time_ms?: number;

  @Column('jsonb', { nullable: true })
  error_details?: Record<string, any>;

  @CreateDateColumn()
  created_at!: Date;
}
