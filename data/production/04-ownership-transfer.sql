-- ============================================================================
-- Production Aurora PostgreSQL - Ownership Transfer
-- ============================================================================
-- Description: Transfer ownership of all schema objects to lambda_user
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Tables, indexes, and objects created
-- ============================================================================

-- ============================================================================
-- TRANSFER OWNERSHIP TO LAMBDA_USER
-- ============================================================================
-- Purpose: Ensures lambda_user owns all objects in taxonomy_schema
-- Includes: Tables, views, materialized views, foreign tables, sequences

DO $$
DECLARE r record;
BEGIN
  -- 1) Tables (including partitioned) – also transfers IDENTITY/SERIAL sequences
  FOR r IN
    SELECT format('ALTER TABLE %I.%I OWNER TO lambda_user;', n.nspname, c.relname) AS cmd
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'taxonomy_schema'
      AND c.relkind IN ('r','p')
  LOOP
    EXECUTE r.cmd;
  END LOOP;

  -- 2) Views
  FOR r IN
    SELECT format('ALTER VIEW %I.%I OWNER TO lambda_user;', n.nspname, c.relname) AS cmd
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'taxonomy_schema'
      AND c.relkind = 'v'
  LOOP
    EXECUTE r.cmd;
  END LOOP;

  -- 3) Materialized views
  FOR r IN
    SELECT format('ALTER MATERIALIZED VIEW %I.%I OWNER TO lambda_user;', n.nspname, c.relname) AS cmd
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'taxonomy_schema'
      AND c.relkind = 'm'
  LOOP
    EXECUTE r.cmd;
  END LOOP;

  -- 4) Foreign tables
  FOR r IN
    SELECT format('ALTER FOREIGN TABLE %I.%I OWNER TO lambda_user;', n.nspname, c.relname) AS cmd
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'taxonomy_schema'
      AND c.relkind = 'f'
  LOOP
    EXECUTE r.cmd;
  END LOOP;

  -- 5) Standalone sequences (not SERIAL/IDENTITY)
  --    Excludes sequences with auto (serial) or internal (identity) dependencies
  FOR r IN
    SELECT format('ALTER SEQUENCE %I.%I OWNER TO lambda_user;', n.nspname, c.relname) AS cmd
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'taxonomy_schema'
      AND c.relkind = 'S'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.classid = 'pg_class'::regclass
          AND d.objid   = c.oid
          AND d.deptype IN ('a','i')   -- serial/identity
      )
  LOOP
    EXECUTE r.cmd;
  END LOOP;
END$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check tables ownership
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'taxonomy_schema'
ORDER BY tablename;

-- Check sequences ownership
SELECT
    schemaname,
    sequencename,
    sequenceowner
FROM pg_sequences
WHERE schemaname = 'taxonomy_schema'
ORDER BY sequencename;

-- Check views ownership
SELECT
    schemaname,
    viewname,
    viewowner
FROM pg_views
WHERE schemaname = 'taxonomy_schema'
ORDER BY viewname;

-- Summary count
SELECT
    'Tables' as object_type,
    COUNT(*) as count,
    'lambda_user' as expected_owner
FROM pg_tables
WHERE schemaname = 'taxonomy_schema'
  AND tableowner = 'lambda_user'

UNION ALL

SELECT
    'Sequences',
    COUNT(*),
    'lambda_user'
FROM pg_sequences
WHERE schemaname = 'taxonomy_schema'
  AND sequenceowner = 'lambda_user';

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Why Transfer Ownership:
--   - lambda_user is the primary Lambda execution role
--   - Ensures Lambda has full DDL and DML permissions
--   - taxonomy_user gets permissions via DEFAULT PRIVILEGES
--
-- Objects Transferred:
--   - All tables (including partitioned tables)
--   - All sequences (IDENTITY/SERIAL sequences transfer with tables)
--   - All views (regular and materialized)
--   - All foreign tables
--
-- NOT Transferred:
--   - SERIAL/IDENTITY sequences (transferred automatically with tables)
--
-- ============================================================================
