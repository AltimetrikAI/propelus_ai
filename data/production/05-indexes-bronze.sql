-- ============================================================================
-- Production Indexes - Bronze Layer
-- ============================================================================
-- Description: Performance indexes for bronze_load_details and bronze_taxonomies
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables created (production-ddl.sql)
-- ============================================================================

-- ============================================================================
-- BRONZE_LOAD_DETAILS INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS bronze_load_details_customer_id_idx ON bronze_load_details (customer_id);
CREATE INDEX IF NOT EXISTS bronze_load_details_taxonomy_id_idx ON bronze_load_details (taxonomy_id);
CREATE INDEX IF NOT EXISTS bronze_load_details_load_id_lower_idx ON bronze_load_details (load_id);
CREATE INDEX IF NOT EXISTS bronze_load_details_load_end_lower_idx ON bronze_load_details USING BRIN (load_end);
CREATE INDEX IF NOT EXISTS bronze_load_details_load_start_brin ON bronze_load_details USING BRIN (load_start);
CREATE INDEX IF NOT EXISTS bronze_load_details_load_status_lower_idx ON bronze_load_details (lower(load_status));
CREATE INDEX IF NOT EXISTS bronze_load_details_load_status_trgm ON bronze_load_details USING GIN (load_status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS bronze_load_details_load_active_flag_true_idx ON bronze_load_details (load_active_flag);
CREATE INDEX IF NOT EXISTS bronze_load_details_load_date_brin ON bronze_load_details USING BRIN (load_date);

-- ============================================================================
-- BRONZE_TAXONOMIES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS bronze_taxonomies_load_id_idx ON bronze_taxonomies (load_id);
CREATE INDEX IF NOT EXISTS bronze_taxonomies_customer_id_idx ON bronze_taxonomies (customer_id);
CREATE INDEX IF NOT EXISTS bronze_taxonomies_taxonomy_id_idx ON bronze_taxonomies (taxonomy_id);
CREATE INDEX IF NOT EXISTS bronze_taxonomies_row_json_gin ON bronze_taxonomies USING GIN (row_json jsonb_path_ops);
CREATE INDEX IF NOT EXISTS bronze_taxonomies_row_load_status_lower_idx ON bronze_taxonomies (lower(row_load_status));
CREATE INDEX IF NOT EXISTS bronze_taxonomies_row_load_status_trgm ON bronze_taxonomies USING GIN (row_load_status gin_trgm_ops);
CREATE INDEX IF NOT EXISTS bronze_taxonomies_row_active_flag_true_idx ON bronze_taxonomies (row_active_flag);
CREATE INDEX IF NOT EXISTS bronze_taxonomies_cust_tax_idx ON bronze_taxonomies (customer_id, taxonomy_id);

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Index Types Used:
--   - B-tree: Standard indexes for equality/range queries
--   - GIN: Generalized Inverted Index for JSONB and trigram text search
--   - BRIN: Block Range Index for timestamp columns (space-efficient)
--
-- Performance Benefits:
--   - JSONB path ops: Fast queries on row_json structure
--   - Trigram (trgm): Fuzzy text matching on status fields
--   - BRIN on timestamps: Efficient time-range queries
--   - Composite indexes: Multi-column lookups
--
-- ============================================================================
