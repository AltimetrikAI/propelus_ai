# Database Migrations - N/A Node Implementation

## Overview

These migrations implement Martin's N/A placeholder node approach for handling variable-depth taxonomy hierarchies.

## Migration Files

### 001-create-na-node-type.sql
**Purpose**: Creates the N/A node type and performance indexes

**Changes**:
- Inserts N/A node type with `node_type_id = -1`
- Creates partial index for filtering N/A nodes
- Creates index for finding N/A nodes quickly
- Adds documentation comments

**Run Time**: ~1 second

---

### 002-create-hierarchy-helper-functions.sql
**Purpose**: Creates SQL functions for N/A-aware hierarchy operations

**Functions Created**:
1. `get_node_full_path(node_id)` - Full path including N/A
2. `get_node_display_path(node_id)` - Display path excluding N/A
3. `get_active_children(parent_node_id)` - Child nodes excluding N/A
4. `get_node_ancestors(node_id)` - Ancestor nodes excluding N/A
5. `is_na_node(node_id)` - Check if node is N/A
6. `count_na_nodes_in_path(node_id)` - Count N/A nodes in path
7. `get_node_path_with_levels(node_id)` - Path with level indicators

**Run Time**: ~2 seconds

---

## How to Run Migrations

### Option 1: Using psql (Recommended)

```bash
# Set environment variables
export PGHOST=your-aurora-host.amazonaws.com
export PGPORT=5432
export PGDATABASE=propelus_taxonomy
export PGUSER=propelus_admin
export PGPASSWORD=your_password

# Run migrations in order
psql -f scripts/migrations/001-create-na-node-type.sql
psql -f scripts/migrations/002-create-hierarchy-helper-functions.sql
```

### Option 2: Using Node.js Script

```bash
# Create .env file with database credentials
cat > .env << EOF
DB_HOST=your-aurora-host.amazonaws.com
DB_PORT=5432
DB_NAME=propelus_taxonomy
DB_USER=propelus_admin
DB_PASSWORD=your_password
EOF

# Run migration script (to be created)
npm run migrate
```

### Option 3: Using AWS CLI (for Aurora)

```bash
# Execute directly on Aurora cluster
aws rds-data execute-statement \
  --resource-arn "arn:aws:rds:us-east-1:123456789:cluster:propelus-taxonomy" \
  --secret-arn "arn:aws:secretsmanager:us-east-1:123456789:secret:db-creds" \
  --database "propelus_taxonomy" \
  --sql "$(cat scripts/migrations/001-create-na-node-type.sql)"
```

---

## Verification

After running migrations, verify they succeeded:

```sql
-- Check N/A node type exists
SELECT * FROM silver_taxonomies_nodes_types WHERE node_type_id = -1;
-- Expected: 1 row with name = 'N/A'

-- Check indexes exist
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname IN ('idx_nodes_exclude_na', 'idx_nodes_na_only');
-- Expected: 2 rows

-- Check functions exist
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%node%';
-- Expected: 7 functions

-- Test a function
SELECT get_node_display_path(1);
-- Should return a text path or NULL if node doesn't exist
```

---

## Rollback

If you need to rollback these migrations:

```bash
# Rollback migration 002 (functions)
psql -c "
DROP FUNCTION IF EXISTS get_node_full_path(BIGINT);
DROP FUNCTION IF EXISTS get_node_display_path(BIGINT);
DROP FUNCTION IF EXISTS get_active_children(BIGINT);
DROP FUNCTION IF EXISTS get_node_ancestors(BIGINT);
DROP FUNCTION IF EXISTS is_na_node(BIGINT);
DROP FUNCTION IF EXISTS count_na_nodes_in_path(BIGINT);
DROP FUNCTION IF EXISTS get_node_path_with_levels(BIGINT);
"

# Rollback migration 001 (N/A node type)
psql -c "
DELETE FROM silver_taxonomies_nodes_types WHERE node_type_id = -1;
DROP INDEX IF EXISTS idx_nodes_exclude_na;
DROP INDEX IF EXISTS idx_nodes_na_only;
"
```

---

## Troubleshooting

### Error: "relation does not exist"
**Cause**: Running migrations before tables are created
**Solution**: Ensure main DDL schema is applied first

### Error: "duplicate key value violates unique constraint"
**Cause**: N/A node type already exists
**Solution**: Normal - migration uses `ON CONFLICT DO UPDATE`

### Error: "function already exists"
**Cause**: Functions already created
**Solution**: Normal - migration uses `CREATE OR REPLACE`

### Slow Performance
**Cause**: Missing base indexes on taxonomy tables
**Solution**: Ensure Martin's main DDL indexes are created

---

## Testing

After migrations, run the test script:

```bash
npm run test:na-nodes
```

This will:
1. Create test taxonomy nodes with N/A gaps
2. Verify N/A nodes are created correctly
3. Test all helper functions
4. Validate display vs. full path behavior

---

## Next Steps

After completing these migrations:

1. ✅ Run Phase 2: Create shared utilities (NANodeHandler, HierarchyQueries)
2. ✅ Run Phase 3: Update Lambda functions
3. ✅ Run Phase 4: Execute tests
4. ✅ Run Phase 5: Update documentation

---

## Notes

- These migrations are **idempotent** - safe to run multiple times
- N/A nodes are **automatically** created by NANodeHandler class
- Never create N/A nodes manually - always use NANodeHandler
- Always filter `node_type_id != -1` in display/UI queries

---

## Reference

- **Decision**: Meeting transcript Oct 8, 2024
- **Data Engineer**: Martin
- **Implementation**: Phase 1 of N/A Node Implementation Plan
