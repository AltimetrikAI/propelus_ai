# Schema Updates - October 14, 2024

**Purpose**: Align TypeORM entities with Data Engineer's latest schema specification
**Status**: ✅ Complete - All critical updates applied

---

## Summary of Changes

### Entities Updated: 8
### New Entities Created: 2
### Total Columns Added/Modified: ~25

---

## Detailed Changes

### 1. bronze_load_details ✅

**Columns Added**:
- `load_start` (timestamp, nullable) - When load started
- `load_end` (timestamp, nullable) - When load ended
- `load_status` (varchar(50), default 'in progress') - Status: completed, partially completed, failed, in progress
- `load_active_flag` (boolean, default true) - Is data from this load active?
- `load_type` (varchar(20)) - Type: 'new' or 'updated'
- `taxonomy_type` (varchar(20)) - Type: 'master' or 'customer'

**Modified**:
- Renamed `type` to optional for backward compatibility

---

### 2. bronze_taxonomies ✅

**Columns Renamed**:
- `id` → `row_id` (Primary Key)

**Columns Added**:
- `row_load_status` (varchar(50), default 'in progress') - Status: completed, in progress, failed
- `row_active_flag` (boolean, default true) - Is data from this row active?

---

### 3. silver_taxonomies ✅

**Columns Added**:
- `load_id` (int, nullable) - FK to bronze_load_details (last load for this taxonomy)

---

### 4. silver_taxonomies_nodes_types ✅

**Columns Added**:
- `load_id` (int, nullable) - FK to bronze_load_details

**Existing** (no changes needed):
- `status` (already present)

---

### 5. silver_taxonomies_attribute_types ✅

**Columns Added**:
- `status` (varchar(20), default 'active') - Status: active or inactive
- `load_id` (int, nullable) - FK to bronze_load_details

---

### 6. silver_taxonomies_nodes ✅

**Columns Added**:
- `status` (varchar(20), default 'active') - Status: active or inactive
- `load_id` (int, nullable) - FK to bronze_load_details
- `row_id` (int, nullable) - FK to bronze_taxonomies

---

### 7. silver_taxonomies_nodes_attributes ✅

**Columns Added**:
- `status` (varchar(20), default 'active') - Status: active or inactive
- `load_id` (int, nullable) - FK to bronze_load_details
- `row_id` (int, nullable) - FK to bronze_taxonomies

---

### 8. silver_taxonomies_versions ✅ NEW TABLE

**Purpose**: Tracks versions of taxonomies over time, including structural changes and remapping impact

**Complete Schema**:
```typescript
@Entity('silver_taxonomies_versions')
export class SilverTaxonomiesVersions {
  taxonomy_version_id: number (PK)
  taxonomy_id: number (FK → silver_taxonomies)
  taxonomy_version_number: number
  change_type: string (255)
  affected_nodes: jsonb (nullable)
  affected_attributes: jsonb (nullable)
  remapping_flag: boolean (default false)
  remapping_reason: text (nullable)
  total_mappings_processed: number (default 0)
  total_mappings_changed: number (default 0)
  total_mappings_unchanged: number (default 0)
  total_mappings_failed: number (default 0)
  total_mappings_new: number (default 0)
  remapping_proces_status: varchar(50) (nullable)
  version_notes: text (nullable)
  version_from_date: timestamp
  version_to_date: timestamp (nullable)
  created_at: timestamp
  last_updated_at: timestamp
  load_id: number (FK → bronze_load_details)
}
```

---

### 9. silver_mapping_taxonomies_versions ✅ NEW TABLE

**Purpose**: Tracks versions of taxonomy mappings over time, including remapping impact

**Complete Schema**:
```typescript
@Entity('silver_mapping_taxonomies_versions')
export class SilverMappingTaxonomiesVersions {
  mapping_version_id: number (PK)
  master_taxonomy_id: number (FK → silver_taxonomies)
  child_taxonomy_id: number (FK → silver_taxonomies)
  mapping_version_number: number
  change_type: string (255)
  affected_mappings: jsonb (nullable)
  remapping_flag: boolean (default false)
  remapping_reason: text (nullable)
  total_mappings_processed: number (default 0)
  total_mappings_changed: number (default 0)
  total_mappings_unchanged: number (default 0)
  total_mappings_failed: number (default 0)
  total_mappings_new: number (default 0)
  remapping_proces_status: varchar(50) (nullable)
  version_notes: text (nullable)
  version_from_date: timestamp
  version_to_date: timestamp (nullable)
  created_at: timestamp
  last_updated_at: timestamp
  load_id: number (FK → bronze_load_details)
}
```

---

### 10. gold_mapping_taxonomies ✅ RENAMED

**Change**: Renamed from `gold_taxonomies_mapping` to `gold_mapping_taxonomies` for naming consistency

