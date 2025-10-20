-- ============================================================================
-- Production Aurora PostgreSQL - Database Roles Setup
-- ============================================================================
-- Description: Creates IAM-enabled roles for Lambda and application access
-- Environment: Aurora PostgreSQL 15+
-- ============================================================================

-- ============================================================================
-- CREATE LAMBDA USER ROLE (Primary Lambda execution role)
-- ============================================================================

CREATE ROLE lambda_user LOGIN;

-- Enable IAM authentication for lambda_user
GRANT rds_iam TO lambda_user;

-- Allow postgres to manage lambda_user
GRANT lambda_user TO postgres;

-- ============================================================================
-- CREATE DATABASE WITH LAMBDA_USER AS OWNER
-- ============================================================================

CREATE DATABASE taxonomy OWNER lambda_user;

-- ============================================================================
-- CONNECT TO TAXONOMY DATABASE TO CREATE SCHEMA
-- ============================================================================
-- Note: Execute the following commands after connecting to the taxonomy database
-- \c taxonomy

-- Create taxonomy_schema owned by lambda_user
CREATE SCHEMA taxonomy_schema AUTHORIZATION lambda_user;

-- ============================================================================
-- SECURITY: REVOKE PUBLIC ACCESS
-- ============================================================================

-- Remove default public access to database
REVOKE ALL ON DATABASE taxonomy FROM PUBLIC;

-- Remove default schema creation rights for public users
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- ============================================================================
-- SET DEFAULT SEARCH PATH
-- ============================================================================

-- Set search_path for all connections to prioritize taxonomy_schema
ALTER DATABASE taxonomy SET search_path = taxonomy_schema, public;

-- ============================================================================
-- CREATE APPLICATION USER ROLE (Read/Write access)
-- ============================================================================

CREATE ROLE taxonomy_user LOGIN;

-- Enable IAM authentication for taxonomy_user
GRANT rds_iam TO taxonomy_user;

-- ============================================================================
-- GRANT TAXONOMY_USER PERMISSIONS
-- ============================================================================

-- Allow connection to taxonomy database
GRANT CONNECT ON DATABASE taxonomy TO taxonomy_user;

-- Allow usage of taxonomy_schema
GRANT USAGE ON SCHEMA taxonomy_schema TO taxonomy_user;

-- Grant table-level permissions (SELECT, INSERT, UPDATE, DELETE)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA taxonomy_schema TO taxonomy_user;

-- Grant sequence permissions (for IDENTITY/SERIAL columns)
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA taxonomy_schema TO taxonomy_user;

-- ============================================================================
-- SET DEFAULT PRIVILEGES FOR FUTURE OBJECTS
-- ============================================================================

-- Automatically grant permissions to taxonomy_user for new tables created by lambda_user
ALTER DEFAULT PRIVILEGES FOR ROLE lambda_user IN SCHEMA taxonomy_schema
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO taxonomy_user;

-- Automatically grant sequence permissions for new sequences
ALTER DEFAULT PRIVILEGES FOR ROLE lambda_user IN SCHEMA taxonomy_schema
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO taxonomy_user;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check roles created
SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname IN ('lambda_user', 'taxonomy_user');

-- Check IAM authentication enabled
SELECT r.rolname, m.rolname as member_of
FROM pg_roles r
LEFT JOIN pg_auth_members am ON r.oid = am.member
LEFT JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolname IN ('lambda_user', 'taxonomy_user')
  AND m.rolname = 'rds_iam';

-- Check database ownership
SELECT datname, pg_catalog.pg_get_userbyid(datdba) as owner
FROM pg_database
WHERE datname = 'taxonomy';

-- Check schema ownership
SELECT nspname, pg_catalog.pg_get_userbyid(nspowner) as owner
FROM pg_namespace
WHERE nspname = 'taxonomy_schema';

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Lambda Connection String (IAM):
--   Host: <aurora-cluster-endpoint>
--   Port: 5432
--   Database: taxonomy
--   User: lambda_user
--   SSL Mode: require
--   Auth: IAM (generate token using AWS SDK)
--
-- Application Connection String (IAM):
--   Host: <aurora-cluster-endpoint>
--   Port: 5432
--   Database: taxonomy
--   User: taxonomy_user
--   SSL Mode: require
--   Auth: IAM (generate token using AWS SDK)
--
-- Search Path:
--   Automatically set to: taxonomy_schema, public
--   All queries default to taxonomy_schema unless schema is explicitly specified
--
-- ============================================================================
