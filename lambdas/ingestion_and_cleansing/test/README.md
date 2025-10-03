# Test Data & Scripts

This directory contains test data generation and validation scripts for the Ingestion & Cleansing Lambda.

## 📁 Contents

- **`sample-data-generator.ts`** - Generates sample Excel files and API/S3 events for testing
- **`validate-test-data.ts`** - Validates test data against Lambda event schemas
- **`local-test-runner.ts`** - Runs Lambda handler locally with test data
- **`README.md`** - This file

## 🚀 Quick Start

### 1. Generate Test Data

```bash
# Generate all test data files
npm run test:generate

# Or specify custom output directory
npx ts-node test/sample-data-generator.ts ./custom-test-data
```

This creates:
- ✅ `test-data/master-social-work.xlsx` (223 profession variations)
- ✅ `test-data/master-nurse-practitioners.xlsx` (12+ specialties)
- ✅ `test-data/customer-hospital-a.xlsx` (10 customer professions)
- ✅ `test-data/api-events.json` (3 sample API events)
- ✅ `test-data/s3-events.json` (3 sample S3 events)

### 2. Validate Test Data

```bash
# Validate all generated test data
npm run test:validate

# Or specify custom directory
npx ts-node test/validate-test-data.ts ./custom-test-data
```

Checks for:
- ✅ Valid Excel layouts (node/attribute markers)
- ✅ Required columns present
- ✅ Event schema compliance
- ⚠️ Missing recommended fields

### 3. Run Local Tests

```bash
# Run Lambda handler locally with test data
npm run test:local

# Test specific event
npx ts-node test/local-test-runner.ts api masterSocialWork
npx ts-node test/local-test-runner.ts s3 customerHospitalA
```

## 📊 Sample Taxonomies

### Master Taxonomy: Social Work (Complex)

Based on Kristen's sample with 223 profession variations.

**Structure**:
```
Industry → Group → Occupation
└─ Attributes: Level, Status
```

**Sample Professions**:
- Licensed Clinical Social Worker (LCSW) + Licensed + Active
- Licensed Clinical Social Worker (LCSW) + Licensed + Temporary
- Licensed Social Worker (LSW) + Licensed + Provisional
- Clinical Social Worker (CSW) + Certified + Active
- Social Work Supervisor + Supervisor + Active

**Key Test Cases**:
- ✅ Multi-level hierarchy (3 node levels)
- ✅ Multiple attributes per node
- ✅ Same profession with different attributes
- ✅ Level variations (Licensed, Certified, Registered, Supervisor, Advanced Practice)
- ✅ Status variations (Active, Temporary, Provisional, Inactive)

### Master Taxonomy: Nurse Practitioners

**Structure**:
```
Industry → Group → Occupation → Specialty
└─ Attributes: Level, Status
```

**Sample Specialties**:
- Family Practice
- Adult-Gerontology
- Pediatrics
- Psychiatric-Mental Health
- Acute Care, Neonatal, Emergency, Oncology, Cardiology

**Key Test Cases**:
- ✅ 4-level hierarchy
- ✅ Specialty as deepest node level
- ✅ Advanced Practice credential level
- ✅ Temporary status variations

### Customer Taxonomy: Hospital A

**Structure**:
```
Job Title (profession)
└─ Attributes: State, Years Experience, Department
```

**Sample Professions**:
- "Licensed Clinical Social Worker" → CA, 5 years, Mental Health
- "LCSW" (abbreviation) → CA, 3 years, Emergency
- "Licensed Social Worker" → WA, 2 years, Pediatrics
- "Family Nurse Practitioner" → CA, 7 years, Primary Care

**Key Test Cases**:
- ✅ Flat structure (no hierarchy)
- ✅ Profession name variations (full vs abbreviation)
- ✅ State-based attributes
- ✅ Department context
- ✅ Tests mapping to master taxonomy

## 🧪 Test Scenarios

### Scenario 1: NEW Load (Master Taxonomy)

**Event**: `api-events.json > masterSocialWork`

**Expected Behavior**:
1. Creates load record with status "in progress"
2. Creates `silver_taxonomies` entry (customer_id: -1, taxonomy_id: -1)
3. Populates node types dictionary (Industry, Group, Occupation)
4. Populates attribute types dictionary (Level, Status)
5. Creates ~20 hierarchy nodes
6. Creates ~20 node attributes
7. Creates Version 1
8. Finalizes load with status "completed"

**SQL Verification**:
```sql
-- Check load details
SELECT * FROM bronze_load_details WHERE load_id = <load_id>;

-- Check created nodes
SELECT * FROM silver_taxonomies_nodes WHERE load_id = <load_id>;

-- Check attributes
SELECT * FROM silver_taxonomies_nodes_attributes WHERE load_id = <load_id>;

-- Check version
SELECT * FROM silver_taxonomies_versions WHERE taxonomy_id = '-1';
```

### Scenario 2: UPDATED Load (Master Taxonomy)

**Steps**:
1. Run Scenario 1 first (NEW load)
2. Modify `master-social-work.xlsx`:
   - Remove 2 professions
   - Add 2 new professions
   - Change 1 profession's status
3. Re-run with same customer_id/taxonomy_id

**Expected Behavior**:
1. Detects load_type = "updated"
2. Upserts existing nodes (refreshes parent/level/profession)
3. Inserts new nodes
4. Soft-deletes missing nodes (status = 'inactive')
5. Reactivates previously inactive attributes if present
6. Closes Version 1 (sets version_to_date)
7. Creates Version 2 with affected_nodes/affected_attributes JSON
8. Finalizes load

