# Database Schema Changes Summary

## Date: January 26, 2025
## Version: Data Model Update per Engineer Specification

---

## Table-by-Table Changes

### Bronze Layer

#### bronze_load_details
**Migration**: 013_bronze_load_details_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| load_start | TIMESTAMP | ✅ Added | When load started |
| load_end | TIMESTAMP | ✅ Added | When load ended |
| load_status | VARCHAR(50) | ✅ Added | Status: completed, partially completed, failed, in progress |
| load_active | BOOLEAN | ✅ Added | Flag if data is active (default: true) |
| load_type | VARCHAR(20) | ✅ Added | Type: new or update |
| taxonomy_type | VARCHAR(20) | ✅ Added | Type: master or customer |

**Indexes Added**: 6 new indexes
**Constraints Added**: 3 check constraints

---

#### bronze_taxonomies
**Migration**: 014_bronze_taxonomies_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| row_id | SERIAL | ✅ Added | Primary key |
| load_id | INTEGER | ✅ Added | FK to bronze_load_details |
| taxonomy_id | INTEGER | ✅ Added | Identifier of related taxonomy |
| row_load_status | VARCHAR(50) | ✅ Added | Status: completed, in progress, failed |
| row_active | BOOLEAN | ✅ Added | Flag if row data is active |

**Indexes Added**: 5 new indexes
**Constraints Added**: 1 FK, 1 CHECK

---

### Silver Layer - Core Tables

#### silver_taxonomies
**Migration**: 015_silver_taxonomies_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| load_id | INTEGER | ✅ Added | FK to bronze_load_details (last load) |

**Indexes Added**: 1 new index
**Constraints Added**: 1 FK

---

#### silver_taxonomies_nodes_types
**Migration**: 016_silver_nodes_types_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| load_id | INTEGER | ✅ Added | FK to bronze_load_details |

**Indexes Added**: 1 new index
**Constraints Added**: 1 FK

---

#### silver_taxonomies_nodes
**Migration**: 017_silver_nodes_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| profession | VARCHAR(500) | ✅ Added | Name of profession connected to node |
| level | INTEGER | ✅ Added | Hierarchy level (0 for root) |
| status | VARCHAR(20) | ✅ Added | Active or inactive |
| load_id | INTEGER | ✅ Added | FK to bronze_load_details |
| row_id | INTEGER | ✅ Added | FK to bronze_taxonomies |

**Indexes Added**: 7 new indexes
**Constraints Added**: 2 FK, 2 CHECK

---

#### silver_taxonomies_attribute_types
**Migration**: 018_silver_attribute_types_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| load_id | INTEGER | ✅ Added | FK to bronze_load_details |

**Indexes Added**: 1 new index
**Constraints Added**: 1 FK

---

#### silver_taxonomies_nodes_attributes
**Migration**: 019_silver_nodes_attributes_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| node_attribute_type_id | INTEGER | ✏️ Renamed | Primary key (was attribute_id) |
| attribute_type_id | INTEGER | ✅ Added | FK to silver_taxonomies_attribute_types |
| status | VARCHAR(20) | ✅ Added | Active or inactive |
| load_id | INTEGER | ✅ Added | FK to bronze_load_details |
| row_id | INTEGER | ✅ Added | FK to bronze_taxonomies |

**Indexes Added**: 6 new indexes
**Constraints Added**: 3 FK, 1 CHECK

---

### Silver Layer - Versioning Tables

#### silver_taxonomies_versions
**Migration**: 020_create_silver_taxonomies_versions.sql

**NEW TABLE** - Tracks taxonomy version history

| Column | Type | Description |
|--------|------|-------------|
| taxonomy_version_id | SERIAL | Primary key |
| taxonomy_id | INTEGER | FK to silver_taxonomies |
| taxonomy_version_number | INTEGER | Sequential version number |
| change_type | VARCHAR(100) | Type of change (nodes added, deleted, etc) |
| affected_nodes | JSONB | Nodes impacted by change |
| affected_attributes | JSONB | Attributes impacted by change |
| remapping_flag | BOOLEAN | Whether remapping required |
| remapping_reason | TEXT | Why remapping needed |
| total_mappings_processed | INTEGER | Total processed during update |
| total_mappings_changed | INTEGER | Mappings modified |
| total_mappings_unchanged | INTEGER | Mappings unaffected |
| total_mappings_failed | INTEGER | Mappings that failed |
| total_mappings_new | INTEGER | New mappings created |
| remapping_proces_status | VARCHAR(50) | Status: in progress, completed, failed |
| version_notes | TEXT | Free-text notes |
| version_from_date | TIMESTAMP | When version became effective |
| version_to_date | TIMESTAMP | When superseded (NULL if current) |
| created_at | TIMESTAMP | Created timestamp |
| last_updated_at | TIMESTAMP | Updated timestamp |
| load_id | INTEGER | FK to bronze_load_details |

