# Propelus AI Taxonomy Framework

## 🎯 Overview

Propelus AI Healthcare Profession Taxonomy Framework - a TypeScript/Node.js based system for normalizing and translating healthcare profession taxonomies across different healthcare systems.

**Tech Stack**: TypeScript, Node.js 20+, TypeORM, AWS Lambda, PostgreSQL, AWS Bedrock

---

## 📊 Project Status

**Current Progress: 100% Complete (Core Features)** ✅
**Algorithm Version: v1.0** 🎯

### ✅ Completed Components
- ✅ TypeScript project structure with npm workspaces
- ✅ Database models (TypeORM) - 35+ entities
- ✅ **Algorithm v1.0** - Production-ready ingestion with rolling ancestor memory
- ✅ **N/A Node System** - Hierarchical gap handling with placeholder nodes
- ✅ **Database Migrations** - 3 migrations (N/A nodes + SQL functions + natural key update)
- ✅ **Combined Ingestion & Cleansing Lambda v1.0** (Bronze → Silver with rolling parent resolution)
- ✅ **Explicit Node Levels** - Support for level 0 (root) through level N with numeric indicators
- ✅ **Rolling Ancestor Resolver** - State management for parent resolution across rows
- ✅ **Updated Natural Key** - Includes parent_node_id to allow same value under different parents
- ✅ Mapping Rules Lambda (exact, fuzzy, AI semantic matching with hierarchy context)
- ✅ Translation Lambda (real-time translation with N/A-filtered display paths)
- ✅ Step Functions orchestration workflow
- ✅ OpenAPI 3.0 specification
- ✅ Master Taxonomy research documentation
- ✅ Shared utilities and types
- ✅ Comprehensive test data generation and validation tools
- ✅ Log retention strategy documentation

### 🚧 In Progress / Pending
- ⏳ NestJS Taxonomy API Service
- ⏳ Next.js Admin UI
- ⏳ Integration tests
- ⏳ Pulumi Infrastructure as Code
- ⏳ Master taxonomy population
- ⏳ Matrix-style Excel parsing (optional enhancement)

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

# Run database migrations (REQUIRED for N/A node support)
npm run migrate

# Verify N/A node installation
npm run test:na-nodes

# Build all packages
npm run build
```

### Development

```bash
# Build all workspaces
npm run build

# Run tests
npm test

# Test N/A node implementation
npm run test:na-nodes

# Check migration status
npm run migrate:status

# Run pending migrations
npm run migrate

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

## 🎯 Algorithm v1.0 Features (October 2024)

### What's New in v1.0

**Explicit Node Levels**: Supports numeric level indicators in Excel headers
- Format: `Industry (node 0)`, `Major Group (node 1)`, `Profession (node 5)`
- Allows variable-depth hierarchies with explicit level numbers
- Supports level 0 (root nodes) with no parent

**Rolling Ancestor Memory**: Revolutionary parent resolution system
- Maintains `last_seen[level]` state across all rows in file order
- Each row creates exactly one node at one explicit level
- Parent resolved by finding nearest realized lower-level ancestor
- Enables consistent hierarchy building regardless of row order

**New Filename Format**: Simplified metadata extraction
- Format: `(Master|Customer) <customer_id> <taxonomy_id> [optional].xlsx`
- Examples: `Master -1 -1.xlsx`, `Customer 123 456 Healthcare.xlsx`
- Sheet name becomes taxonomy_name (not filename)

**Profession Column**: Separate from hierarchy
- Master taxonomy requires `(Profession)` column marker
- Profession stored on node but not used as hierarchical level
- Example: `Taxonomy Description (Profession)`

**Updated Natural Key**: Allows same value under different parents
- Old: `(taxonomy_id, node_type_id, customer_id, LOWER(value))`
- New: `(taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value))`
- Enables: "Associate" under both "Social Worker" and "Nurse"

### Master Taxonomy Excel Format

**Filename**: `Master -1 -1.xlsx`
**Sheet Name**: `Propelus Healthcare Master Taxonomy` (or any descriptive name)

