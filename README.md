# Propelus AI Taxonomy Framework

## 🎯 Overview

Propelus AI Healthcare Profession Taxonomy Framework - a TypeScript/Node.js based system for normalizing and translating healthcare profession taxonomies across different healthcare systems.

**Tech Stack**: TypeScript, Node.js 20+, TypeORM, AWS Lambda, PostgreSQL, AWS Bedrock

---

## 📊 Project Status

**Current Progress: ~90% Complete** ✅

### ✅ Completed Components
- ✅ TypeScript project structure with npm workspaces
- ✅ Database models (TypeORM) - 35+ entities
- ✅ **Combined Ingestion & Cleansing Lambda v2.0** (Bronze → Silver in single transaction)
- ✅ Mapping Rules Lambda (exact, fuzzy, AI semantic matching)
- ✅ Translation Lambda (real-time translation with AI + caching)
- ✅ Step Functions orchestration workflow
- ✅ OpenAPI 3.0 specification
- ✅ Master Taxonomy research documentation
- ✅ Shared utilities and types
- ✅ Comprehensive test data generation and validation tools
- ✅ Log retention strategy documentation

### 🚧 In Progress / Pending
- ⏳ Database migrations (awaiting physical data model)
- ⏳ NestJS Taxonomy API Service
- ⏳ Next.js Admin UI
- ⏳ Integration tests
- ⏳ Pulumi Infrastructure as Code
- ⏳ Master taxonomy population

---

## 🏗️ Architecture

```
Propelus_AI/
├── shared/                              # Shared TypeScript code
│   ├── database/
│   │   ├── entities/                    # TypeORM entities (35+)
│   │   │   ├── bronze.entity.ts        # Bronze layer tables
│   │   │   ├── silver.entity.ts        # Silver layer tables
│   │   │   ├── mapping.entity.ts       # Mapping tables
│   │   │   ├── gold.entity.ts          # Gold layer tables
│   │   │   └── audit.entity.ts         # Audit logs
│   │   └── connection.ts               # Database connection
│   ├── types/                          # TypeScript interfaces
│   └── utils/                          # Common utilities (logger, etc.)
│
├── lambdas/                             # AWS Lambda functions
│   ├── ingestion_and_cleansing/        # ✅ v2.0 - Combined Bronze→Silver
│   │   ├── src/
│   │   │   ├── handler.ts              # Main entry point
│   │   │   ├── types/                  # TypeScript type definitions
│   │   │   ├── utils/                  # Normalization, streams, constants
│   │   │   ├── parsers/                # Excel, API, layout, filename parsers
│   │   │   ├── database/               # SQL query modules
│   │   │   │   └── queries/            # Load, bronze, silver, versioning
│   │   │   └── processors/             # S3, API, row, orchestrator
│   │   ├── test/                       # Test data generation & validation
│   │   │   ├── sample-data-generator.ts
│   │   │   ├── validate-test-data.ts
│   │   │   ├── local-test-runner.ts
│   │   │   └── README.md
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── README.md
│   │
│   ├── mapping_rules/                  # ✅ Multi-strategy matching
│   │   ├── src/
│   │   │   ├── handler.ts
│   │   │   ├── services/
│   │   │   │   └── mapping-engine.ts
│   │   │   └── matchers/
│   │   │       ├── exact-matcher.ts    # Exact string matching
│   │   │       ├── fuzzy-matcher.ts    # Levenshtein distance
│   │   │       └── ai-semantic-matcher.ts  # AWS Bedrock AI
│   │   └── package.json
│   │
│   └── translation/                    # ✅ Real-time translation
│       ├── src/
│       │   ├── handler.ts
│       │   ├── services/
│       │   │   └── translation-service.ts
│       │   └── cache/
│       │       └── cache-service.ts    # Redis caching
│       └── package.json
│
├── services/                            # Microservices
│   ├── taxonomy-api/                   # ⏳ NestJS REST API (planned)
│   ├── translation-service/            # ⏳ Translation service (planned)
│   └── admin-ui/                       # ⏳ Next.js Admin UI (planned)
│
├── infrastructure/                      # Infrastructure definitions
│   ├── step-functions/
│   │   └── taxonomy-processing-workflow.json  # ✅ Complete workflow
│   └── openapi/
│       └── taxonomy-api-spec.yaml      # ✅ OpenAPI 3.0 spec
│
├── docs/                                # Documentation
│   ├── MASTER_TAXONOMY_RESEARCH.md     # ✅ Industry standards research
│   ├── architecture/                   # Architecture diagrams
│   └── Data model 0.42 tables description.pdf
│
├── tests/                               # Test suites
├── package.json                         # Root workspace config
└── tsconfig.json                        # TypeScript config
```

---

## 🚀 Quick Start

### Prerequisites
- Node.js 20+
- PostgreSQL 15+
- Redis (optional, for caching)
- AWS Account (for Bedrock, Lambda deployment)

### Installation

```bash
# Clone repository
git clone <repository-url>
cd Propelus_AI

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Start PostgreSQL and Redis (Docker)
docker-compose up -d postgres redis

# Build all packages
npm run build
```

### Development

