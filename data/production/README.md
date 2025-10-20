# Production Aurora PostgreSQL Setup

## Overview

This directory contains production-ready database setup scripts for the Propelus AI Taxonomy Framework on Aurora PostgreSQL 15+.

## Prerequisites

- **Aurora PostgreSQL 15+** cluster provisioned
- **AWS CLI** configured with appropriate IAM permissions
- **psql** client installed
- Database endpoint and credentials available

## Execution Order

Run the scripts in the following order:

### 1. Setup Roles and Permissions
```bash
psql -h <aurora-endpoint> -U postgres -d postgres -f 01-setup-roles.sql
```
Creates:
- `lambda_user` role (IAM-enabled, database owner)
- `taxonomy_user` role (IAM-enabled, read/write access)
- `taxonomy` database
- `taxonomy_schema` schema

### 2. Install Extensions
```bash
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 02-extensions.sql
```
Installs:
- `pg_trgm` - Trigram text search
- `pgcrypto` - Cryptographic functions

### 3. Create Tables
```bash
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f production-ddl.sql
```
Creates all tables:
- Bronze layer (load_details, taxonomies)
- Silver layer (taxonomies, nodes, attributes, mappings, versions)
- Gold layer (mapping_taxonomies)
- All audit log tables

### 4. Create Indexes (Performance Critical)
```bash
# Bronze layer indexes
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 05-indexes-bronze.sql

# Silver core indexes
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 06-indexes-silver-core.sql

# Silver mapping indexes
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 07-indexes-silver-mapping.sql

# Silver versioning indexes
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 08-indexes-silver-versioning.sql

# Gold layer indexes
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 09-indexes-gold.sql

# Audit log indexes
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 10-indexes-logs.sql
```
Creates 200+ performance indexes:
- GIN indexes for JSONB and trigram search
- BRIN indexes for timestamp columns
- B-tree indexes for foreign keys and lookups

### 5. Seed N/A Node
```bash
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 03-seed-na-node.sql
```
Inserts special N/A node type (ID: -1) for hierarchy gap handling.

### 6. Transfer Ownership
```bash
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 04-ownership-transfer.sql
```
Transfers ownership of all objects to `lambda_user`.

## Complete Setup Script

For convenience, run all scripts in order:

```bash
#!/bin/bash
AURORA_ENDPOINT="<your-aurora-endpoint>"
POSTGRES_USER="postgres"
LAMBDA_USER="lambda_user"

echo "1. Setting up roles..."
psql -h $AURORA_ENDPOINT -U $POSTGRES_USER -d postgres -f 01-setup-roles.sql

echo "2. Installing extensions..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 02-extensions.sql

echo "3. Creating tables..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f production-ddl.sql

echo "4. Creating bronze indexes..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 05-indexes-bronze.sql

echo "5. Creating silver core indexes..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 06-indexes-silver-core.sql

echo "6. Creating silver mapping indexes..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 07-indexes-silver-mapping.sql

echo "7. Creating silver versioning indexes..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 08-indexes-silver-versioning.sql

echo "8. Creating gold indexes..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 09-indexes-gold.sql

echo "9. Creating log indexes..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 10-indexes-logs.sql

echo "10. Seeding N/A node..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 03-seed-na-node.sql

echo "11. Transferring ownership..."
psql -h $AURORA_ENDPOINT -U $LAMBDA_USER -d taxonomy -f 04-ownership-transfer.sql

echo "Setup complete!"
```

## Files Summary

| File | Purpose | Objects Created |
|------|---------|----------------|
| 01-setup-roles.sql | Roles and database | 2 roles, 1 database, 1 schema |
| 02-extensions.sql | PostgreSQL extensions | 2 extensions |
| production-ddl.sql | All table definitions | 30+ tables |
| 05-indexes-bronze.sql | Bronze layer indexes | 17 indexes |
| 06-indexes-silver-core.sql | Silver core indexes | 54 indexes |
| 07-indexes-silver-mapping.sql | Mapping indexes | 25 indexes |
| 08-indexes-silver-versioning.sql | Versioning indexes | 26 indexes |
| 09-indexes-gold.sql | Gold layer indexes | 5 indexes |
| 10-indexes-logs.sql | Audit log indexes | 73 indexes |
| 03-seed-na-node.sql | N/A node insertion | 1 record |
| 04-ownership-transfer.sql | Ownership transfer | All objects |

## Verification

After setup, verify the installation:

```sql
-- Connect to taxonomy database
\c taxonomy

-- Check extensions
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pg_trgm', 'pgcrypto');

-- Check tables count (should be 30+)
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'taxonomy_schema';

-- Check indexes count (should be 200+)
SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'taxonomy_schema';

-- Check N/A node exists
SELECT * FROM silver_taxonomies_nodes_types WHERE node_type_id = -1;

-- Check ownership
SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname = 'taxonomy_schema'
LIMIT 5;
```

## IAM Authentication

Lambda functions connect using IAM authentication:

```bash
# Generate IAM auth token
aws rds generate-db-auth-token \
  --hostname <aurora-endpoint> \
  --port 5432 \
  --username lambda_user \
  --region us-east-1
```

Lambda environment variables:
```bash
PGHOST=<aurora-endpoint>
PGPORT=5432
PGDATABASE=taxonomy
PGSCHEMA=taxonomy_schema
PGUSER=lambda_user
PGSSLMODE=require
```

## Maintenance

### Reindex
```sql
REINDEX SCHEMA taxonomy_schema;
```

### Analyze Tables
```sql
ANALYZE;
```

### Check Index Usage
```sql
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'taxonomy_schema'
ORDER BY idx_scan DESC;
```

## Troubleshooting

### Connection Issues
```bash
# Test connection
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -c "SELECT 1;"
```

### IAM Authentication Issues
```bash
# Verify IAM role membership
SELECT r.rolname, m.rolname as member_of
FROM pg_roles r
LEFT JOIN pg_auth_members am ON r.oid = am.member
LEFT JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolname = 'lambda_user';
```

### Missing Indexes
```sql
-- Find missing indexes on foreign keys
SELECT
    c.conrelid::regclass AS table,
    string_agg(a.attname, ', ') AS columns
FROM pg_constraint c
JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid
    AND i.indkey::int[] @> c.conkey::int[]
  )
GROUP BY c.conrelid;
```

## Support

For issues or questions:
- Check CloudWatch Logs for Lambda errors
- Review Aurora Performance Insights
- Verify IAM permissions and policies
- See main project README.md for architecture details

---

**Last Updated**: January 26, 2025
**Version**: 1.0.0
**Environment**: Aurora PostgreSQL 15+
**Status**: Production-Ready