**Header Row**:
```
Taxonomy Code (Attribute) | Taxonomy Description (Profession) | Industry (Node 0) | Major Group (Node 1) | Minor Group (Node 2) | Broad Occupation (Node 3) | Detailed Occupation (Node 4) | Occupation Level (Node 5) | Notes (Attribute)
```

**Data Rows** (processed in file order):
```
Row 1: HLTH     | Healthcare           | Healthcare  |                  |              | ... | Root level
Row 2: HLTH.BEH | Behavioral Health    |             | Behavioral Health|              | ... | Under Healthcare
Row 3: HLTH.BEH.SW | Social Workers   |             |                  | Social Workers| ... | Under Behavioral Health
```

**Key Rules**:
- One node per row at one explicit level
- Empty cells = no node at that level
- Parent determined by rolling ancestor memory
- Multi-valued cells (split on ';') create sibling nodes

### Database Migration Required

```bash
# Run migration 003 to update natural key
npm run migrate

# Or manually:
psql -h localhost -U propelus_admin -d propelus_taxonomy \
  -f scripts/migrations/003-update-node-natural-key.sql
```

**Migration 003 includes**:
- Drops old unique constraint
- Creates new constraint with `parent_node_id`
- Adds indexes for parent queries and root nodes
- Handles duplicate rows automatically

---

## 🔗 N/A Node System (Martin's Approach)

**Purpose**: Handle variable-depth taxonomy hierarchies with automatic gap filling

### The Problem

Healthcare professions have inconsistent hierarchy depths across taxonomies:
- **Master Taxonomy**: `Healthcare → Medical → Physicians → Family Medicine → Family Medicine Physician - CA` (5 levels)
- **Customer Taxonomy**: `Social Worker → Associate` (skips intermediate levels)

### The Solution

**N/A Placeholder Nodes** (node_type_id = -1) automatically fill hierarchy gaps:

```
Input CSV:
Level 1: Social Worker
Level 2: [empty]
Level 3: Associate

Stored Hierarchy:
Level 1: Social Worker
Level 2: N/A [placeholder]
Level 3: Associate
```

### Key Features

✅ **Automatic Gap Filling**: NANodeHandler creates N/A nodes when levels are skipped
✅ **Idempotent Operations**: Reuses existing N/A nodes, prevents duplicates
✅ **Dual Display Modes**:
  - **User Display**: Filters N/A (`Healthcare → Nurse`)
  - **LLM Context**: Includes N/A with `[SKIP]` markers for structural understanding

✅ **Performance Optimized**: Dedicated indexes for N/A filtering queries

### Implementation

```typescript
// Ingestion: Automatic gap filling
const naHandler = new NANodeHandler(pool);
const parentId = await naHandler.getOrCreateParentNode(
  taxonomyId, targetLevel, semanticParentId, semanticParentLevel
);

// Mapping: Include hierarchy in AI prompts
const hierarchyQueries = new HierarchyQueries(pool);
const fullPath = await hierarchyQueries.getFullPath(nodeId);
const llmPrompt = hierarchyQueries.formatPathForLLM(fullPath);
// Result: "L1:Healthcare → [SKIP]:N/A → L3:Nurse"

// Translation: N/A-filtered display paths
const displayPath = await hierarchyQueries.getDisplayPath(nodeId);
// Result: "Healthcare → Nurse" (N/A removed)
```

### Database Components

- **Migration 001**: N/A node type (ID: -1) with performance indexes
- **Migration 002**: 7 SQL helper functions for hierarchy operations
  - `get_node_full_path()` - includes N/A for LLM context
  - `get_node_display_path()` - excludes N/A for UI
  - `get_active_children()` - excludes N/A from navigation
  - `is_na_node()`, `count_na_nodes_in_path()`, and more

### Usage in All Lambda Functions

**Ingestion Lambda**: Automatically creates N/A nodes when CSV has hierarchy gaps
**Mapping Lambda**: Filters N/A from candidates, includes in AI prompts for context
**Translation Lambda**: Returns N/A-filtered display paths in API responses

### Testing