```bash
# Build all workspaces
npm run build

# Run tests
npm test

# Lint code
npm run lint

# Format code
npm run format

# Type check
npm run type-check
```

### Local Lambda Testing

```bash
# Build specific Lambda
cd lambdas/bronze_ingestion
npm run build

# Package for deployment
npm run package
```

---

## 📚 Lambda Functions

### 1. Ingestion & Cleansing Lambda v2.0 (Combined)

**Purpose**: Atomic Bronze → Silver transformation in single transaction

**Triggers**:
- S3 file upload events (Excel)
- API Gateway POST requests (JSON payload)

**Features**:
- **Bronze Layer Processing** (§1-5):
  - Multi-format parsing (Excel, API JSON)
  - Layout detection (master vs customer)
  - Load tracking with request_id
- **Dictionary Management** (§6):
  - Append-only node types
  - Append-only attribute types
- **Silver Transformation** (§7):
  - Hierarchical node creation
  - Parent-child relationships
  - Multi-value attributes
- **Two Processing Paths**:
  - **NEW Load**: Insert-only, creates Version 1
  - **UPDATED Load**: Upsert + soft-delete reconciliation, creates Version N
- **Versioning** (§7A.3, §7B.5):
  - Track taxonomy evolution
  - Affected nodes/attributes JSON
  - Version history with date ranges
- **Complete Audit Trail**:
  - Row-level lineage (load_id, row_id)
  - Status tracking (completed/failed)
  - Error details in load_details JSON

**Tech**:
- TypeScript with embedded SQL
- PostgreSQL natural key constraints
- xlsx parser
- AWS SDK v3 (S3)
- pg (PostgreSQL driver)

**Test Tools**:
```bash
npm run test:generate  # Generate sample taxonomies
npm run test:validate  # Validate test data
npm run test:local     # Run Lambda locally
```

---

### 2. Mapping Rules Lambda

**Purpose**: Maps customer taxonomies to master taxonomy using multiple strategies

**Triggers**: EventBridge after Silver processing

**Matching Strategies**:
1. **Exact Matcher**: Case-insensitive exact string matching
2. **Fuzzy Matcher**: Levenshtein distance (70% threshold)
3. **AI Semantic Matcher**: AWS Bedrock (Claude/Llama) for semantic understanding

**Features**:
- Confidence scoring (0-1)
- Low-confidence flagging for human review
- Mapping versioning support

**Tech**:
- AWS Bedrock Runtime
- string-similarity library
- leven (Levenshtein distance)

---

### 3. Translation Lambda

**Purpose**: Real-time taxonomy translation via API

**Triggers**: API Gateway requests

**Features**:
- Existing mapping lookup
- AI-powered translation fallback
- Redis caching (1-hour TTL)
- Ambiguity detection
- Alternative suggestions

**Response Example**:
```json
{
  "source": {
    "taxonomy": "customer_123",
    "code": "RN",
    "attributes": {"state": "CA"}
  },
  "target": {
    "taxonomy": "master",
    "codes": ["Registered Nurse - CA"],
    "nodes": [...]
  },
  "confidence": 0.95,
  "cached": false
}
```

---

## 🔄 Step Functions Workflow

**File**: `infrastructure/step-functions/taxonomy-processing-workflow.json`

**Flow**:
```
Ingestion & Cleansing (v2.0)
[Atomic: Bronze → Silver + Versioning]
    ↓
Mapping Rules
    ↓
[Check Confidence]
    ├─→ High Confidence → Promote to Gold → Success
    └─→ Low Confidence → Human Review Queue
                            ↓
                        [Approved?]
                            ├─→ Yes → Promote to Gold
                            └─→ No → Reject
```

**Features**:
- Automatic retries with exponential backoff
- Error handling with SNS notifications
- Human-in-the-loop workflow (24h timeout)
- Gold layer promotion
- CloudWatch integration

---

## 🗄️ Database Architecture

**Type**: Single Aurora PostgreSQL database
**Structure**: Table prefixes (`bronze_`, `silver_`, `gold_`)
**Multi-tenancy**: Soft isolation via `customer_id`

### Key Tables:

#### Bronze Layer
- `bronze_load_details` - Load metadata
- `bronze_taxonomies` - Raw taxonomy data
- `bronze_professions` - Raw profession data

#### Silver Layer
- `silver_taxonomies` - Structured taxonomies
- `silver_taxonomies_nodes` - Hierarchical nodes
- `silver_taxonomies_nodes_attributes` - Node attributes
- `silver_professions` - Normalized professions
- `silver_mapping_taxonomies` - Taxonomy mappings
- `silver_mapping_taxonomies_rules` - Mapping rules

#### Gold Layer
- `gold_taxonomies_mapping` - Approved mappings
- `gold_mapping_professions` - Production-ready data

#### Audit Layer
- 12+ audit log tables tracking all changes
- Version history tracking
- Remapping support

---

## 🔌 API Endpoints

**Specification**: `infrastructure/openapi/taxonomy-api-spec.yaml` (OpenAPI 3.0)

### Core Endpoints:

