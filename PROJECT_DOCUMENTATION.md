# Propelus Healthcare Taxonomy Project Documentation

## Executive Summary
The Propelus Taxonomy Framework is an AI-powered system for standardizing healthcare profession data across multiple customers and taxonomies. It uses a three-layer data architecture (Bronze, Silver, Gold) with Lambda functions for processing, mapping professions to a master taxonomy using both deterministic rules and AI/LLM capabilities.

## System Architecture Overview

### Data Flow Architecture
```
Customer Data → Bronze Layer → Silver Layer → Gold Layer → APIs
                     ↓              ↓            ↓
              (Raw Storage)  (Cleaned Data) (Final Mappings)
```

### Three-Layer Data Architecture

#### 1. Bronze Layer (Raw Data)
- **Purpose**: Store raw, unprocessed data exactly as received
- **Tables**:
  - `bronze_taxonomies`: Raw taxonomy data ingestion from API
  - `bronze_professions`: Raw profession data with attributes
- **Format**: Customer ID, row_json, load date, type (new/updated)

#### 2. Silver Layer (Cleaned & Structured)
- **Purpose**: Cleaned, normalized, and structured data with mapping rules
- **Core Tables**:
  - `silver_taxonomies`: Hierarchical taxonomy metadata
  - `silver_taxonomies_nodes_types`: Node type definitions (6 levels)
  - `silver_taxonomies_nodes`: Hierarchical nodes within taxonomies
  - `silver_taxonomies_nodes_attributes`: Node attributes
  - `silver_professions`: Non-hierarchical profession data
  - `silver_professions_attributes`: Profession attributes
- **Taxonomy Mapping Tables**:
  - `silver_mapping_taxonomies_rules_types`: Rule types (regex, AI, etc.)
  - `silver_mapping_taxonomies_rules`: Mapping rules for taxonomies
  - `silver_mapping_taxonomies_rules_assignment`: Rule assignments with priority
  - `silver_mapping_taxonomies`: Master-to-customer taxonomy mappings
- **Profession Mapping Tables**:
  - `silver_mapping_professions_rules_types`: Rule types for professions
  - `silver_mapping_professions_rules`: Mapping rules for professions
  - `silver_mapping_professions_rules_assignment`: Rule assignments
  - `silver_mapping_professions`: Profession-to-taxonomy mappings
- **Audit Tables**:
  - `silver_taxonomies_log`: Audit trail for taxonomy changes

#### 3. Gold Layer (Final Production Data)
- **Purpose**: Validated, approved mappings ready for API consumption
- **Tables**:
  - `gold_taxonomies_mapping`: Approved master-to-customer mappings
  - `gold_mapping_professions`: Approved profession-to-taxonomy mappings

## Lambda Functions Architecture

### 1. Ingestion and Cleanup Lambda
**Purpose**: Process raw data from Bronze to Silver layer
**Process**:
1. Read from Bronze tables
2. Parse JSON data
3. Extract and normalize:
   - Taxonomy hierarchies
   - Node types and relationships
   - Profession names and attributes
4. Load into Silver layer tables
5. Handle data quality issues

### 2. Translation Constant Command Logic Lambda
**Purpose**: Apply deterministic mapping rules
**Features**:
- Separate rule engines for taxonomies and professions
- Regex pattern matching with JSONB attributes
- Exact string matching (case-insensitive)
- Fuzzy matching with edit distance
- Priority-based rule execution per node type
- 100% confidence for command-based matches
**Process**:
1. Load rules from assignment tables by node type
2. Apply rules in priority order (lower number = higher priority)
3. Stop at first successful match
4. Store results in silver_mapping tables
5. Promote approved mappings to Gold layer

### 3. Translation LLM Logic Lambda
**Purpose**: AI-powered mapping for complex cases
**Features**:
- AWS Bedrock integration (Claude/Titan)
- Semantic similarity matching
- Context-aware translation
- Multiple match suggestions
**Process**:
1. Generate embeddings for unmatched items
2. Find semantically similar candidates
3. Use LLM for intelligent matching
4. Return multiple options with confidence scores
5. Flag for human review if confidence < threshold

### 4. Check Professional Title Lambda
**Purpose**: Validate and map individual profession titles
**Process**:
1. Check against customer taxonomy
2. Apply static mapping rules only (no AI)
3. Handle profession-specific attributes
4. Report unmapped professions

## Data Model Details