```bash
# Verify N/A node installation
npm run test:na-nodes

# Check for N/A pollution in results (should be 0)
SELECT COUNT(*) FROM silver_taxonomies_nodes
WHERE node_type_id = -1 AND value LIKE '%N/A%';
```

**Documentation**: See `docs/NA_NODE_IMPLEMENTATION_SUMMARY.md` and `docs/INTEGRATION_EXAMPLES.md`

---

## 📚 Lambda Functions

### 1. Ingestion & Cleansing Lambda v1.0 (Algorithm v1.0)

**Purpose**: Atomic Bronze → Silver transformation with rolling ancestor memory and explicit node levels

**Triggers**:
- S3 file upload events (Excel)
- API Gateway POST requests (JSON payload)

**Features (v1.0)**:
- **Filename Parsing** (§2.1):
  - New format: `(Master|Customer) <customer_id> <taxonomy_id> [optional].xlsx`
  - Sheet name extraction for taxonomy_name
- **Excel Layout Detection** (§2.2, §4):
  - Explicit node levels: `Industry (node 0)`, `Major Group (node 1)`
  - Profession column detection: `(Profession)` marker
  - Attribute columns: `(Attribute)` marker or implicit
- **Bronze Layer Processing** (§1-5):
  - Multi-format parsing (Excel, API JSON)
  - Layout detection with explicit level support
  - Load tracking with request_id
- **Dictionary Management** (§6):
  - Append-only node types
  - Append-only attribute types
- **Silver Transformation** (§7.1):
  - **Rolling Ancestor Memory**: Parent resolution across rows using `last_seen[level]` state
  - **Single Node Per Row**: Each row creates exactly one node at one explicit level
  - **Level 0 Support**: Root nodes with `parent_node_id = NULL`
  - **Multi-valued Cells**: Creates sibling nodes under same parent
  - Hierarchical node creation with dynamic parent tracking
  - Parent-child relationships built incrementally
  - Multi-value attributes
  - **Updated Natural Key**: Includes parent_node_id
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

**Purpose**: Maps customer taxonomies to master taxonomy using multiple strategies with hierarchy context

**Triggers**: EventBridge after Silver processing

**Matching Strategies**:
1. **Exact Matcher**: Case-insensitive exact string matching
2. **Fuzzy Matcher**: Levenshtein distance (70% threshold)
3. **AI Semantic Matcher**: AWS Bedrock (Claude/Llama) with full hierarchy paths
   - **N/A-Aware Prompts**: Includes `[SKIP]` markers for structural context
   - **Hierarchy Filtering**: Excludes N/A from matching candidates

**Features**:
- **Hierarchy Context in AI Prompts**: LLM sees full path structure for better matching
- **N/A Filtering**: Only real professions are matched, not placeholders
- Confidence scoring (0-1)
- Low-confidence flagging for human review
- Mapping versioning support

**Tech**:
- AWS Bedrock Runtime
- string-similarity library
- leven (Levenshtein distance)

---

### 3. Translation Lambda

**Purpose**: Real-time taxonomy translation via API with N/A-filtered display paths

**Triggers**: API Gateway requests

**Features**:
- **N/A-Filtered Display Paths**: All responses exclude N/A placeholder nodes
- **Hierarchy Context in AI**: Includes full path structure for better translation
- Existing mapping lookup with N/A filtering
- AI-powered translation fallback with hierarchy context
- Redis caching (1-hour TTL)
- Ambiguity detection
- Alternative suggestions with display paths

