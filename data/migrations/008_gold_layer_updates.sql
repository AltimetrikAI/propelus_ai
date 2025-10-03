-- Migration: 008_gold_layer_updates
-- Description: Gold Layer Updates for consistency per Marcin's Data Model v0.42
-- Author: Propelus AI Team - Data Model Update
-- Date: 2025-01-11

-- ============================================================================
-- GOLD LAYER CONSISTENCY UPDATES
-- ============================================================================

-- Update gold_taxonomies_mapping to match silver layer naming
ALTER TABLE gold_taxonomies_mapping
RENAME COLUMN node_id TO child_node_id;

-- Add comments for clarity
COMMENT ON TABLE gold_taxonomies_mapping IS 'Final approved mappings between taxonomies';
COMMENT ON COLUMN gold_taxonomies_mapping.mapping_id IS 'Primary key values taken from silver_mapping_taxonomies';
COMMENT ON COLUMN gold_taxonomies_mapping.master_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in master taxonomy - taken from silver_mapping_taxonomies';
COMMENT ON COLUMN gold_taxonomies_mapping.child_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in child taxonomy - taken from silver_mapping_taxonomies';

-- Update foreign key constraint if it exists
DO $$
BEGIN
    -- Drop old constraint if it exists
    IF EXISTS (SELECT constraint_name FROM information_schema.table_constraints
               WHERE table_name = 'gold_taxonomies_mapping'
               AND constraint_name LIKE '%node_id%') THEN
        ALTER TABLE gold_taxonomies_mapping DROP CONSTRAINT
            (SELECT constraint_name FROM information_schema.table_constraints
             WHERE table_name = 'gold_taxonomies_mapping'
             AND constraint_name LIKE '%node_id%' LIMIT 1);
    END IF;

    -- Add new constraint with updated name
    ALTER TABLE gold_taxonomies_mapping
    ADD CONSTRAINT fk_gold_taxonomies_mapping_child_node_id
    FOREIGN KEY (child_node_id) REFERENCES silver_taxonomies_nodes(node_id);
END $$;

-- ============================================================================
-- UPDATE GOLD_MAPPING_PROFESSIONS TABLE
-- ============================================================================

-- Update gold_mapping_professions to match naming convention if column exists
DO $$
BEGIN
    IF EXISTS (SELECT column_name FROM information_schema.columns
               WHERE table_name = 'gold_mapping_professions'
               AND column_name = 'node_id') THEN
        ALTER TABLE gold_mapping_professions
        RENAME COLUMN node_id TO child_node_id;

        -- Update comments
        COMMENT ON COLUMN gold_mapping_professions.child_node_id IS 'Foreign key to silver_taxonomies_nodes indicates the node in child taxonomy';

        -- Update foreign key constraint
        IF EXISTS (SELECT constraint_name FROM information_schema.table_constraints
                   WHERE table_name = 'gold_mapping_professions'
                   AND constraint_name LIKE '%node_id%') THEN
            ALTER TABLE gold_mapping_professions DROP CONSTRAINT
                (SELECT constraint_name FROM information_schema.table_constraints
                 WHERE table_name = 'gold_mapping_professions'
                 AND constraint_name LIKE '%node_id%' LIMIT 1);
        END IF;

        ALTER TABLE gold_mapping_professions
        ADD CONSTRAINT fk_gold_mapping_professions_child_node_id
        FOREIGN KEY (child_node_id) REFERENCES silver_taxonomies_nodes(node_id);
    END IF;
END $$;

-- ============================================================================
-- CREATE AUDIT LOG TABLES FOR GOLD LAYER (ENHANCED LOGGING)
-- ============================================================================

-- Create gold_mapping_taxonomies_log for audit trail
CREATE TABLE gold_mapping_taxonomies_log (
    log_id SERIAL PRIMARY KEY,
    mapping_id INTEGER,
    old_row JSONB,
    new_row JSONB,
    operation_type VARCHAR(20) CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP DEFAULT NOW(),
    user_name VARCHAR(255)
);

-- Add comments
COMMENT ON TABLE gold_mapping_taxonomies_log IS 'Audit trail for changes to gold_taxonomies_mapping table';
COMMENT ON COLUMN gold_mapping_taxonomies_log.mapping_id IS 'Primary key of affected row from gold_taxonomies_mapping table';
COMMENT ON COLUMN gold_mapping_taxonomies_log.old_row IS 'Snapshot of the row before the change (serialized record, null for insert operation)';
COMMENT ON COLUMN gold_mapping_taxonomies_log.new_row IS 'Snapshot of the row after the change (serialized record)';
COMMENT ON COLUMN gold_mapping_taxonomies_log.operation_type IS 'Type of row change — insert, update, or delete';
COMMENT ON COLUMN gold_mapping_taxonomies_log.operation_date IS 'Timestamp when the operation occurred';
COMMENT ON COLUMN gold_mapping_taxonomies_log.user_name IS 'User that performed the operation (can be technical user too)';

