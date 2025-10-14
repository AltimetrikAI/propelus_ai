# Schema Comparison: Data Engineer Spec vs Current Implementation

**Date**: October 14, 2024
**Purpose**: Compare latest schema documentation with Algorithm v1.0 implementation

---

## Bronze Layer

### bronze_load_details

**Current Implementation**:
- ✅ load_id (PK)
- ✅ customer_id
- ✅ taxonomy_id
- ✅ load_details (jsonb)
- ✅ load_date (CreateDateColumn)
- ✅ type (renamed from 'load_type' in spec)
- ✅ request_id
- ✅ source_system (renamed from API spec)
- ✅ callback_url

**Data Engineer Spec Additions Needed**:
- ❌ load_start (timestamp)
- ❌ load_end (timestamp)
- ❌ load_status ('completed', 'partially completed', 'failed', 'in progress')
- ❌ load_active_flag (boolean, default true)
- ❌ load_type (should be separate from 'type': 'new' or 'updated')
- ❌ taxonomy_type ('master' or 'customer')

**Action**: Add missing columns to bronze_load_details entity

---

### bronze_taxonomies

**Current Implementation**:
- ✅ id (PK) - but spec calls it row_id
- ✅ customer_id
- ✅ taxonomy_id
- ✅ row_json (jsonb)
- ✅ load_date (CreateDateColumn)
- ✅ type
- ✅ load_id (FK)
- ✅ file_url
- ✅ request_id

**Data Engineer Spec Changes Needed**:
- ⚠️ Rename 'id' to 'row_id' (PK)
- ❌ row_load_status ('completed', 'in progress', 'failed')
- ❌ row_active_flag (boolean, default true)

**Action**: Rename PK and add status/flag columns

---

## Silver Layer

### silver_taxonomies

**Current Implementation**:
- ✅ taxonomy_id (PK)
- ✅ customer_id
- ✅ name
- ✅ type ('master' or 'customer')
- ✅ status ('active' or 'inactive')
- ✅ created_at
- ✅ last_updated_at
- ✅ taxonomy_version
- ✅ version_notes
- ✅ version_effective_date

**Data Engineer Spec Additions Needed**:
- ❌ load_id (FK to bronze_load_details)

**Action**: Add load_id column

---

### silver_taxonomies_nodes_types

**Current Implementation**:
- ✅ node_type_id (PK)
- ✅ name
- ✅ status ('active' default)
- ✅ level
- ✅ created_at
- ✅ last_updated_at

**Data Engineer Spec Additions Needed**:
- ❌ load_id (FK to bronze_load_details)

**Action**: Add load_id column

---

### silver_taxonomies_attribute_types

**Current Implementation**:
- ✅ attribute_type_id (PK)
- ✅ name (unique)
- ✅ created_at
- ✅ last_updated_at

**Data Engineer Spec Additions Needed**:
- ❌ status ('active' or 'inactive', default 'active')
- ❌ load_id (FK to bronze_load_details)

**Action**: Add status and load_id columns

---

### silver_taxonomies_nodes

**Current Implementation**:
- ✅ node_id (PK)
- ✅ node_type_id (FK)
- ✅ taxonomy_id (FK)
- ✅ parent_node_id (FK, nullable)
- ✅ value (text)
- ✅ profession (nullable)
- ✅ level (default 1)
- ✅ created_at
- ✅ last_updated_at

**Data Engineer Spec Additions Needed**:
- ❌ status ('active' or 'inactive', default 'active')
- ❌ load_id (FK to bronze_load_details)
- ❌ row_id (FK to bronze_taxonomies)

**Action**: Add status, load_id, and row_id columns

---

### silver_taxonomies_nodes_attributes

**Current Implementation**:
- ✅ Node_attribute_type_id (PK) - matches spec
- ✅ Attribute_type_id (FK)
- ✅ node_id (FK)
- ⚠️ name (column) - spec doesn't mention this, only value
- ✅ value (text)
- ✅ created_at
- ✅ last_updated_at

**Data Engineer Spec Additions Needed**:
- ❌ status ('active' or 'inactive', default 'active')
- ❌ load_id (FK to bronze_load_details)
- ❌ row_id (FK to bronze_taxonomies)

**Action**: Add status, load_id, and row_id columns

---

### silver_taxonomies_versions

**Current Implementation**:
- ❌ **Table does not exist in current entities**

**Data Engineer Spec - Full Table Needed**:
- taxonomy_version_id (PK)
- taxonomy_id (FK)
- taxonomy_version_number (sequential)
- change_type (text)
- affected_nodes (jsonb/list)
- affected_attributes (jsonb/list)
- remapping_flag (boolean, default false)
- remapping_reason (text, nullable)
- total_mappings_processed (int, default 0)
- total_mappings_changed (int, default 0)
- total_mappings_unchanged (int, default 0)
- total_mappings_failed (int, default 0)
- total_mappings_new (int, default 0)
- remapping_proces_status (text, nullable)
- version_notes (text, nullable)
- version_from_date (timestamp)
- version_to_date (timestamp, nullable)
- created_at (timestamp)
- last_updated_at (timestamp)
- load_id (FK)

**Action**: Create complete silver_taxonomies_versions entity

---

## Audit Layer

### Log Tables (Example: silver_taxonomies_log)

**Current Implementation**:
- ⚠️ audit.entity.ts exists but may not match spec

**Data Engineer Spec**:
- Primary key of source table
- old_row (jsonb, snapshot before change)
- new_row (jsonb, snapshot after change)
- operation_type ('insert', 'update', 'delete')
- operation_date (timestamp)
- user (text, can be technical user)

**Action**: Verify/update audit log structure

---

## Summary

### Critical Missing Features:
1. ✅ **Already Implemented in v1.0**: Algorithm core logic with rolling ancestor memory
2. ❌ **Missing**: Status tracking columns (load_status, row_load_status)
3. ❌ **Missing**: Active flags (load_active_flag, row_active_flag)
4. ❌ **Missing**: Lineage tracking (load_id, row_id foreign keys everywhere)
5. ❌ **Missing**: silver_taxonomies_versions table (versioning system)
6. ❌ **Missing**: Proper audit log structure

### Alignment Status:
- **Algorithm v1.0 Logic**: ✅ 100% Complete
- **Database Schema**: ⚠️ ~70% Complete
- **Missing Columns**: ~15-20 columns across multiple tables
- **Missing Tables**: 1 critical table (silver_taxonomies_versions)

---

## Recommendations

### Priority 1 (Critical for Production):
1. Add status and flag columns to Bronze tables
2. Add load_id/row_id lineage to all Silver tables
3. Create silver_taxonomies_versions table

### Priority 2 (Important for Operations):
4. Update audit log structure
5. Add indexes for new FK columns

### Priority 3 (Nice to Have):
6. Add database constraints matching spec
7. Update TypeORM entity relationships