**Indexes Added**: 8 indexes + 1 unique constraint
**Constraints Added**: 2 FK, 3 CHECK
**Triggers**: 1 auto-update trigger

---

#### silver_mapping_taxonomies_versions
**Migration**: 021_create_silver_mapping_taxonomies_versions.sql

**NEW TABLE** - Tracks mapping version history

| Column | Type | Description |
|--------|------|-------------|
| mapping_version_id | SERIAL | Primary key |
| mapping_id | INTEGER | FK to silver_mapping_taxonomies |
| mapping_version_number | INTEGER | Sequential version number |
| version_from_date | TIMESTAMP | When version became effective |
| version_to_date | TIMESTAMP | When superseded (NULL if current) |
| superseded_by_mapping_id | INTEGER | FK to replacing mapping |
| superseded_at | TIMESTAMP | When superseded |
| created_at | TIMESTAMP | Created timestamp |
| last_updated_at | TIMESTAMP | Updated timestamp |

**Indexes Added**: 7 indexes + 1 unique constraint
**Constraints Added**: 2 FK, 3 CHECK
**Triggers**: 1 auto-update trigger

---

### Silver Layer - Mapping Rules

#### silver_mapping_taxonomies_rules
**Migration**: 022_silver_mapping_rules_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| command | VARCHAR(100) | ✅ Added | Command executed (regex, AI, Human, etc) |
| AI_mapping_flag | BOOLEAN | ✅ Added | If connected to AI mappings |
| Human_mapping_flag | BOOLEAN | ✅ Added | If connected to Human mappings |

**Indexes Added**: 4 new indexes

---

#### silver_mapping_taxonomies
**Migration**: 023_silver_mapping_taxonomies_updates.sql

| Column | Type | Added/Modified | Description |
|--------|------|----------------|-------------|
| user | VARCHAR(255) | ✅ Added | User responsible for mapping |

**Indexes Added**: 1 new index
**Views Created**: 1 detailed view (v_silver_mapping_taxonomies_detailed)

---

### Gold Layer

#### gold_mapping_taxonomies
**Migration**: 024_create_gold_mapping_taxonomies.sql

**NEW TABLE** - Final approved mappings

| Column | Type | Description |
|--------|------|-------------|
| mapping_id | INTEGER | Primary key from silver_mapping_taxonomies |
| master_node_id | INTEGER | FK to master node |
| child_node_id | INTEGER | FK to child node |
| created_at | TIMESTAMP | Created timestamp |
| last_updated_at | TIMESTAMP | Updated timestamp |

**Indexes Added**: 5 indexes
**Constraints Added**: 3 FK
**Triggers**: 1 auto-update trigger
**Views Created**: 2 helper views (sync_candidates, orphaned_mappings)
**Functions Created**: 1 sync function (sync_gold_mapping_taxonomies)

---

## Total Statistics

### Tables
- **Existing tables updated**: 9
- **New tables created**: 3
- **Total tables affected**: 12

### Columns
- **New columns added**: 35+
- **Columns renamed**: 1
- **Total changes**: 36+

### Indexes
- **New indexes created**: 40+
- **Unique constraints**: 2

### Constraints
- **Foreign keys added**: 15+
- **Check constraints**: 10+

### Database Objects
- **Triggers created**: 3
- **Views created**: 3
- **Functions created**: 4

---

## Key Features Enabled

### 1. Complete Load Tracking
✅ Start/end timestamps for every load
✅ Status tracking at load and row level
✅ Active/inactive flags for data lifecycle

### 2. Full Data Lineage
✅ Every Silver record traces to Bronze load
✅ Every Silver node/attribute traces to Bronze row
✅ Complete audit trail

### 3. Versioning System
✅ Taxonomy version history
✅ Mapping version history
✅ Remapping workflow support
✅ Change tracking (additions/deletions)

### 4. Enhanced Mapping Rules
✅ Command-based rule execution
✅ AI vs Human mapping flags
✅ User attribution for mappings
✅ Priority-based rule assignment

### 5. Gold Layer Management
✅ Production-ready mapping table
✅ Automated sync from Silver
✅ Orphan detection
✅ Non-AI mapping isolation

---

## Migration Safety

All migrations include:
- ✅ Transaction wrapping (auto-rollback on failure)
- ✅ IF NOT EXISTS checks
- ✅ Verification queries
- ✅ Success/failure notifications
- ✅ Column comments for documentation

---

## Next Implementation Steps

1. **TypeScript Types** - Update shared types to match new schema
2. **Lambda Functions** - Implement Translation Constant Command Logic
3. **Versioning Logic** - Build version creation/management
4. **Gold Sync** - Automate Silver→Gold synchronization
5. **Testing** - Create test data and validation scripts
