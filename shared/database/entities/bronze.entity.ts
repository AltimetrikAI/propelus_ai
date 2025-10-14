/**
 * Bronze Layer Database Entities
 * Raw data ingestion tables - Enhanced v0.42
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

@Entity('bronze_load_details')
export class BronzeLoadDetails {
  @PrimaryGeneratedColumn()
  load_id!: number;

  @Column()
  customer_id!: number;

  @Column()
  taxonomy_id!: number;

  @Column('jsonb')
  load_details!: Record<string, any>;

  @CreateDateColumn()
  load_date!: Date;

  // NEW: October 14, 2024 - Data Engineer Schema Alignment
  @Column({ type: 'timestamp', nullable: true })
  load_start?: Date;

  @Column({ type: 'timestamp', nullable: true })
  load_end?: Date;

  @Column({ length: 50, default: 'in progress' })
  load_status!: string; // 'completed', 'partially completed', 'failed', 'in progress'

  @Column({ default: true })
  load_active_flag!: boolean;

  @Column({ length: 20 })
  load_type!: string; // 'new' or 'updated'

  @Column({ length: 20 })
  taxonomy_type!: string; // 'master' or 'customer'

  @Column({ length: 20, nullable: true })
  type?: string; // Legacy field - kept for backward compatibility

  // Request tracking and async support
  @Column({ length: 100, nullable: true })
  request_id?: string;

  @Column({ length: 100, nullable: true })
  source_system?: string; // 'api', 'file_upload', 'admin_ui', 'batch_import'

  @Column({ length: 500, nullable: true })
  callback_url?: string;

  @OneToMany(() => BronzeTaxonomies, (taxonomy) => taxonomy.load_details)
  taxonomies!: BronzeTaxonomies[];
}

@Entity('bronze_taxonomies')
export class BronzeTaxonomies {
  @PrimaryGeneratedColumn()
  row_id!: number; // Renamed from 'id' per Data Engineer schema spec

  @Column()
  customer_id!: number;

  @Column({ nullable: true })
  taxonomy_id?: number;

  @Column('jsonb')
  row_json!: Record<string, any>;

  @CreateDateColumn()
  load_date!: Date;

  @Column({ length: 20 })
  type!: string; // 'new' or 'updated'

  @Column({ nullable: true })
  load_id?: number;

  // NEW: October 14, 2024 - Data Engineer Schema Alignment
  @Column({ length: 50, default: 'in progress' })
  row_load_status!: string; // 'completed', 'in progress', 'failed'

  @Column({ default: true })
  row_active_flag!: boolean;

  // File and request tracking
  @Column({ length: 500, nullable: true })
  file_url?: string;

  @Column({ length: 100, nullable: true })
  request_id?: string;

  @ManyToOne(() => BronzeLoadDetails, (loadDetails) => loadDetails.taxonomies)
  @JoinColumn({ name: 'load_id' })
  load_details?: BronzeLoadDetails;
}

@Entity('bronze_professions')
export class BronzeProfessions {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  customer_id!: number;

  @Column('jsonb')
  row_json!: Record<string, any>;

  @CreateDateColumn()
  load_date!: Date;

  @Column({ length: 20 })
  type!: string; // 'new' or 'updated'

  // NEW: September 29, 2025 - File and request tracking
  @Column({ length: 500, nullable: true })
  file_url?: string;

  @Column({ length: 100, nullable: true })
  request_id?: string;
}

@Entity('bronze_data_sources')
export class BronzeDataSources {
  @PrimaryGeneratedColumn()
  source_id!: number;

  @Column()
  customer_id!: number;

  @Column({ length: 50, nullable: true })
  source_type?: string; // 'api', 'file', 'manual', 'bucket'

  @Column({ length: 255, nullable: true })
  source_name?: string;

  @Column('text', { nullable: true })
  source_url?: string;

  @Column('uuid', { nullable: true })
  request_id?: string;

  @Column({ length: 255, nullable: true })
  session_id?: string;

  @Column('text', { nullable: true })
  file_path?: string;

  @Column({ nullable: true })
  file_size_bytes?: number;

  @Column({ nullable: true })
  record_count?: number;

  @Column({ length: 50, nullable: true })
  import_status?: string; // 'pending', 'processing', 'completed', 'failed'

  @Column('text', { nullable: true })
  error_message?: string;

  @CreateDateColumn()
  created_at!: Date;

  @Column({ type: 'timestamp', nullable: true })
  processed_at?: Date;
}