**SQL Verification**:
```sql
-- Check inactive nodes
SELECT * FROM silver_taxonomies_nodes
WHERE taxonomy_id = '-1' AND status = 'inactive';

-- Check version history
SELECT * FROM silver_taxonomies_versions
WHERE taxonomy_id = '-1'
ORDER BY taxonomy_version_number;

-- Check updated timestamps
SELECT node_id, value, last_updated_at, load_id
FROM silver_taxonomies_nodes
WHERE taxonomy_id = '-1'
ORDER BY last_updated_at DESC;
```

### Scenario 3: Customer Taxonomy Mapping

**Event**: `api-events.json > customerHospitalA`

**Expected Behavior**:
1. Creates load record
2. Creates `silver_taxonomies` entry (customer_id: 100, taxonomy_id: 200)
3. Creates single node type ("Job Title")
4. Creates attribute types (State, Years Experience, Department)
5. Creates 10 profession nodes (flat structure, level = 1)
6. Creates attributes for each profession
7. Creates Version 1
8. Finalizes load

**SQL Verification**:
```sql
-- Check customer taxonomy
SELECT * FROM silver_taxonomies WHERE customer_id = '100';

-- Check flat structure (all nodes level 1, no parents)
SELECT node_id, value, level, parent_node_id
FROM silver_taxonomies_nodes
WHERE taxonomy_id = '200';

-- Check attributes include State
SELECT n.value AS profession, at.name AS attr_type, na.value AS attr_value
FROM silver_taxonomies_nodes n
JOIN silver_taxonomies_nodes_attributes na ON n.node_id = na.node_id
JOIN silver_taxonomies_attribute_types at ON na.attribute_type_id = at.attribute_type_id
WHERE n.taxonomy_id = '200';
```

## 🔧 Database Setup

Before running tests, ensure:

1. **Database exists**:
   ```sql
   CREATE DATABASE propelus_taxonomy;
   ```

2. **Tables created** (run migrations):
   ```bash
   psql -d propelus_taxonomy -f ../../migrations/001_initial_schema.sql
   ```

3. **Environment variables set**:
   ```bash
   export PGHOST=localhost
   export PGPORT=5432
   export PGDATABASE=propelus_taxonomy
   export PGUSER=postgres
   export PGPASSWORD=your_password
   export PGSSLMODE=disable  # For local testing
   ```

## 📝 Adding Custom Test Data

### Custom Master Taxonomy

```typescript
const customMasterData = [
  ['Industry (node)', 'Group (node)', 'Occupation (node)', 'Level (attribute)'],
  ['Healthcare', 'Physicians', 'General Practitioner', 'Licensed'],
  // ... more rows
];

generateExcelFile(customMasterData, './test-data/custom-master.xlsx');
```

### Custom API Event

```typescript
const customApiEvent = {
  source: 'api',
  taxonomyType: 'customer',
  payload: {
    customer_id: '999',
    taxonomy_id: '888',
    taxonomy_name: 'My Custom Taxonomy',
    layout: {
      'Proffesion column': { Profession: 'Title' }
    },
    rows: [
      { 'Title': 'Software Engineer', 'Level': 'Senior', 'Location': 'Remote' }
    ]
  }
};
```

## 🐛 Troubleshooting

### Issue: "Excel file has no sheets"

**Cause**: File is not a valid Excel file or is corrupted

**Fix**: Regenerate test data:
```bash
npm run test:generate
```

### Issue: "Missing column ending with '(node)'"

**Cause**: Excel headers missing node/attribute markers

**Fix**: Ensure headers include markers:
- Master: `Industry (node)`, `Level (attribute)`
- Customer: `Job Title (profession)`

### Issue: "Load failed with status 'failed'"

**Cause**: Database constraint violation or row processing error

**Fix**: Check logs for row-level errors:
```sql
SELECT load_details->'Row Errors'
FROM bronze_load_details
WHERE load_id = <load_id>;
```

## 🎯 Next Steps for Tuesday Walkthrough

1. **Generate Test Data**:
   ```bash
   npm run test:generate
   ```

2. **Validate Data**:
   ```bash
   npm run test:validate
   ```

3. **Test Lambda Locally**:
   ```bash
   npm run test:local
   ```

4. **Deploy Lambda**:
   ```bash
   npm run build
   npm run package
   npm run deploy
   ```

5. **Test with S3** (upload Excel files):
   ```bash
   aws s3 cp test-data/master-social-work.xlsx \
     s3://propelus-taxonomy-uploads/customer--1__taxonomy--1__master-social-work.xlsx
   ```

6. **Verify Results** (check database):
   ```sql
   -- Check latest load
   SELECT * FROM bronze_load_details ORDER BY load_id DESC LIMIT 1;

   -- Check node count
   SELECT COUNT(*) FROM silver_taxonomies_nodes WHERE load_id = <load_id>;

   -- Check version
   SELECT * FROM silver_taxonomies_versions WHERE taxonomy_id = '-1';
   ```

## 📚 References

- [Lambda Algorithm v0.2](/docs/Lambda_Ingestion_Algorithm_v0.2.docx)
- [Data Model v0.42](/docs/Data_Model_v0.42.pdf)
- [Log Retention Strategy](/docs/LOG_RETENTION_STRATEGY.md)
- [PROJECT_DOCUMENTATION.md](/PROJECT_DOCUMENTATION.md)