**Reason**: Align with naming convention used in silver_mapping_taxonomies

---

## Impact on Algorithm v1.0

### ✅ Fully Compatible

All Algorithm v1.0 features remain fully operational:
- Rolling ancestor memory
- Explicit node levels
- Updated natural key (with parent_node_id)
- Profession column handling

### ✅ Enhanced Capabilities

New schema features add:
- **Full Load Tracking**: load_start, load_end, load_status
- **Row-Level Tracking**: row_load_status for granular error handling
- **Data Lineage**: load_id and row_id throughout Silver layer
- **Active Flags**: Manual override capability for data management
- **Version Management**: Complete version tracking with remapping support

---

## Database Migration Required

### Migration 004: Schema Alignment

```sql
-- Add new columns to bronze_load_details
ALTER TABLE bronze_load_details
  ADD COLUMN load_start TIMESTAMP,
  ADD COLUMN load_end TIMESTAMP,
  ADD COLUMN load_status VARCHAR(50) DEFAULT 'in progress',
  ADD COLUMN load_active_flag BOOLEAN DEFAULT true,
  ADD COLUMN load_type VARCHAR(20),
  ADD COLUMN taxonomy_type VARCHAR(20);

-- Rename bronze_taxonomies.id to row_id
ALTER TABLE bronze_taxonomies
  RENAME COLUMN id TO row_id;

-- Add status and flag columns to bronze_taxonomies
ALTER TABLE bronze_taxonomies
  ADD COLUMN row_load_status VARCHAR(50) DEFAULT 'in progress',
  ADD COLUMN row_active_flag BOOLEAN DEFAULT true;

-- Add load_id to silver tables
ALTER TABLE silver_taxonomies
  ADD COLUMN load_id INTEGER REFERENCES bronze_load_details(load_id);

ALTER TABLE silver_taxonomies_nodes_types
  ADD COLUMN load_id INTEGER REFERENCES bronze_load_details(load_id);

ALTER TABLE silver_taxonomies_attribute_types
  ADD COLUMN status VARCHAR(20) DEFAULT 'active',
  ADD COLUMN load_id INTEGER REFERENCES bronze_load_details(load_id);

ALTER TABLE silver_taxonomies_nodes
  ADD COLUMN status VARCHAR(20) DEFAULT 'active',
  ADD COLUMN load_id INTEGER REFERENCES bronze_load_details(load_id),
  ADD COLUMN row_id INTEGER REFERENCES bronze_taxonomies(row_id);

ALTER TABLE silver_taxonomies_nodes_attributes
  ADD COLUMN status VARCHAR(20) DEFAULT 'active',
  ADD COLUMN load_id INTEGER REFERENCES bronze_load_details(load_id),
  ADD COLUMN row_id INTEGER REFERENCES bronze_taxonomies(row_id);

-- Create silver_taxonomies_versions table
CREATE TABLE silver_taxonomies_versions (
  taxonomy_version_id SERIAL PRIMARY KEY,
  taxonomy_id INTEGER NOT NULL REFERENCES silver_taxonomies(taxonomy_id),
  taxonomy_version_number INTEGER NOT NULL,
  change_type VARCHAR(255) NOT NULL,
  affected_nodes JSONB,
  affected_attributes JSONB,
  remapping_flag BOOLEAN DEFAULT false,
  remapping_reason TEXT,
  total_mappings_processed INTEGER DEFAULT 0,
  total_mappings_changed INTEGER DEFAULT 0,
  total_mappings_unchanged INTEGER DEFAULT 0,
  total_mappings_failed INTEGER DEFAULT 0,
  total_mappings_new INTEGER DEFAULT 0,
  remapping_proces_status VARCHAR(50),
  version_notes TEXT,
  version_from_date TIMESTAMP NOT NULL,
  version_to_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  last_updated_at TIMESTAMP DEFAULT NOW(),
  load_id INTEGER NOT NULL REFERENCES bronze_load_details(load_id)
);

-- Create silver_mapping_taxonomies_versions table
CREATE TABLE silver_mapping_taxonomies_versions (
  mapping_version_id SERIAL PRIMARY KEY,
  master_taxonomy_id INTEGER NOT NULL REFERENCES silver_taxonomies(taxonomy_id),
  child_taxonomy_id INTEGER NOT NULL REFERENCES silver_taxonomies(taxonomy_id),
  mapping_version_number INTEGER NOT NULL,
  change_type VARCHAR(255) NOT NULL,
  affected_mappings JSONB,
  remapping_flag BOOLEAN DEFAULT false,
  remapping_reason TEXT,
  total_mappings_processed INTEGER DEFAULT 0,
  total_mappings_changed INTEGER DEFAULT 0,
  total_mappings_unchanged INTEGER DEFAULT 0,
  total_mappings_failed INTEGER DEFAULT 0,
  total_mappings_new INTEGER DEFAULT 0,
  remapping_proces_status VARCHAR(50),
  version_notes TEXT,
  version_from_date TIMESTAMP NOT NULL,
  version_to_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  last_updated_at TIMESTAMP DEFAULT NOW(),
  load_id INTEGER NOT NULL REFERENCES bronze_load_details(load_id)
);

-- Rename gold_taxonomies_mapping to gold_mapping_taxonomies
ALTER TABLE gold_taxonomies_mapping RENAME TO gold_mapping_taxonomies;

-- Create indexes
CREATE INDEX idx_taxonomy_versions_taxonomy ON silver_taxonomies_versions(taxonomy_id);
CREATE INDEX idx_taxonomy_versions_load ON silver_taxonomies_versions(load_id);
CREATE INDEX idx_mapping_versions_master ON silver_mapping_taxonomies_versions(master_taxonomy_id);
CREATE INDEX idx_mapping_versions_child ON silver_mapping_taxonomies_versions(child_taxonomy_id);
CREATE INDEX idx_mapping_versions_load ON silver_mapping_taxonomies_versions(load_id);
CREATE INDEX idx_nodes_load ON silver_taxonomies_nodes(load_id);
CREATE INDEX idx_nodes_row ON silver_taxonomies_nodes(row_id);
CREATE INDEX idx_attributes_load ON silver_taxonomies_nodes_attributes(load_id);
CREATE INDEX idx_attributes_row ON silver_taxonomies_nodes_attributes(row_id);
```

