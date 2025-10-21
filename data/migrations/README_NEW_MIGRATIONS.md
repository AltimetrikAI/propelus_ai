# Database Schema Updates - Migrations 013-026

## Overview

This document describes the database migrations created to implement the data engineer's updated specification for the Propelus AI Taxonomy Framework.

## Migration Files Created

### Bronze Layer Updates
- **013_bronze_load_details_updates.sql** - Adds load tracking columns (load_start, load_end, load_status, load_active, load_type, taxonomy_type)
- **014_bronze_taxonomies_updates.sql** - Adds row-level tracking (row_id PK, load_id FK, taxonomy_id, row_load_status, row_active)

### Silver Layer - Core Tables
- **015_silver_taxonomies_updates.sql** - Adds load_id foreign key
- **016_silver_nodes_types_updates.sql** - Adds load_id foreign key
- **017_silver_nodes_updates.sql** - Adds profession, level, status, load_id, row_id columns
- **018_silver_attribute_types_updates.sql** - Adds load_id foreign key
- **019_silver_nodes_attributes_updates.sql** - Renames columns, adds attribute_type_id FK, status, load_id, row_id

### Silver Layer - Versioning
- **020_create_silver_taxonomies_versions.sql** - Creates taxonomy version tracking table
- **021_create_silver_mapping_taxonomies_versions.sql** - Creates mapping version tracking table

### Silver Layer - Mapping Rules
- **022_silver_mapping_rules_updates.sql** - Adds command, AI_mapping_flag, Human_mapping_flag columns
- **023_silver_mapping_taxonomies_updates.sql** - Adds user column, creates detailed view
- **025_add_confidence_column.sql** - Adds confidence score column (0-100) for mapping quality tracking

### Gold Layer
- **024_create_gold_mapping_taxonomies.sql** - Creates Gold mapping table with sync views and functions

### Customer Identifier Updates (January 21, 2025)
- **026_customer_id_to_varchar.sql** - Changes customer_id from BIGINT to VARCHAR(255) to support subsystem identifiers (e.g., "evercheck-719", "datasolutions-123")

## Execution Order

**IMPORTANT**: Run migrations in numerical order (013 through 026)

```bash
# From the project root
cd /Users/douglasmartins/Propelus_AI

# Run each migration in order
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/013_bronze_load_details_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/014_bronze_taxonomies_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/015_silver_taxonomies_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/016_silver_nodes_types_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/017_silver_nodes_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/018_silver_attribute_types_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/019_silver_nodes_attributes_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/020_create_silver_taxonomies_versions.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/021_create_silver_mapping_taxonomies_versions.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/022_silver_mapping_rules_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/023_silver_mapping_taxonomies_updates.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/024_create_gold_mapping_taxonomies.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/025_add_confidence_column.sql
psql -h localhost -U propelus_admin -d propelus_taxonomy -f data/migrations/026_customer_id_to_varchar.sql
```

## Key Changes Summary

### 1. Load Tracking Enhancement
- Every load now tracked with start/end times and status
- Row-level status tracking in bronze_taxonomies
- Active/inactive flags for data lifecycle management

### 2. Versioning System
- `silver_taxonomies_versions` tracks taxonomy evolution
- `silver_mapping_taxonomies_versions` tracks mapping changes
- Supports remapping workflows when taxonomies update

### 3. Enhanced Lineage
- All Silver tables now link back to bronze_load_details via load_id
- Silver nodes and attributes link to specific bronze rows via row_id
- Complete audit trail from raw data to final mappings

### 4. Mapping Rule Improvements
- `command` column specifies execution method (regex, equals, AI, Human)
- `AI_mapping_flag` and `Human_mapping_flag` for rule categorization
- `user` column in mappings tracks human approvals

### 5. Gold Layer Table
- New `gold_mapping_taxonomies` table for production mappings
- Only contains active, non-AI approved mappings
- Helper views and sync function for maintenance

## Verification

After running all migrations, verify with:

```sql
-- Check all new tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'silver_taxonomies_versions',
    'silver_mapping_taxonomies_versions',
    'gold_mapping_taxonomies'
)
ORDER BY table_name;

-- Check key columns were added
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name IN (
    'bronze_load_details',
    'bronze_taxonomies',
    'silver_taxonomies_nodes'
)
AND column_name IN (
    'load_status',
    'row_id',
    'profession',
    'level'
)
ORDER BY table_name, column_name;
```

## Rollback

Each migration is wrapped in a transaction (BEGIN/COMMIT). If a migration fails, it will automatically rollback.

To manually rollback specific migrations, rollback scripts would need to be created (not included in this release).

## Dependencies

These migrations assume:
1. Migrations 001-012 have been successfully applied
2. PostgreSQL 15+ is being used
3. User has CREATE TABLE and ALTER TABLE privileges

## Next Steps

After running migrations:
1. Update TypeScript type definitions to match new schema
2. Implement Lambda function for Translation Constant Command Logic
3. Update existing Lambda functions to populate new columns
4. Create seed data for mapping rules
5. Test versioning workflows

## Support

For issues or questions:
- Data Engineering: Marcin (algorithm owner)
- Backend Development: Douglas Martins
- Database: Check migration verification output for specific errors
