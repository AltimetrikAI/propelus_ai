# Propelus AI Taxonomy Framework

## Overview

The Propelus AI Healthcare Profession Taxonomy Framework is a TypeScript/Node.js based system for normalizing and translating healthcare profession taxonomies across different healthcare systems.

**Technology Stack**: TypeScript, Node.js 20+, TypeORM, AWS Lambda, PostgreSQL (Aurora), AWS Bedrock

**Version**: 4.1.0
**Status**: Production Ready
**Last Updated**: January 21, 2025

### Recent Changes (v4.1.0)
- **Customer ID Format**: Changed from integer to string (VARCHAR 255) to support subsystem identifiers (e.g., `evercheck-719`)
- **Taxonomy Descriptions**: Added optional description field for human-friendly taxonomy names
- **Auto-Detection**: System automatically detects new vs updated taxonomies (no manual flag required)
- **Enhanced API Contracts**: Updated OpenAPI spec (v1.1.0) with improved request/response schemas

---

## Features

### Core Capabilities
- **Data Ingestion & Cleansing**: Automated processing of taxonomy data from multiple sources (Excel, API)
- **Rule-Based Mapping**: Deterministic command-based mapping engine (equals, contains, startswith, regex)
- **NLP Qualifier Matching**: Context-aware pattern matching for qualified profession terms
- **AI Semantic Matching**: Advanced matching using AWS Bedrock (Claude/Llama) with hierarchy context
- **Real-Time Translation**: Fast profession code translation with caching support
- **Version Tracking**: Complete audit trail for taxonomies and mappings with remapping support
- **Hierarchical Gap Handling**: N/A node system for variable-depth taxonomy structures

### Data Architecture
- **Bronze Layer**: Raw data ingestion with load tracking
- **Silver Layer**: Cleansed, structured data with versioning
- **Gold Layer**: Production-approved mappings
- **Audit Layer**: Complete change history across all layers

---

## Architecture

### Project Structure

```
Propelus_AI/
├── shared/                              # Shared TypeScript code
│   ├── database/
│   │   ├── entities/                    # TypeORM entities
│   │   └── connection.ts
│   ├── types/                           # TypeScript interfaces
│   └── utils/                           # Common utilities
│
├── lambdas/                             # AWS Lambda functions
│   ├── ingestion_and_cleansing/        # Bronze → Silver transformation
│   ├── taxonomy_mapping_command/       # Rule-based mapping engine
│   ├── mapping_rules/                  # Multi-strategy matching
│   └── translation/                    # Real-time translation
│
├── data/
│   ├── migrations/                     # Database migrations (001-026)
│   └── production/                     # Production deployment scripts
│
├── docs/                               # Documentation
└── infrastructure/                     # AWS infrastructure definitions
```

### Lambda Functions

#### 1. Ingestion & Cleansing Lambda
**Purpose**: Transform raw taxonomy data from Bronze to Silver layer

**Features**:
- Excel and API data parsing
- Rolling ancestor memory for hierarchy resolution
- Multi-valued cell handling
- Load lifecycle tracking

#### 2. Taxonomy Mapping Command Lambda
**Purpose**: Deterministic rule-based mapping

**Features**:
- Priority-based rule execution
- Command support: equals, contains, startswith, endswith, regex
- Automatic versioning
- Gold layer synchronization

#### 3. Mapping Rules Lambda
**Purpose**: Advanced multi-strategy matching

**Matching Strategies**:
1. Exact Match (100% confidence)
2. NLP Qualifier Match (90-95% confidence)
3. Fuzzy Match (70-90% confidence)
4. AI Semantic Match (variable confidence)

#### 4. Translation Lambda
**Purpose**: Real-time taxonomy translation

**Features**:
- Existing mapping lookup
- AI-powered translation fallback
- Redis caching (1-hour TTL)
- Alternative suggestions

---

## Database Schema

### Tables
- **Bronze Layer**: 2 tables (load_details, taxonomies)
- **Silver Layer**: 14 tables (taxonomies, nodes, attributes, mappings, versions)
- **Gold Layer**: 1 table (approved mappings)
- **Audit Layer**: 12 log tables

### Key Features
- BIGINT identity columns for scalability
- Complete data lineage (load_id, row_id tracking)
- Status-based soft deletes
- Version history for taxonomies and mappings

---

## Installation

### Prerequisites
- Node.js 20+
- PostgreSQL 15+ (Aurora recommended)
- AWS Account with IAM permissions
- AWS CLI configured

### Setup

```bash
# Install dependencies
npm install

# Build all packages
npm run build

# Run database migrations
npm run migrate
```

---

## Deployment

### Production Database Setup