### Taxonomy Structure
```
Master Taxonomy (Propelus SSOT, ID: -1)
    ↓ (Mapping via rules + AI)
Customer Taxonomies (Hierarchical, multiple per customer)
    ↓ (Mapping via rules)
Professions (Non-hierarchical data sets with attributes)
```

### Key Entities

#### Taxonomies
- **Master Taxonomy**: Propelus SSOT (taxonomy_id: -1, customer_id: -1)
- **Customer Taxonomies**: Client-specific hierarchies
- **Attributes**: Name, type (master/customer), status (active/inactive)
- **Dual Mapping Paths**:
  1. Master ↔ Customer taxonomy (bidirectional)
  2. Customer profession → Customer taxonomy (unidirectional)

#### Nodes
- **Hierarchy Levels**: Industry → Profession Group → Broad Occupation → Detailed Occupation → Specialty → Profession
- **Node Types**: Dynamic per taxonomy
- **Parent-Child Relationships**: Maintained for hierarchy

#### Professions
- **Core Data**: Name, ID, status
- **Attributes**:
  - States (e.g., CA, FL, TX)
  - Abbreviations (e.g., RN, NP)
  - Occupation statuses (permanent, temporary)
  - License requirements
  - Custom attributes per customer

#### Mapping Rules
- **Types**: Regex, exact match, fuzzy match, AI-based
- **Priority System**: Rules execute in priority order
- **Confidence Levels**:
  - 100%: Deterministic match (auto-approve)
  - 90-99%: High confidence (configurable auto-approve)
  - 70-89%: Medium confidence (human review)
  - <70%: Low confidence (requires human intervention)

## Confidence Scoring & Human Review

### Confidence Thresholds
- **Auto-Approval**: ≥90% (configurable)
- **Review Required**: 70-89%
- **Manual Mapping**: <70%

### Human-in-the-Loop Workflow
1. System presents multiple mapping options
2. Shows confidence scores for each
3. Human reviews context and alternatives
4. Selects correct mapping or creates new
5. System learns from decisions
6. Updates gold layer with approved mappings

### Status Management
- **Active**: Approved and in use
- **Pending**: Awaiting human review
- **Rejected**: Declined mappings
- **Inactive**: Deprecated mappings

## API Endpoints

### 1. Taxonomy Query API
```
GET /api/v1/taxonomies
GET /api/v1/taxonomies/{id}/nodes
POST /api/v1/taxonomies/search
```

### 2. Translation API
```
POST /api/v1/translate
{
  "input_text": "RN in ICU",
  "context": {"state": "FL"},
  "options": {
    "include_alternatives": true,
    "min_confidence": 0.7
  }
}
```

### 3. Professional Title Check API
```
POST /api/v1/professions/validate
GET /api/v1/professions/mappings
```

### 4. Admin APIs
```
GET /api/v1/admin/review-queue
POST /api/v1/admin/approve-mapping
POST /api/v1/admin/reject-mapping
PUT /api/v1/admin/create-mapping
```

## Key Insights from Customer Meeting (Sept 24)

### Customer Data Reality
- **Customers rarely provide hierarchical taxonomies**
- Typical input is flat lists with 3-4 fields:
  - State (e.g., "WA")
  - Client profession code (e.g., "ARNP")
  - Client profession description
  - Issuing authority (rarely provided)

### Two Distinct Workflows
1. **Mapping Creation (Left-to-Right)**:
   - Requires human-in-the-loop for low confidence
   - Builds the mapping database
   - Uses Bronze → Silver → Gold flow

2. **Translation Service (Right-to-Left)**:
   - Fully deterministic, no human intervention
   - Real-time API responses
   - Can return multiple matches if attributes insufficient

### Critical Requirements
- **Issuing Authority Context**: Essential for proper mapping
  - State-based (static list)
  - National certifications (dynamic, evolving)
  - Some override state (e.g., ARRT is always national)

- **Attribute Combinations**: Must track each unique combination
  - "WA + ARNP" stored separately from "CA + ARNP"
  - Helps disambiguate future mappings

- **Context Rules**: Need rules for common abbreviations
  - ACLS → American Heart Association
  - ARRT → Always national certification
  - RQI → Context-dependent

## Key Insights from Sept 25 Meeting

