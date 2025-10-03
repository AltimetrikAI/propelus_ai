-- Migration: 006_silver_attribute_types
-- Description: Silver Layer Attribute Types Standardization per Marcin's Data Model v0.42
-- Author: Propelus AI Team - Data Model Update
-- Date: 2025-01-11

-- ============================================================================
-- SILVER LAYER ATTRIBUTE TYPES
-- ============================================================================

-- Create new silver_taxonomies_attribute_types table
CREATE TABLE silver_taxonomies_attribute_types (
    attribute_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    last_updated_at TIMESTAMP DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE silver_taxonomies_attribute_types IS 'Defines the types of attributes that can be assigned to taxonomy nodes. Acts as a reference table so attributes are standardized across taxonomies.';
COMMENT ON COLUMN silver_taxonomies_attribute_types.attribute_type_id IS 'Primary surrogate key - ID of the attribute type';
COMMENT ON COLUMN silver_taxonomies_attribute_types.name IS 'Name of the attribute type (for example: State)';

-- Create indexes
CREATE INDEX idx_silver_attribute_types_name ON silver_taxonomies_attribute_types(name);

-- Insert standard attribute types from Marcin's sample data and common use cases
INSERT INTO silver_taxonomies_attribute_types (name) VALUES
('Profession abbreviation'),
('Allowed occupation status'),
('State'),
('License Type'),
('Issuing Authority'),
('Certification Level'),
('Specialization'),
('Professional Level'),
('Geographic Region'),
('Regulatory Body');

-- ============================================================================
-- UPDATE EXISTING SILVER_TAXONOMIES_NODES_ATTRIBUTES TABLE
-- ============================================================================

-- First, create a backup of the current structure
CREATE TABLE silver_taxonomies_nodes_attributes_backup AS
SELECT * FROM silver_taxonomies_nodes_attributes;

-- Add the new Attribute_type_id column
ALTER TABLE silver_taxonomies_nodes_attributes
ADD COLUMN Attribute_type_id INTEGER;

-- Rename the primary key column as per Marcin's specification
ALTER TABLE silver_taxonomies_nodes_attributes
RENAME COLUMN attribute_id TO Node_attribute_type_id;

-- Update the column comment
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.Node_attribute_type_id IS 'Primary surrogate key - ID of the connection between node and attribute_type';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.Attribute_type_id IS 'Foreign key to silver_taxonomies_attribute_types';

-- Map existing attributes to standardized attribute types
-- This is a best-effort mapping based on common attribute names
UPDATE silver_taxonomies_nodes_attributes
SET Attribute_type_id = (
    SELECT attribute_type_id
    FROM silver_taxonomies_attribute_types
    WHERE LOWER(name) = CASE
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%state%' THEN 'state'
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%license%' THEN 'license type'
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%authority%' THEN 'issuing authority'
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%abbreviation%' THEN 'profession abbreviation'
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%status%' THEN 'allowed occupation status'
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%certification%' THEN 'certification level'
        WHEN LOWER(silver_taxonomies_nodes_attributes.name) LIKE '%specialization%' THEN 'specialization'
        ELSE 'state' -- Default fallback
    END
    LIMIT 1
);

-- For any remaining NULL values, set them to a default attribute type
UPDATE silver_taxonomies_nodes_attributes
SET Attribute_type_id = (
    SELECT attribute_type_id
    FROM silver_taxonomies_attribute_types
    WHERE name = 'State'
    LIMIT 1
)
WHERE Attribute_type_id IS NULL;

-- Now add the foreign key constraint
ALTER TABLE silver_taxonomies_nodes_attributes
ADD CONSTRAINT fk_silver_nodes_attributes_type_id
FOREIGN KEY (Attribute_type_id) REFERENCES silver_taxonomies_attribute_types(attribute_type_id);

-- Create index on the new foreign key
CREATE INDEX idx_silver_nodes_attributes_type_id ON silver_taxonomies_nodes_attributes(Attribute_type_id);

-- Update table comments
COMMENT ON TABLE silver_taxonomies_nodes_attributes IS 'Stores attributes assigned to taxonomy nodes, one or many attributes of the same type can be attached to the node';
COMMENT ON COLUMN silver_taxonomies_nodes_attributes.value IS 'Attribute value (for example: CA, FL, WY, UT)';

-- ============================================================================
-- UPDATE SILVER_PROFESSIONS_ATTRIBUTES IF EXISTS
-- ============================================================================

-- Check if silver_professions_attributes table exists and update it similarly
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'silver_professions_attributes') THEN
        -- Add Attribute_type_id column to professions attributes as well
        ALTER TABLE silver_professions_attributes
        ADD COLUMN Attribute_type_id INTEGER;

        -- Map existing profession attributes to standardized types
        UPDATE silver_professions_attributes
        SET Attribute_type_id = (
            SELECT attribute_type_id
            FROM silver_taxonomies_attribute_types
            WHERE LOWER(name) = CASE
                WHEN LOWER(silver_professions_attributes.name) LIKE '%state%' THEN 'state'
                WHEN LOWER(silver_professions_attributes.name) LIKE '%license%' THEN 'license type'
                WHEN LOWER(silver_professions_attributes.name) LIKE '%authority%' THEN 'issuing authority'
                WHEN LOWER(silver_professions_attributes.name) LIKE '%abbreviation%' THEN 'profession abbreviation'
                WHEN LOWER(silver_professions_attributes.name) LIKE '%status%' THEN 'allowed occupation status'
                ELSE 'state' -- Default fallback
            END
            LIMIT 1
        );

        -- Set default for any NULL values
        UPDATE silver_professions_attributes
        SET Attribute_type_id = (
            SELECT attribute_type_id
            FROM silver_taxonomies_attribute_types
            WHERE name = 'State'
            LIMIT 1
        )
        WHERE Attribute_type_id IS NULL;

        -- Add foreign key constraint
        ALTER TABLE silver_professions_attributes
        ADD CONSTRAINT fk_silver_professions_attributes_type_id
        FOREIGN KEY (Attribute_type_id) REFERENCES silver_taxonomies_attribute_types(attribute_type_id);

        -- Create index
        CREATE INDEX idx_silver_professions_attributes_type_id ON silver_professions_attributes(Attribute_type_id);
    END IF;
END $$;