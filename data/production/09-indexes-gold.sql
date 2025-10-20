-- ============================================================================
-- Production Indexes - Gold Layer
-- ============================================================================
-- Description: Performance indexes for gold_mapping_taxonomies (production mappings)
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (production-ddl.sql)
-- ============================================================================

-- ============================================================================
-- GOLD_MAPPING_TAXONOMIES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_master_node_id_idx ON gold_mapping_taxonomies (master_node_id);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_child_node_id_idx ON gold_mapping_taxonomies (child_node_id);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_created_at_brin ON gold_mapping_taxonomies USING BRIN (created_at);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_last_updated_at_brin ON gold_mapping_taxonomies USING BRIN (last_updated_at);
CREATE INDEX IF NOT EXISTS gold_mapping_taxonomies_master_child_idx ON gold_mapping_taxonomies (master_node_id, child_node_id);

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Gold Layer Purpose:
--   - Contains only active, approved, non-AI mappings
--   - Used by Translation Lambda for real-time lookups
--   - Synced from silver_mapping_taxonomies
--
-- Critical Indexes:
--   - master_node_id, child_node_id: Fast bidirectional lookups
--   - Composite index: Translation queries
--   - BRIN timestamps: Audit queries
--
-- Performance:
--   - Small table (only active mappings)
--   - Read-heavy workload
--   - Fast translation API responses
--
-- ============================================================================
