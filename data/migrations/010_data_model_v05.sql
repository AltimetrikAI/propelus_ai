-- ============================================================================
-- Migration 010: Data Model v0.5 - Comprehensive Audit Logging
-- ============================================================================
-- Date: September 30, 2025
-- Version: 0.5
-- Description: Add comprehensive audit log tables for all Silver and Gold layer entities
--              Based on Marcin's Data Model v0.5 specification
-- ============================================================================

BEGIN;

-- ============================================================================
-- SILVER LAYER AUDIT LOG TABLES
-- ============================================================================

-- 1. Silver Taxonomies Nodes Types Log
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver_taxonomies_nodes_types_log (
    node_type_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name VARCHAR(255)
);

CREATE INDEX idx_silver_nodes_types_log_node_type ON silver_taxonomies_nodes_types_log(node_type_id);
CREATE INDEX idx_silver_nodes_types_log_operation ON silver_taxonomies_nodes_types_log(operation_date DESC);
CREATE INDEX idx_silver_nodes_types_log_user ON silver_taxonomies_nodes_types_log(user_name);

COMMENT ON TABLE silver_taxonomies_nodes_types_log IS 'Audit log for all operations on silver_taxonomies_nodes_types table';
COMMENT ON COLUMN silver_taxonomies_nodes_types_log.old_row IS 'JSONB snapshot of row before change (NULL for insert)';
COMMENT ON COLUMN silver_taxonomies_nodes_types_log.new_row IS 'JSONB snapshot of row after change (NULL for delete)';
COMMENT ON COLUMN silver_taxonomies_nodes_types_log.operation_type IS 'Type of operation: insert, update, or delete';
COMMENT ON COLUMN silver_taxonomies_nodes_types_log.operation_date IS 'Timestamp when operation occurred';
COMMENT ON COLUMN silver_taxonomies_nodes_types_log.user_name IS 'User who performed the operation';

-- 2. Silver Taxonomies Nodes Log
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver_taxonomies_nodes_log (
    node_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name VARCHAR(255)
);

CREATE INDEX idx_silver_nodes_log_node ON silver_taxonomies_nodes_log(node_id);
CREATE INDEX idx_silver_nodes_log_operation ON silver_taxonomies_nodes_log(operation_date DESC);
CREATE INDEX idx_silver_nodes_log_user ON silver_taxonomies_nodes_log(user_name);

COMMENT ON TABLE silver_taxonomies_nodes_log IS 'Audit log for all operations on silver_taxonomies_nodes table';

-- 3. Silver Taxonomies Nodes Attributes Log
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver_taxonomies_nodes_attributes_log (
    node_attribute_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name VARCHAR(255)
);

CREATE INDEX idx_silver_nodes_attr_log_attr ON silver_taxonomies_nodes_attributes_log(node_attribute_id);
CREATE INDEX idx_silver_nodes_attr_log_operation ON silver_taxonomies_nodes_attributes_log(operation_date DESC);
CREATE INDEX idx_silver_nodes_attr_log_user ON silver_taxonomies_nodes_attributes_log(user_name);

COMMENT ON TABLE silver_taxonomies_nodes_attributes_log IS 'Audit log for all operations on silver_taxonomies_nodes_attributes table';

-- 4. Silver Taxonomies Attribute Types Log
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver_taxonomies_attribute_types_log (
    attribute_type_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name VARCHAR(255)
);

CREATE INDEX idx_silver_attr_types_log_type ON silver_taxonomies_attribute_types_log(attribute_type_id);
CREATE INDEX idx_silver_attr_types_log_operation ON silver_taxonomies_attribute_types_log(operation_date DESC);
CREATE INDEX idx_silver_attr_types_log_user ON silver_taxonomies_attribute_types_log(user_name);

COMMENT ON TABLE silver_taxonomies_attribute_types_log IS 'Audit log for all operations on silver_taxonomies_attribute_types table';

-- 5. Silver Mapping Taxonomies Rules Log
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver_mapping_taxonomies_rules_log (
    mapping_rule_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name VARCHAR(255)
);

CREATE INDEX idx_silver_mapping_rules_log_rule ON silver_mapping_taxonomies_rules_log(mapping_rule_id);
CREATE INDEX idx_silver_mapping_rules_log_operation ON silver_mapping_taxonomies_rules_log(operation_date DESC);
CREATE INDEX idx_silver_mapping_rules_log_user ON silver_mapping_taxonomies_rules_log(user_name);

