-- ============================================================================
-- Production Indexes - Silver Versioning Layer
-- ============================================================================
-- Description: Performance indexes for taxonomy and mapping version tracking
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (production-ddl.sql)
-- ============================================================================

-- ============================================================================
-- SILVER_TAXONOMIES_VERSIONS INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_taxonomy_id_idx ON silver_taxonomies_versions (taxonomy_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_load_id_idx ON silver_taxonomies_versions (load_id);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_remapping_flag_true_idx ON silver_taxonomies_versions (remapping_flag);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_remapping_reason_lower_idx ON silver_taxonomies_versions (lower(remapping_reason));
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_remapping_reason_trgm ON silver_taxonomies_versions USING GIN (remapping_reason gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_total_mappings_processed_lower_idx ON silver_taxonomies_versions (total_mappings_processed);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_total_mappings_changed_lower_idx ON silver_taxonomies_versions (total_mappings_changed);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_total_mappings_unchanged_lower_idx ON silver_taxonomies_versions (total_mappings_unchanged);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_total_mappings_failed_lower_idx ON silver_taxonomies_versions (total_mappings_failed);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_total_mappings_new_lower_idx ON silver_taxonomies_versions (total_mappings_new);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_remapping_proces_status_lower_idx ON silver_taxonomies_versions (lower(remapping_proces_status));
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_remapping_proces_status_trgm ON silver_taxonomies_versions USING GIN (remapping_proces_status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_version_notes_lower_idx ON silver_taxonomies_versions (lower(version_notes));
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_version_notes_trgm ON silver_taxonomies_versions USING GIN (version_notes gin_trgm_ops);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_version_to_date_lower_idx ON silver_taxonomies_versions USING BRIN(version_to_date);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_created_at_lower_idx ON silver_taxonomies_versions USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_created_at_brin ON silver_taxonomies_versions USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_last_updated_at_brin ON silver_taxonomies_versions USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS silver_taxonomies_versions_version_from_date_brin ON silver_taxonomies_versions USING BRIN (version_from_date);

-- ============================================================================
-- SILVER_MAPPING_TAXONOMIES_VERSIONS INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_mapping_id_idx ON silver_mapping_taxonomies_versions (mapping_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_superseded_by_mapping_id_idx ON silver_mapping_taxonomies_versions (superseded_by_mapping_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_version_to_date_lower_idx ON silver_mapping_taxonomies_versions USING BRIN(version_to_date);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_superseded_by_mapping_id_lower_idx ON silver_mapping_taxonomies_versions (superseded_by_mapping_id);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_created_at_brin ON silver_mapping_taxonomies_versions USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_last_updated_at_brin ON silver_mapping_taxonomies_versions USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_version_from_date_brin ON silver_mapping_taxonomies_versions USING BRIN (version_from_date);
CREATE INDEX IF NOT EXISTS silver_mapping_taxonomies_versions_version_to_date_brin ON silver_mapping_taxonomies_versions USING BRIN (version_to_date);

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Version Tracking Performance:
--   - taxonomy_id, mapping_id: Fast version lookups
--   - remapping_flag: Filter remapping events
--   - BRIN on date columns: Efficient time-range queries
--   - Counter indexes: Aggregate query performance
--
-- Used by:
--   - Lambda version tracking
--   - Audit queries
--   - Historical analysis
--
-- ============================================================================