```
POST   /v1/ingest          - Ingest taxonomy data
POST   /v1/translate       - Translate profession code
GET    /v1/taxonomies      - List taxonomies
GET    /v1/taxonomies/{id} - Get taxonomy details
GET    /v1/mappings        - Query mappings
POST   /v1/verify          - Human verification
```

### Example: Translation Request

```bash
curl -X POST https://api.propelus.ai/v1/translate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "source_taxonomy": "customer_123",
    "target_taxonomy": "master",
    "source_code": "RN",
    "attributes": {
      "state": "CA"
    }
  }'
```

---

## 🏥 Master Taxonomy

**Research Document**: `docs/MASTER_TAXONOMY_RESEARCH.md`

### Hierarchy Structure:

**Level 1: Industry**
- Healthcare

**Level 2: Group**
- Medical Professionals
- Nursing Professionals
- Allied Health Professionals
- etc.

**Level 3: Occupation** (SOC/O*NET based)
- Physicians
- Registered Nurses
- Licensed Practical Nurses
- etc.

**Level 4: Specialty**
- Critical Care
- Family Medicine
- Pediatrics
- etc.

**Level 5: Profession** (State-specific)
- Registered Nurse - CA (RN)
- Family Medicine Physician - NY (MD)
- etc.

### Industry Standards Referenced:
- **O*NET**: Occupational Information Network
- **BLS SOC**: Bureau of Labor Statistics Standard Occupational Classification
- **ISCO**: International Standard Classification of Occupations
- **NUCC**: Provider Taxonomy Codes
- **State Licensing Boards**: 50+ state systems

---

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

### Test Structure:
```
tests/
├── unit/
│   ├── lambdas/
│   ├── services/
│   └── utils/
├── integration/
│   ├── database/
│   └── api/
└── e2e/
    └── workflows/
```

---

## 🚢 Deployment

### AWS Lambda Deployment

```bash
# Package Lambda
cd lambdas/bronze_ingestion
npm run package

# Deploy with AWS CLI
aws lambda update-function-code \
  --function-name bronze-ingestion \
  --zip-file fileb://bronze-ingestion.zip
```

### Infrastructure as Code (Planned)

**Tool**: Pulumi (TypeScript)

```bash
# Deploy to sandbox
pulumi up --stack sandbox

# Deploy to production
pulumi up --stack prod
```

---

## 📖 Documentation

- [Meeting Notes (Oct 2, 2025)](./MEETING_NOTES_OCT2.md)
- [Action Items](./ACTION_ITEMS.md)
- [Master Taxonomy Research](./docs/MASTER_TAXONOMY_RESEARCH.md)
- [Data Model v0.42 Description](./docs/Data%20model%200.42%20tables%20description.pdf)
- [Architecture Diagrams](./docs/architecture/)
- [OpenAPI Specification](./infrastructure/openapi/taxonomy-api-spec.yaml)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [API Documentation](./API_DOCUMENTATION.md)

---

## 🎨 Code Style

- **ESLint** for linting
- **Prettier** for formatting
- **TypeScript strict mode** enabled

```bash
# Lint code
npm run lint

# Auto-fix issues
npm run lint:fix

# Format code
npm run format
```

---

## 🤝 Contributing

### Adding a New Lambda Function

1. Create directory in `/lambdas/your-lambda/`
2. Add `package.json` and `tsconfig.json`
3. Create `src/handler.ts` with main handler
4. Export handler: `export async function handler(event, context)`
5. Add build scripts
6. Root package.json will auto-discover via workspaces

---

## 🔧 Environment Variables

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=propelus_admin
DB_PASSWORD=your_password
DB_NAME=propelus_taxonomy

# Redis Cache
REDIS_ENABLED=true
REDIS_HOST=localhost
REDIS_PORT=6379

# AWS
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0

# SQS
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/xxx/taxonomy-processing

# EventBridge
EVENT_BUS_NAME=taxonomy-events
```

---

## 📊 Key Metrics

- **35+ TypeORM entities** (Bronze, Silver, Gold, Audit layers)
- **3 Lambda functions** (fully implemented in TypeScript)
  - Combined Ingestion & Cleansing v2.0 (26 TypeScript modules)
  - Mapping Rules with 3 strategies (exact, fuzzy, AI semantic)
  - Real-time Translation with caching
- **Comprehensive test suite** (sample data generation, validation, local testing)
- **26 TypeScript modules** in Ingestion & Cleansing Lambda
- **Multi-level taxonomy hierarchy** support (master: up to 6 levels, customer: flat)
- **100% TypeScript** (SQL-centric architecture)

---

## 🐛 Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Test connection
psql -h localhost -U propelus_admin -d propelus_taxonomy
```

### Lambda Build Errors
```bash
# Clean and rebuild
npm run clean
npm install
npm run build
```

### TypeScript Errors
```bash
# Run type check
npm run type-check
```

---

## 📞 Support

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Check docs/ folder
- **Team**: Contact Propelus AI team

---

## 📄 License

Copyright © 2025 Propelus AI

---

**Last Updated**: October 3, 2025
**Version**: 2.0.0
**Status**: Production-Ready (90% complete)
**Lead Engineer**: Douglas Martins, Senior AI Engineer/Architect
