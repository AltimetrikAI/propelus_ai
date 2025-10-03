# Ingestion & Cleansing Lambda (v2.0)

Combined Bronze ingestion and Silver processing Lambda function implementing the data engineer's algorithm v0.2.

## Overview

This Lambda performs **atomic Bronze → Silver transformation** in a single transaction:

1. **Bronze Ingestion** (§1-5): Raw data capture
2. **Dictionary Management** (§6): Append-only node/attribute types
3. **Silver Transformation** (§7): Structured hierarchy with versioning
4. **Reconciliation** (§7B): Soft-delete for updated loads
5. **Versioning** (§7A.3, §7B.5): Track taxonomy evolution
6. **Finalization** (§8): Row counts and status

## Architecture

### File Structure

```
src/
├── handler.ts                      # Main Lambda entry point
├── types/                          # TypeScript type definitions
│   ├── index.ts
│   ├── events.ts
│   ├── layout.ts
│   └── context.ts
├── utils/                          # Utility functions
│   ├── normalization.ts
│   ├── stream.ts
│   └── constants.ts
├── parsers/                        # Data extraction & parsing
│   ├── api-parser.ts
│   ├── excel-parser.ts
│   ├── layout-parser.ts
│   └── filename-parser.ts
├── database/
│   ├── connection.ts
│   └── queries/                    # SQL query modules
│       ├── load.ts
│       ├── bronze.ts
│       ├── silver-taxonomy.ts
│       ├── silver-dictionaries.ts
│       ├── silver-nodes.ts
│       ├── silver-attributes.ts
│       ├── reconciliation.ts
│       └── versioning.ts
└── processors/                     # Processing logic
    ├── s3-processor.ts
    ├── api-processor.ts
    ├── row-processor.ts
    └── load-orchestrator.ts
```

## Event Types

### S3 Event (Excel Ingestion)

```json
{
  "source": "s3",
  "taxonomyType": "master",
  "bucket": "propelus-taxonomy-uploads",
  "key": "customer-123__taxonomy-456__master.xlsx"
}
```

**Filename Convention**: `customer-<CID>__taxonomy-<TID>__<name>.xlsx`

### API Event (Payload Ingestion)

```json
{
  "source": "api",
  "taxonomyType": "customer",
  "payload": {
    "customer_id": "123",
    "taxonomy_id": "456",
    "taxonomy_name": "Custom Roles",
    "layout": {
      "Proffesion column": { "Profession": "Job Title" }
    },
    "rows": [
      { "Job Title": "Registered Nurse", "State": "CA", "Years": "5" }
    ]
  }
}
```

## Excel Layout Format

### Master Taxonomy

```
Industry (node) | Group (node) | Occupation (node) | Level (attribute) | Status (attribute)
Healthcare      | Medical      | Physician         | Licensed          | Active
Healthcare      | Nursing      | RN               | Registered        | Temporary
```

- **Columns ending with `(node)`**: Hierarchy levels (order matters!)
- **Columns ending with `(attribute)`**: Contextual attributes for LLM enrichment
  - Examples: Status (Temporary, Provisional), Level (Licensed, Certified)

### Customer Taxonomy

```
Job Title (profession) | State | Years Experience | Specialty
Registered Nurse       | CA    | 5                | ICU
Software Developer     | NY    | 3                | Backend
```

- **Exactly ONE column ending with `(profession)`**: Profession name
- **All other columns**: Attributes (no marker needed)

## Load Types

### NEW Load
- First time loading a (customer_id, taxonomy_id) pair
- **INSERT-only** for nodes/attributes
- Does NOT reactivate inactive records
- Creates **Version 1**

### UPDATED Load
- Subsequent loads for existing taxonomy
- **UPSERT** nodes (refresh parent/level/profession)
- **UPSERT** attributes (reactivate if inactive)
- **Soft-delete** missing nodes/attributes (`status='inactive'`)
- Creates **Version N**, closes **Version N-1**

## Environment Variables

```bash
PGHOST=taxonomy-db.cluster-xxx.us-east-1.rds.amazonaws.com
PGPORT=5432
PGDATABASE=propelus_taxonomy
PGUSER=lambda_user
PGPASSWORD=<from-secrets-manager>
PGSSLMODE=require
```

## Build & Deploy

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Package for Lambda
npm run package

# Deploy (requires AWS CLI configured)
npm run deploy
```

## Testing

```bash
# Run unit tests
npm test

# Run with watch mode
npm test:watch

# Run integration tests (requires test DB)
npm run test:integration
```

## Key Features

### 1. Append-Only Dictionaries
- `silver_taxonomies_nodes_types`
- `silver_taxonomies_attribute_types`
- **Never modified** - only INSERT if not exists by `lower(name)`

### 2. Natural Keys
- **Nodes**: `(taxonomy_id, node_type_id, customer_id, lower(value))`
- **Attributes**: `(node_id, attribute_type_id, lower(value))`
- Case-insensitive uniqueness prevents duplicates

### 3. Soft-Delete Reconciliation
- Nodes/attributes not in current load: `status='inactive'`
- Version tracking captures all changes

### 4. Lineage Tracking
- Every row links to: `load_id`, `row_id` (bronze)
- Full audit trail for troubleshooting

## Response Format

```json
{
  "ok": true,
  "load_id": 12345,
  "customer_id": "123",
  "taxonomy_id": "456",
  "taxonomy_type": "master",
  "load_type": "updated",
  "rows_processed": 150
}
```

## Error Handling

- **Row-level errors**: Marked as `row_load_status='failed'` in bronze
- **Load-level errors**: Entire load marked as `'failed'` or `'partially completed'`
- All errors captured in `bronze_load_details.load_details['Row Errors']`

## Performance Considerations

- **Dictionary caching**: Reduces redundant lookups within transaction
- **Batch processing**: All rows in single transaction for consistency
- **Connection pooling**: `max: 2` for Lambda (scales via concurrent executions)
- **Indexes**: Natural key indexes ensure fast upsert performance

## Monitoring

Key CloudWatch metrics:
- Lambda duration (target: <30s for 1000 rows)
- Lambda errors (target: <0.1%)
- Load status distribution
- Version creation rate

## Migration from v1.0

This Lambda **replaces**:
- ❌ `lambdas/bronze_ingestion`
- ❌ `lambdas/silver_processing`

Advantages:
- ✅ Atomic transaction (Bronze → Silver)
- ✅ Proper versioning
- ✅ Soft-delete reconciliation
- ✅ Better error handling
- ✅ Complete audit trail

## References

- **Algorithm**: `/docs/Lambda_Ingestion_Algorithm_v0.2.docx`
- **Data Model**: `/docs/Data_Model_v0.42.pdf`
- **Step Functions**: Update workflow to call this single Lambda

## Support

For issues or questions, contact:
- **Data Engineering**: Marcin (algorithm owner)
- **Backend Development**: Douglas Martins
- **Product**: Kristen, Edwin