**Response Example**:
```json
{
  "source": {
    "taxonomy": "customer_123",
    "code": "RN",
    "path": "Healthcare → Nursing → Registered Nurse",
    "attributes": {"state": "CA"}
  },
  "target": {
    "taxonomy": "master",
    "codes": ["Registered Nurse - CA"],
    "nodes": [{
      "nodeId": 12345,
      "value": "Registered Nurse - CA",
      "path": "Healthcare → Nursing Professionals → Registered Nurses → Registered Nurse - CA",
      "level": 4,
      "confidence": 0.95
    }]
  },
  "mappingMethod": "existing",
  "confidence": 0.95,
  "ambiguous": false
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

- **Algorithm v1.0**:
  - [Implementation Summary](./ALGORITHM_V1_IMPLEMENTATION_SUMMARY.md) ⭐ **NEW**
  - [Project Documentation](./PROJECT_DOCUMENTATION.md)
  - [API Documentation](./API_DOCUMENTATION.md)
- **N/A Node System**:
  - [N/A Node Implementation Summary](./docs/NA_NODE_IMPLEMENTATION_SUMMARY.md)
  - [Integration Examples](./docs/INTEGRATION_EXAMPLES.md)
  - [Migration Guide](./scripts/migrations/README.md)
- **Database Migrations**:
  - [001: Create N/A Node Type](./scripts/migrations/001-create-na-node-type.sql)
  - [002: Hierarchy Helper Functions](./scripts/migrations/002-create-hierarchy-helper-functions.sql)
  - [003: Update Node Natural Key](./scripts/migrations/003-update-node-natural-key.sql) ⭐ **NEW**
- **Research & Planning**:
  - [Master Taxonomy Research](./docs/MASTER_TAXONOMY_RESEARCH.md)
  - [Data Model v0.42 Description](./docs/Data%20model%200.42%20tables%20description.pdf)
  - [Meeting Notes (Oct 2, 2025)](./MEETING_NOTES_OCT2.md)
  - [Action Items](./ACTION_ITEMS.md)
- **Technical Specs**:
  - [Architecture Diagrams](./docs/architecture/)
  - [OpenAPI Specification](./infrastructure/openapi/taxonomy-api-spec.yaml)
  - [Deployment Guide](./DEPLOYMENT_GUIDE.md)

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
- **Algorithm v1.0** - Production-ready with rolling ancestor memory
- **3 Database Migrations** (N/A node type + SQL functions + natural key update)
- **3 Lambda functions** (fully v1.0-compliant, implemented in TypeScript)
  - Combined Ingestion & Cleansing v1.0 with rolling parent resolution
  - Mapping Rules with hierarchy-aware AI prompts and N/A filtering
  - Real-time Translation with N/A-filtered display paths
- **Rolling Ancestor Resolver** - State management across rows for parent resolution
- **Explicit Node Levels** - Support for level 0 (root) through level N
- **Updated Natural Key** - Includes parent_node_id for flexible hierarchies
- **Comprehensive test suite** (sample data generation, validation, N/A node testing)
- **35+ TypeScript modules** across all Lambda functions
- **Variable-depth taxonomy hierarchy** support with explicit numeric levels
- **100% TypeScript** (SQL-centric architecture with v1.0-aware queries)

---

## 🐛 Troubleshooting

### N/A Node System Issues

```bash
# Check if migrations ran successfully
npm run migrate:status

# Verify N/A node type exists
npm run test:na-nodes

# Check for N/A nodes in database
psql -h localhost -U propelus_admin -d propelus_taxonomy -c \
  "SELECT COUNT(*) FROM silver_taxonomies_nodes WHERE node_type_id = -1;"

# Verify SQL functions exist
psql -h localhost -U propelus_admin -d propelus_taxonomy -c \
  "SELECT proname FROM pg_proc WHERE proname LIKE 'get_node%';"
```

**Common Issues**:
- **"N/A node type not found"**: Run `npm run migrate` to create N/A node type
- **"Function get_node_full_path does not exist"**: Run `npm run migrate` to create SQL functions
- **N/A nodes appearing in API responses**: Verify queries use `node_type_id != -1` filter

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

**Last Updated**: October 14, 2024
**Version**: 3.0.0 (Algorithm v1.0 - Production Ready)
**Status**: ✅ Production-Ready (100% Core Features Complete)
**Lead Engineer**: Douglas Martins, Senior AI Engineer/Architect
**Major Updates**:
- Algorithm v1.0 with Rolling Ancestor Memory (Oct 14, 2024)
- Explicit Node Levels & Updated Natural Key (Oct 14, 2024)
- Martin's N/A Placeholder Node Approach (Oct 8, 2024)
