-- Migration: 005_bronze_layer_enhancement
-- Description: Enhanced Bronze Layer with Load Details Tracking per Marcin's Data Model v0.42
-- Author: Propelus AI Team - Data Model Update
-- Date: 2025-01-11

-- ============================================================================
-- BRONZE LAYER ENHANCEMENT
-- ============================================================================

-- Create new bronze_load_details table for comprehensive load tracking
CREATE TABLE bronze_load_details (
    load_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    taxonomy_id INTEGER NOT NULL,
    load_details JSONB NOT NULL,
    load_date TIMESTAMP DEFAULT NOW(),
    type VARCHAR(20) CHECK (type IN ('New', 'Updated'))
);

-- Add comments for documentation
COMMENT ON TABLE bronze_load_details IS 'Stores a row for every data load for each taxonomy data set ingested';
COMMENT ON COLUMN bronze_load_details.customer_id IS 'Identifier of the customer whose data was loaded';
COMMENT ON COLUMN bronze_load_details.taxonomy_id IS 'Identifier of the taxonomy related to this load';
COMMENT ON COLUMN bronze_load_details.load_details IS 'JSON with detailed information about the load (load type, API command, Request ID)';
COMMENT ON COLUMN bronze_load_details.load_date IS 'Timestamp when the load occurred';
COMMENT ON COLUMN bronze_load_details.type IS 'Type of ingestion – new taxonomy or updated taxonomy';

-- Create indexes for performance
CREATE INDEX idx_bronze_load_details_customer ON bronze_load_details(customer_id);
CREATE INDEX idx_bronze_load_details_taxonomy ON bronze_load_details(taxonomy_id);
CREATE INDEX idx_bronze_load_details_date ON bronze_load_details(load_date DESC);
CREATE INDEX idx_bronze_load_details_type ON bronze_load_details(type);

-- Add foreign key relationship to existing bronze_taxonomies table
ALTER TABLE bronze_taxonomies
ADD COLUMN load_id INTEGER;

-- Create foreign key constraint
ALTER TABLE bronze_taxonomies
ADD CONSTRAINT fk_bronze_taxonomies_load_id
FOREIGN KEY (load_id) REFERENCES bronze_load_details(load_id);

-- Create index on new foreign key
CREATE INDEX idx_bronze_taxonomies_load_id ON bronze_taxonomies(load_id);

-- Update bronze_taxonomies table comment
COMMENT ON TABLE bronze_taxonomies IS 'Raw ingestion of taxonomy data set per customer (row by row)';
COMMENT ON COLUMN bronze_taxonomies.customer_id IS 'Identifier of the customer providing the taxonomy taken from application API';
COMMENT ON COLUMN bronze_taxonomies.taxonomy_id IS 'Identifier of the related taxonomy';
COMMENT ON COLUMN bronze_taxonomies.row_json IS 'JSON that contains one single row of taxonomy data';
COMMENT ON COLUMN bronze_taxonomies.load_id IS 'Foreign key to bronze_load_details tracking the load batch';

-- Insert sample load details for existing data (optional - can be run during migration)
-- This creates load details for existing bronze data
INSERT INTO bronze_load_details (customer_id, taxonomy_id, load_details, load_date, type)
SELECT DISTINCT
    customer_id,
    COALESCE(
        (row_json->>'taxonomy_id')::INTEGER,
        1
    ) as taxonomy_id,
    jsonb_build_object(
        'Load Type', 'Migration',
        'Request Type', 'HISTORICAL DATA',
        'Request ID', 'MIGRATION_' || id::TEXT,
        'Request Status', 'Success',
        'Number Of Rows', '1',
        'Nodes', '{}',
        'Attributes', '{}'
    ) as load_details,
    load_date,
    'New'
FROM bronze_taxonomies
WHERE load_id IS NULL
ORDER BY customer_id, load_date;

-- Update existing bronze_taxonomies records to link with new load_details
UPDATE bronze_taxonomies bt
SET load_id = bld.load_id
FROM bronze_load_details bld
WHERE bt.customer_id = bld.customer_id
  AND bt.load_date >= bld.load_date
  AND bt.load_id IS NULL
  AND bld.load_details->>'Request Type' = 'HISTORICAL DATA';