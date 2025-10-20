# Taxonomy Mapping Command Lambda

## Overview

This Lambda function implements the **Translation Constant Command Logic Algorithm** for mapping customer taxonomy nodes to the master taxonomy using non-AI, rule-based matching.

## Purpose

- Maps customer profession codes/names to master taxonomy nodes
- Uses deterministic command-based rules (regex, equals, contains, etc.)
- Excludes AI and human-based mappings
- Handles both new and update load types
- Maintains version history and mapping lineage
- Automatically syncs approved mappings to Gold layer

## Architecture

```
handler.ts (main orchestrator)
├── services/
│   ├── rule-loader.ts          # Loads mapping rules by priority
│   ├── node-matcher.ts          # Evaluates rules against nodes
│   ├── mapping-processor.ts     # Creates/updates/deactivates mappings
│   └── versioning-service.ts    # Manages taxonomy versions
├── database/
│   └── connection.ts            # PostgreSQL connection pool
└── types/
    └── index.ts                 # TypeScript interfaces
```

## Algorithm Flow

### For Each Load:

1. **Create/Update Version Record** in `silver_taxonomies_versions`
2. **Load Customer Nodes** (level=0, status='active')
3. **For Each Customer Node**:
   - Load applicable rules (by node type pair, sorted by priority)
   - Try each rule until first match found
   - If matched:
     - **New Load**: Create new mapping
     - **Update Load**: Compare to existing, update if changed
   - If no match:
     - **New Load**: No action
     - **Update Load**: Deactivate existing mapping if present
4. **Update Version Counters**
5. **Sync to Gold Layer** (active non-AI mappings only)

## Input Event

```typescript
{
  "load_id": 123,
  "customer_id": 456,
  "taxonomy_id": 789,
  "load_type": "new" | "update",
  "taxonomy_type": "master" | "customer"
}
```

## Response

```typescript
{
  "success": true,
  "load_id": 123,
  "customer_id": 456,
  "taxonomy_id": 789,
  "results": {
    "nodes_processed": 150,
    "mappings_created": 80,
    "mappings_updated": 20,
    "mappings_deactivated": 10,
    "mappings_unchanged": 35,
    "failures": 5
  },
  "version_id": 42,
  "errors": ["Node 101: No matching rule found"],
  "processing_time_ms": 4523
}
```

## Supported Commands

The node matcher supports these command types:

- **equals** - Exact match (case-insensitive)
- **contains** - Substring match
- **startswith** - Prefix match
- **endswith** - Suffix match
- **regex** - PostgreSQL regex match

## Rule Evaluation

Rules are evaluated in **priority order** (lower number = higher priority).
The **first match wins** - no further rules are evaluated for that node.

**Confidence**: All command-based rules return **100%** confidence.

## Versioning

### Taxonomy Versions (`silver_taxonomies_versions`)

- **New Loads**: Create version 1
- **Update Loads**:
  - Close previous version (set `version_to_date`)
  - Create new version (increment number)
  - Track changes and remapping stats

### Mapping Versions (`silver_mapping_taxonomies_versions`)

- Each mapping gets a version record
- When mapping changes, old version is closed
- New mapping gets incremented version number

## Database Tables Used

### Read:
- `silver_taxonomies`
- `silver_taxonomies_nodes`
- `silver_taxonomies_nodes_types`
- `silver_taxonomies_nodes_attributes`
- `silver_taxonomies_attribute_types`
- `silver_mapping_taxonomies_rules`
- `silver_mapping_taxonomies_rules_assignment`
- `silver_mapping_taxonomies` (existing mappings)

### Write:
- `silver_mapping_taxonomies` (create/update mappings)
- `silver_mapping_taxonomies_versions` (version history)
- `silver_taxonomies_versions` (taxonomy version tracking)
- `gold_mapping_taxonomies` (via sync function)

## Environment Variables

```bash
PGHOST=localhost                    # Database host
PGPORT=5432                         # Database port
PGDATABASE=taxonomy                 # Database name (production: taxonomy)
PGSCHEMA=taxonomy_schema            # Database schema
PGUSER=lambda_user                  # Database user (production: lambda_user)
PGPASSWORD=your_password            # Database password
PGSSLMODE=require                   # SSL mode for Aurora (production)
```

## Build & Deploy

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests
npm test

# Package for deployment
npm run package

# Deploy (requires AWS CLI and proper IAM role)
aws lambda update-function-code \
  --function-name taxonomy-mapping-command \
  --zip-file fileb://function.zip
```

## Local Testing

```bash
# Run TypeScript in watch mode
npm run watch

# Test with sample event
node dist/handler.js
```

## Integration

This Lambda should be invoked after:
1. Bronze layer ingestion completes (`bronze_load_details.load_status = 'completed'`)
2. Silver layer processing completes (nodes created)

Typically triggered by:
- EventBridge event from Silver processing Lambda
- Step Functions workflow
- Direct API invocation

## Performance

- **Connection Pooling**: Max 2 connections (Lambda best practice)
- **Rule Caching**: Rules cached per invocation
- **Transaction-based**: All operations in single transaction
- **Expected Duration**: 2-10 seconds for 100-500 nodes

## Error Handling

- Individual node errors don't fail entire load
- Failed nodes tracked in response `errors` array
- Transaction rollback on critical failures
- Version marked as 'failed' if error occurs

## Monitoring

Key CloudWatch metrics:
- **Duration**: Processing time per load
- **Errors**: Lambda invocation errors
- **Custom Metrics** (add via CloudWatch SDK):
  - Nodes processed per second
  - Match rate (% of nodes successfully mapped)
  - Rules hit distribution

## Future Enhancements

- [ ] Support for attribute-based matching
- [ ] Hierarchy traversal for multi-level matching
- [ ] Batch processing optimization
- [ ] Dead letter queue for failed loads
- [ ] Custom command types (extensible rule engine)

## Support

- **Algorithm**: Based on Translation Constant Command Logic spec
- **Database Schema**: Migrations 013-025
- **TypeScript Types**: `shared/types/silver.types.ts`, `shared/types/bronze.types.ts`