-- Create indexes for performance
CREATE INDEX idx_gold_mapping_log_mapping_id ON gold_mapping_taxonomies_log(mapping_id);
CREATE INDEX idx_gold_mapping_log_operation_date ON gold_mapping_taxonomies_log(operation_date DESC);
CREATE INDEX idx_gold_mapping_log_user ON gold_mapping_taxonomies_log(user_name);

-- ============================================================================
-- CREATE AUDIT TRIGGER FOR GOLD_TAXONOMIES_MAPPING
-- ============================================================================

-- Create audit trigger function for gold layer
CREATE OR REPLACE FUNCTION audit_gold_mapping_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO gold_mapping_taxonomies_log (
            mapping_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.mapping_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            NOW(),
            COALESCE(current_setting('application_name', true), 'system')
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO gold_mapping_taxonomies_log (
            mapping_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.mapping_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            NOW(),
            COALESCE(current_setting('application_name', true), 'system')
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO gold_mapping_taxonomies_log (
            mapping_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.mapping_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            NOW(),
            COALESCE(current_setting('application_name', true), 'system')
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS audit_gold_taxonomies_mapping ON gold_taxonomies_mapping;
CREATE TRIGGER audit_gold_taxonomies_mapping
    AFTER INSERT OR UPDATE OR DELETE ON gold_taxonomies_mapping
    FOR EACH ROW EXECUTE FUNCTION audit_gold_mapping_changes();

-- ============================================================================
-- ADDITIONAL AUDIT TABLES FOR COMPREHENSIVE LOGGING
-- ============================================================================

-- Create audit tables for other gold layer tables if they exist
DO $$
DECLARE
    table_name TEXT;
    log_table_name TEXT;
    trigger_func_name TEXT;
    trigger_name TEXT;
BEGIN
    FOR table_name IN
        SELECT tablename
        FROM pg_tables
        WHERE tablename LIKE 'gold_%'
        AND tablename NOT LIKE '%_log'
        AND tablename != 'gold_taxonomies_mapping'
        AND schemaname = 'public'
    LOOP
        log_table_name := table_name || '_log';
        trigger_func_name := 'audit_' || table_name || '_changes';
        trigger_name := 'audit_' || table_name;

        -- Create log table
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I (
                log_id SERIAL PRIMARY KEY,
                record_id INTEGER,
                old_row JSONB,
                new_row JSONB,
                operation_type VARCHAR(20) CHECK (operation_type IN (''insert'', ''update'', ''delete'')),
                operation_date TIMESTAMP DEFAULT NOW(),
                user_name VARCHAR(255)
            )', log_table_name);

        -- Create indexes
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_record_id ON %I(record_id)',
                      replace(log_table_name, '_', ''), log_table_name);
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_operation_date ON %I(operation_date DESC)',
                      replace(log_table_name, '_', ''), log_table_name);
    END LOOP;
END $$;

-- ============================================================================
-- UPDATE EXISTING GOLD DATA TO REFLECT SILVER CHANGES
-- ============================================================================

-- Update any existing gold mappings to ensure they reference valid silver nodes
-- This is a safety check to maintain referential integrity
DO $$
BEGIN
    -- Check if there are any gold mappings with invalid references after column rename
    IF EXISTS (SELECT 1 FROM gold_taxonomies_mapping
               WHERE NOT EXISTS (
                   SELECT 1 FROM silver_taxonomies_nodes stn
                   WHERE stn.node_id = gold_taxonomies_mapping.child_node_id
               )) THEN

        -- Log the issue but don't fail the migration
        RAISE NOTICE 'Found gold mappings with invalid child_node_id references. These may need manual review.';

        -- Optionally, you could delete invalid mappings:
        -- DELETE FROM gold_taxonomies_mapping
        -- WHERE NOT EXISTS (
        --     SELECT 1 FROM silver_taxonomies_nodes stn
        --     WHERE stn.node_id = gold_taxonomies_mapping.child_node_id
        -- );
    END IF;
END $$;

-- ============================================================================
-- PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Create additional indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_gold_taxonomies_mapping_master_child
ON gold_taxonomies_mapping(master_node_id, child_node_id);

CREATE INDEX IF NOT EXISTS idx_gold_taxonomies_mapping_created_at
ON gold_taxonomies_mapping(created_at DESC);

-- Update table statistics for better query planning
ANALYZE gold_taxonomies_mapping;
ANALYZE gold_mapping_taxonomies_log;