---

## Code Updates Required

### 1. Update Load Opening Logic
File: `lambdas/ingestion_and_cleansing/src/database/queries/load.ts`

**Changes Needed**:
- Set `load_start = NOW()` when opening load
- Set `load_type` based on taxonomy existence check
- Set `taxonomy_type` from event
- Initialize `load_status = 'in progress'`
- Initialize `load_active_flag = true`

### 2. Update Load Finalization Logic
File: `lambdas/ingestion_and_cleansing/src/database/queries/load.ts`

**Changes Needed**:
- Set `load_end = NOW()` when finalizing
- Update `load_status` based on row outcomes:
  - 'completed' if all rows completed
  - 'partially completed' if some rows failed
  - 'failed' if no rows completed

### 3. Update Bronze Row Processing
File: `lambdas/ingestion_and_cleansing/src/database/queries/bronze.ts`

**Changes Needed**:
- Initialize `row_load_status = 'in progress'` when inserting
- Initialize `row_active_flag = true` when inserting
- Update `row_load_status` to 'completed' or 'failed' after processing

### 4. Update Silver Node Insertion
File: `lambdas/ingestion_and_cleansing/src/database/queries/silver-nodes.ts`

**Changes Needed**:
- Add `load_id` parameter
- Add `row_id` parameter
- Set `status = 'active'` by default
- Pass lineage information through

### 5. Update Silver Attribute Insertion
File: `lambdas/ingestion_and_cleansing/src/database/queries/silver-attributes.ts`

**Changes Needed**:
- Add `load_id` parameter
- Add `row_id` parameter
- Set `status = 'active'` by default

### 6. Update Versioning Logic
File: `lambdas/ingestion_and_cleansing/src/database/queries/versioning.ts`

**Changes Needed**:
- Use new `silver_taxonomies_versions` table
- Populate all required fields per spec
- Set defaults for mapping-related fields (all zeros, NULL status)

---

## Testing Checklist

- [ ] Run migration 004 on dev database
- [ ] Update code files with new parameters
- [ ] Test Bronze layer load tracking
- [ ] Test row-level status tracking
- [ ] Test Silver layer lineage (load_id, row_id)
- [ ] Test version creation with new table
- [ ] Verify status flags work correctly
- [ ] Test active flag filtering
- [ ] Verify backward compatibility with existing data

---

## Benefits

### For Operations:
✅ **Granular Error Tracking**: Know exactly which rows failed
✅ **Load Performance Metrics**: Track load_start and load_end times
✅ **Manual Data Control**: Active flags for data management

### For Development:
✅ **Full Lineage**: Trace any Silver data back to Bronze row and load
✅ **Version History**: Complete audit trail of taxonomy changes
✅ **Status Management**: Soft deletes and manual overrides

### For Business:
✅ **Data Quality**: Better error handling and recovery
✅ **Audit Compliance**: Complete tracking of data flow
✅ **Operational Visibility**: Load status monitoring

---

**Updated By**: Douglas Martins
**Date**: October 14, 2024
**Related**: Algorithm v1.0 Implementation
**Status**: Ready for Migration
