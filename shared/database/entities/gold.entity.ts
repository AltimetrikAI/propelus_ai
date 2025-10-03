/**
 * Gold Layer Database Entities
 * Production-ready, approved mappings
 */
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('gold_taxonomies_mapping')
export class GoldTaxonomiesMapping {
  @PrimaryGeneratedColumn()
  mapping_id!: number;

  @Column()
  master_node_id!: number;

  @Column()
  child_node_id!: number;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  // NEW: September 29, 2025 - Version tracking for remapping support
  @Column({ default: 1 })
  mapping_version!: number;

  @Column({ nullable: true })
  promoted_from_mapping_id?: number;
}

@Entity('gold_mapping_professions')
export class GoldMappingProfessions {
  @PrimaryGeneratedColumn()
  mapping_id!: number;

  @Column()
  child_node_id!: number;

  @Column()
  profession_id!: number;

  @CreateDateColumn()
  created_at!: Date;

  @UpdateDateColumn()
  last_updated_at!: Date;

  // NEW: September 29, 2025 - Version tracking for remapping support
  @Column({ default: 1 })
  mapping_version!: number;

  @Column({ nullable: true })
  promoted_from_mapping_id?: number;
}

@Entity('gold_mapping_taxonomies_log')
export class GoldMappingTaxonomiesLog {
  @PrimaryGeneratedColumn()
  log_id!: number;

  @Column({ nullable: true })
  mapping_id?: number;

  @Column('jsonb', { nullable: true })
  old_row?: Record<string, any>;

  @Column('jsonb', { nullable: true })
  new_row?: Record<string, any>;

  @Column({ length: 20, nullable: true })
  operation_type?: string; // insert, update, delete

  @CreateDateColumn()
  operation_date!: Date;

  @Column({ length: 255, nullable: true })
  user_name?: string;
}