COMMENT ON TABLE silver_mapping_taxonomies_rules_log IS 'Audit log for all operations on silver_mapping_taxonomies_rules table';

-- 6. Silver Mapping Rules Assignment Log
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver_mapping_rules_assignment_log (
    mapping_rule_assignment_id INTEGER NOT NULL,
    old_row JSONB,
    new_row JSONB NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('insert', 'update', 'delete')),
    operation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name VARCHAR(255)
);

CREATE INDEX idx_silver_rules_assignment_log_assignment ON silver_mapping_rules_assignment_log(mapping_rule_assignment_id);
CREATE INDEX idx_silver_rules_assignment_log_operation ON silver_mapping_rules_assignment_log(operation_date DESC);
CREATE INDEX idx_silver_rules_assignment_log_user ON silver_mapping_rules_assignment_log(user_name);

COMMENT ON TABLE silver_mapping_rules_assignment_log IS 'Audit log for all operations on silver_mapping_taxonomies_rules_assignment table';

-- ============================================================================
-- AUDIT TRIGGERS FOR SILVER LAYER TABLES
-- ============================================================================

-- Trigger Function for silver_taxonomies_nodes_types
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_silver_taxonomies_nodes_types()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO silver_taxonomies_nodes_types_log (
            node_type_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.node_type_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO silver_taxonomies_nodes_types_log (
            node_type_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.node_type_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO silver_taxonomies_nodes_types_log (
            node_type_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.node_type_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_audit_silver_taxonomies_nodes_types ON silver_taxonomies_nodes_types;
CREATE TRIGGER trigger_audit_silver_taxonomies_nodes_types
    AFTER INSERT OR UPDATE OR DELETE ON silver_taxonomies_nodes_types
    FOR EACH ROW EXECUTE FUNCTION audit_silver_taxonomies_nodes_types();

-- Trigger Function for silver_taxonomies_nodes
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_silver_taxonomies_nodes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO silver_taxonomies_nodes_log (
            node_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.node_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO silver_taxonomies_nodes_log (
            node_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.node_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO silver_taxonomies_nodes_log (
            node_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.node_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_audit_silver_taxonomies_nodes ON silver_taxonomies_nodes;
CREATE TRIGGER trigger_audit_silver_taxonomies_nodes
    AFTER INSERT OR UPDATE OR DELETE ON silver_taxonomies_nodes
    FOR EACH ROW EXECUTE FUNCTION audit_silver_taxonomies_nodes();

-- Trigger Function for silver_taxonomies_nodes_attributes
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_silver_taxonomies_nodes_attributes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO silver_taxonomies_nodes_attributes_log (
            node_attribute_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.node_attribute_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO silver_taxonomies_nodes_attributes_log (
            node_attribute_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.node_attribute_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO silver_taxonomies_nodes_attributes_log (
            node_attribute_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.node_attribute_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_audit_silver_taxonomies_nodes_attributes ON silver_taxonomies_nodes_attributes;
CREATE TRIGGER trigger_audit_silver_taxonomies_nodes_attributes
    AFTER INSERT OR UPDATE OR DELETE ON silver_taxonomies_nodes_attributes
    FOR EACH ROW EXECUTE FUNCTION audit_silver_taxonomies_nodes_attributes();

-- Trigger Function for silver_taxonomies_attribute_types
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_silver_taxonomies_attribute_types()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO silver_taxonomies_attribute_types_log (
            attribute_type_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.attribute_type_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO silver_taxonomies_attribute_types_log (
            attribute_type_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.attribute_type_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO silver_taxonomies_attribute_types_log (
            attribute_type_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.attribute_type_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_audit_silver_taxonomies_attribute_types ON silver_taxonomies_attribute_types;
CREATE TRIGGER trigger_audit_silver_taxonomies_attribute_types
    AFTER INSERT OR UPDATE OR DELETE ON silver_taxonomies_attribute_types
    FOR EACH ROW EXECUTE FUNCTION audit_silver_taxonomies_attribute_types();

-- Trigger Function for silver_mapping_taxonomies_rules
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_silver_mapping_taxonomies_rules()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO silver_mapping_taxonomies_rules_log (
            mapping_rule_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.mapping_rule_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO silver_mapping_taxonomies_rules_log (
            mapping_rule_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.mapping_rule_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO silver_mapping_taxonomies_rules_log (
            mapping_rule_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.mapping_rule_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_audit_silver_mapping_taxonomies_rules ON silver_mapping_taxonomies_rules;
CREATE TRIGGER trigger_audit_silver_mapping_taxonomies_rules
    AFTER INSERT OR UPDATE OR DELETE ON silver_mapping_taxonomies_rules
    FOR EACH ROW EXECUTE FUNCTION audit_silver_mapping_taxonomies_rules();

-- Trigger Function for silver_mapping_taxonomies_rules_assignment
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_silver_mapping_rules_assignment()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO silver_mapping_rules_assignment_log (
            mapping_rule_assignment_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            OLD.mapping_rule_assignment_id,
            row_to_json(OLD)::jsonb,
            NULL,
            'delete',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO silver_mapping_rules_assignment_log (
            mapping_rule_assignment_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.mapping_rule_assignment_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            'update',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO silver_mapping_rules_assignment_log (
            mapping_rule_assignment_id, old_row, new_row, operation_type, operation_date, user_name
        ) VALUES (
            NEW.mapping_rule_assignment_id,
            NULL,
            row_to_json(NEW)::jsonb,
            'insert',
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_audit_silver_mapping_rules_assignment ON silver_mapping_taxonomies_rules_assignment;
CREATE TRIGGER trigger_audit_silver_mapping_rules_assignment
    AFTER INSERT OR UPDATE OR DELETE ON silver_mapping_taxonomies_rules_assignment
    FOR EACH ROW EXECUTE FUNCTION audit_silver_mapping_rules_assignment();

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify all new log tables were created
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN (
        'silver_taxonomies_nodes_types_log',
        'silver_taxonomies_nodes_log',
        'silver_taxonomies_nodes_attributes_log',
        'silver_taxonomies_attribute_types_log',
        'silver_mapping_taxonomies_rules_log',
        'silver_mapping_rules_assignment_log'
    );

    IF table_count = 6 THEN
        RAISE NOTICE 'SUCCESS: All 6 audit log tables created successfully';
    ELSE
        RAISE EXCEPTION 'FAILURE: Expected 6 audit log tables, found %', table_count;
    END IF;
END $$;

-- Verify all triggers were created
DO $$
DECLARE
    trigger_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
    AND trigger_name IN (
        'trigger_audit_silver_taxonomies_nodes_types',
        'trigger_audit_silver_taxonomies_nodes',
        'trigger_audit_silver_taxonomies_nodes_attributes',
        'trigger_audit_silver_taxonomies_attribute_types',
        'trigger_audit_silver_mapping_taxonomies_rules',
        'trigger_audit_silver_mapping_rules_assignment'
    );

    IF trigger_count = 6 THEN
        RAISE NOTICE 'SUCCESS: All 6 audit triggers created successfully';
    ELSE
        RAISE EXCEPTION 'FAILURE: Expected 6 audit triggers, found %', trigger_count;
    END IF;
END $$;

-- ============================================================================
-- COMMIT TRANSACTION
-- ============================================================================

COMMIT;

-- ============================================================================
-- POST-MIGRATION INFORMATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Migration 010: Data Model v0.5 - COMPLETED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'New Tables Created: 6 audit log tables';
    RAISE NOTICE 'New Triggers Created: 6 automatic audit triggers';
    RAISE NOTICE 'New Indexes Created: 18 indexes for performance';
    RAISE NOTICE '';
    RAISE NOTICE 'Audit Log Tables:';
    RAISE NOTICE '  - silver_taxonomies_nodes_types_log';
    RAISE NOTICE '  - silver_taxonomies_nodes_log';
    RAISE NOTICE '  - silver_taxonomies_nodes_attributes_log';
    RAISE NOTICE '  - silver_taxonomies_attribute_types_log';
    RAISE NOTICE '  - silver_mapping_taxonomies_rules_log';
    RAISE NOTICE '  - silver_mapping_rules_assignment_log';
    RAISE NOTICE '';
    RAISE NOTICE 'All tables now have automatic audit logging enabled.';
    RAISE NOTICE 'Changes are tracked with before/after snapshots in JSONB format.';
    RAISE NOTICE '=============================================================================';
END $$;