### Data Model Refinements
- **Attributes Structure**: Edwin suggested attribute types catalog separate from values
- **Bronze Traceability**: Track data sources (API calls, files) with source_id
- **Flexible Mapping**: Changed "master_node_id" to "target_node_id" for customer-to-customer mappings
- **Data Lineage**: Need complete traceability from Bronze → Silver → Gold

### Technical Decisions
- **Database**: Staying with Aurora PostgreSQL per data team decision
- **GraphQL Layer**: Data team has GraphQL API layer on top of PostgreSQL
- **Observability**: CloudWatch for logs, then filtered to CloudWatch Insights
- **Master Taxonomy**: Manual creation process initially

### Processing Requirements
- **Source Tracking**: Store file names, API endpoints, request IDs
- **Processing Stages**: Track each stage (ingestion, processing, mapping, review, promotion)
- **Attribute Types**: Catalog of standard attributes (state, abbreviation, license_type)
- **Version Control**: Track master taxonomy versions for changes

## Use Cases

### Use Case 1: Taxonomy Mapping
**Scenario**: Customer provides their taxonomy, needs mapping to master
**Flow**:
1. Ingest customer taxonomy to Bronze layer
2. Process through Silver layer
3. Apply deterministic rules
4. Use AI for uncertain matches
5. Human review for low confidence
6. Store approved mappings in Gold

### Use Case 2: Profession Title Validation
**Scenario**: Verify if profession title exists in taxonomy
**Flow**:
1. Receive profession title with attributes
2. Check against customer taxonomy
3. Apply static rules only
4. Return match or flag for manual review

### Use Case 3: Cross-Customer Mapping
**Scenario**: Map professions across different customers
**Flow**:
1. Map Customer A profession → Master taxonomy
2. Map Master taxonomy → Customer B taxonomy
3. Enable cross-customer insights

## Implementation Timeline

### Phase 1: Foundation (Weeks 1-3)
- Design data model
- Set up Bronze/Silver/Gold layers
- Create database schema

### Phase 2: Core Lambda Functions (Weeks 4-7)
- Implement ingestion Lambda
- Build deterministic mapping engine
- Create rule management system

### Phase 3: AI Integration (Weeks 8-10)
- Integrate AWS Bedrock
- Implement semantic search
- Build confidence scoring

### Phase 4: Human Review & Admin (Weeks 11-12)
- Create review queue
- Build admin UI
- Implement approval workflow

### Phase 5: Testing & Deployment (Weeks 13-14)
- End-to-end testing
- Performance optimization
- Production deployment

## Technical Stack

### Data Layer
- **Database**: PostgreSQL (AWS Aurora)
- **Analytics**: Snowflake
- **Cache**: Redis
- **Data Pipeline**: AWS Lambda

### AI/ML
- **LLM**: AWS Bedrock (Claude 3 Sonnet)
- **Embeddings**: AWS Titan
- **Vector Store**: FAISS
- **Framework**: LangChain/LangGraph

### APIs & Services
- **API Framework**: FastAPI
- **Admin UI**: Streamlit
- **Monitoring**: CloudWatch
- **Infrastructure**: Terraform

## Performance Requirements

### Response Times
- Deterministic matching: <100ms
- AI-powered matching: <2s
- Bulk processing: 10,000 records/minute

### Accuracy Targets
- Deterministic rules: 100% accuracy
- AI matching: >85% accuracy
- Overall system: >95% with human review

## Security & Compliance

### Data Security
- Encryption at rest and in transit
- PII data masking
- Audit logging for all changes
- Role-based access control

### Compliance
- HIPAA compliant infrastructure
- SOC 2 certification ready
- GDPR compliance for EU customers

## Monitoring & Metrics

### Key Metrics
- Mapping accuracy rate
- Average confidence score
- Human review queue size
- Processing latency
- API response times

### Dashboards
- Real-time processing status
- Confidence score distribution
- Human review metrics
- System health indicators

## Support & Maintenance

### Regular Tasks
- Rule optimization
- AI model fine-tuning
- Confidence threshold adjustment
- Performance monitoring
- Data quality checks

### Documentation
- API documentation (OpenAPI/Swagger)
- Admin guide
- Integration guide
- Troubleshooting guide

## Future Enhancements

### Planned Features
- Multi-language support
- Real-time streaming API
- Advanced analytics dashboard
- Mobile admin app
- Automated rule learning from human decisions

### Scalability Plans
- Horizontal scaling of Lambda functions
- Multi-region deployment
- Caching optimization
- Database sharding for large customers