```bash
cd data/production

# 1. Setup roles and database
psql -h <aurora-endpoint> -U postgres -f 01-setup-roles.sql

# 2. Install extensions
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 02-extensions.sql

# 3. Create tables
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f production-ddl.sql

# 4-9. Create indexes
for i in 05 06 07 08 09 10; do
  psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f ${i}-indexes-*.sql
done

# 10. Seed N/A node
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 03-seed-na-node.sql

# 11. Transfer ownership
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 04-ownership-transfer.sql
```

See [Production Setup README](./data/production/README.md) for complete instructions.

### Lambda Deployment

```bash
# Package Lambda
cd lambdas/<lambda-name>
npm run build
npm run package

# Deploy with AWS CLI
aws lambda update-function-code \
  --function-name <function-name> \
  --zip-file fileb://function.zip
```

---

## Configuration

### Environment Variables

```bash
# Database
PGHOST=<aurora-endpoint>
PGPORT=5432
PGDATABASE=taxonomy
PGSCHEMA=taxonomy_schema
PGUSER=lambda_user
PGPASSWORD=<password>
PGSSLMODE=require

# AWS Services
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0

# Optional: Redis Cache
REDIS_ENABLED=true
REDIS_HOST=<redis-endpoint>
REDIS_PORT=6379
```

---

## Customer Identifiers

**Format**: `subsystem-clientid` (VARCHAR 255)

The system uses string-based customer identifiers to support multiple client subsystems with their own naming conventions.

**Examples**:
- `evercheck-719` - EverCheck customer ID 719
- `datasolutions-123` - DataSolutions customer ID 123
- `cebroker-456` - CE Broker customer ID 456

**Pattern**: Lowercase alphanumeric with hyphen separator (`^[a-z0-9]+-[a-z0-9]+$`)

This allows each subsystem (EverCheck, DataSolutions, CE Broker) to maintain their own customer identification scheme while ensuring global uniqueness across the taxonomy service.

---

## API Endpoints

**Specification**: `infrastructure/openapi/taxonomy-api-spec.yaml` (OpenAPI 3.1)

### Core Endpoints

```
POST   /v1/ingest          - Ingest taxonomy data (full reload)
POST   /v1/translate       - Translate profession code
GET    /v1/taxonomies      - List taxonomies
GET    /v1/taxonomies/{id} - Get taxonomy details
GET    /v1/mappings        - Query mappings
POST   /v1/verify          - Human verification
```

---

## Documentation

### Algorithm & Implementation
- [Algorithm v1.0 Implementation](./ALGORITHM_V1_IMPLEMENTATION_SUMMARY.md)
- [API Documentation](./API_DOCUMENTATION.md)

### Database
- [Production Setup Guide](./data/production/README.md)
- [Migration Guide](./data/migrations/README_NEW_MIGRATIONS.md)
- [Schema Changes Summary](./docs/SCHEMA_CHANGES_SUMMARY.md)

### Lambda Functions
- [Ingestion Lambda README](./lambdas/ingestion_and_cleansing/README.md)
- [Mapping Command Lambda README](./lambdas/taxonomy_mapping_command/README.md)
- [Mapping Rules Lambda README](./lambdas/mapping_rules/README.md)

### NLP Integration
- [NLP Integration Overview](./docs/nlp/NLP_INTEGRATION_OVERVIEW.md)
- [Matcher Specification](./docs/nlp/MATCHER_SPECIFICATION.md)

### Architecture
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Master Taxonomy Research](./docs/MASTER_TAXONOMY_RESEARCH.md)
- [OpenAPI Specification](./infrastructure/openapi/taxonomy-api-spec.yaml)

---

## Testing

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

---

## Performance

### Lambda Optimization
- Memory: 512MB-1024MB based on workload
- Timeout: 60s (Translation) to 300s (Ingestion/Mapping)
- Connection pooling: Max 2 connections per Lambda

### Database Optimization
- 200+ performance indexes (GIN, BRIN, B-tree)
- Trigram indexes for fuzzy text search
- JSONB path operators for metadata queries

---

## Security

### Database
- IAM authentication for Lambda users
- SSL/TLS encryption in transit
- Encryption at rest (Aurora)
- Least-privilege role permissions

### API
- API key authentication
- VPC configuration for Lambda and RDS
- CloudWatch Logs encryption

---

## Monitoring

### CloudWatch Metrics
- Lambda invocations, duration, errors
- Database connections, CPU, memory
- Step Functions execution status

### Alerts
- Lambda error rates
- Database connection pool saturation
- Low-confidence mapping rates

---

## Support

For technical support or questions:
- Review CloudWatch Logs for Lambda errors
- Check Aurora Performance Insights
- Verify IAM permissions and policies
- Consult documentation in `/docs` folder

---

## License

Copyright © 2025 Propelus AI

---

**Last Updated**: January 21, 2025
**Version**: 4.1.0
**Lead Engineer**: Douglas Martins, Senior AI Engineer/Architect
