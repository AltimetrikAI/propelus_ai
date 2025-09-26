# Propelus AI - Complete Implementation Plan

## Overview
This plan ensures all project components are aligned with the latest data model changes from September 24-25 meetings. The system now implements a full Bronze/Silver/Gold architecture with enhanced tracking, flexible mapping, and proper attribute handling.

## Current State Analysis

### ✅ Completed
1. **Database Migrations** (4 migrations created)
   - 001: Initial taxonomy schema
   - 002: Bronze/Silver/Gold architecture
   - 003: Issuing authorities and context
   - 004: Sept 25 refinements (source tracking, traceability)

2. **Python Models**
   - `/services/taxonomy-api/app/models/taxonomy.py` - Complete Bronze/Silver/Gold models
   - `/services/taxonomy-api/app/models/profession.py` - Original model (needs deprecation)

3. **API Endpoints**
   - `/services/taxonomy-api/app/api/v1/endpoints/taxonomies.py` - Basic endpoints
   - `/services/taxonomy-api/app/api/v1/endpoints/professions.py` - Basic endpoints

4. **Documentation**
   - DATA_MODEL_DOCUMENTATION.md - Updated with all changes
   - PROJECT_DOCUMENTATION.md - Updated with meeting insights
   - WORKFLOW_DOCUMENTATION.md - New, complete workflows

### ❌ Needs Update
1. **Lambda Functions** - Not yet created
2. **Translation Service** - Still using old agent architecture
3. **Admin UI** - Placeholder only
4. **Infrastructure** - Missing Terraform/Docker configs
5. **Tests** - No tests created yet

## Implementation Plan by Component

### Phase 1: Database & Core Models (Priority 1)

#### 1.1 Run All Migrations
```sql
-- Execute in order:
001_create_taxonomy_schema.sql
002_bronze_silver_gold_architecture.sql
003_issuing_authorities_and_context.sql
004_sept25_refinements.sql
```

#### 1.2 Update SQLAlchemy Models
**File**: `/services/taxonomy-api/app/models/taxonomy.py`
- [x] Add BronzeDataSources model
- [x] Add SilverAttributeTypes model
- [x] Add ProcessingLog model
- [x] Add MasterTaxonomyVersions model
- [ ] Add helper methods for data lineage
- [ ] Add validation methods

**Actions Needed**:
```python
# Add to taxonomy.py:
class BronzeDataSources(Base):
    __tablename__ = 'bronze_data_sources'
    # ... (already planned in migration)

class ProcessingLog(Base):
    __tablename__ = 'processing_log'
    # ... (already planned in migration)
```

#### 1.3 Deprecate Old Models
**File**: `/services/taxonomy-api/app/models/profession.py`
- Mark as deprecated
- Move relevant code to taxonomy.py

### Phase 2: API Layer Updates (Priority 2)

#### 2.1 Core API Endpoints

**New File**: `/services/taxonomy-api/app/api/v1/endpoints/ingestion.py`
```python
# Bronze layer ingestion endpoints
POST /api/v1/ingestion/bronze/taxonomies
POST /api/v1/ingestion/bronze/professions
GET /api/v1/ingestion/status/{source_id}
```

**New File**: `/services/taxonomy-api/app/api/v1/endpoints/mapping.py`
```python
# Mapping management endpoints
POST /api/v1/mappings/create
GET /api/v1/mappings/pending-review
POST /api/v1/mappings/{mapping_id}/approve
POST /api/v1/mappings/{mapping_id}/reject
```

**New File**: `/services/taxonomy-api/app/api/v1/endpoints/translation.py`
```python
# Translation service endpoint
POST /api/v1/translate
{
    "source_taxonomy": "customer_123",
    "target_taxonomy": "evercheck",
    "source_code": "ARNP",
    "attributes": {
        "state": "WA",
        "issuing_authority": "Washington State"
    }
}
```

#### 2.2 Update Existing Endpoints
- Update `taxonomies.py` to use `target_node_id` instead of `master_node_id`
- Add source tracking to all endpoints
- Add processing log entries

### Phase 3: Lambda Functions (Priority 1)

#### 3.1 Bronze Ingestion Lambda
**New File**: `/lambdas/bronze_ingestion/handler.py`
```python
def handler(event, context):
    """
    Process raw data from S3/API into Bronze layer
    - Parse CSV/JSON/Excel files
    - Store in bronze_taxonomies/bronze_professions
    - Create source tracking record
    - Trigger Silver processing
    """
```

#### 3.2 Silver Processing Lambda
**New File**: `/lambdas/silver_processing/handler.py`
```python
def handler(event, context):
    """
    Process Bronze data into Silver layer
    - Parse and structure data
    - Create taxonomy nodes and attributes
    - Apply data quality rules
    - Trigger mapping rules
    """
```

#### 3.3 Mapping Rules Lambda
**New File**: `/lambdas/mapping_rules/handler.py`
```python
def handler(event, context):
    """
    Apply mapping rules to Silver data
    - Execute rules by priority
    - Calculate confidence scores
    - Flag for human review if needed
    - Update silver_mapping_taxonomies
    """
```

#### 3.4 Translation Lambda
**New File**: `/lambdas/translation/handler.py`
```python
def handler(event, context):
    """
    Real-time translation between taxonomies
    - Look up Gold layer mappings
    - Apply context rules
    - Return single or multiple matches
    - Log translation patterns
    """
```

### Phase 4: Service Layer Updates (Priority 2)

#### 4.1 Translation Service Refactor
**Update**: `/services/translation-service/app/`
- Remove agent-based architecture
- Implement direct database queries
- Add caching layer
- Implement confidence scoring

#### 4.2 Admin UI Implementation
**Update**: `/services/admin-ui/`
- Create review queue interface
- Add mapping approval/rejection UI
- Create master taxonomy editor
- Add data lineage viewer

### Phase 5: Infrastructure (Priority 3)

#### 5.1 Terraform Configuration
**New Files**:
```
/infrastructure/terraform/
├── main.tf
├── variables.tf
├── rds.tf           # Aurora PostgreSQL
├── lambda.tf        # Lambda functions
├── api_gateway.tf   # API Gateway
├── s3.tf           # Data buckets
└── iam.tf          # Roles and policies
```

#### 5.2 Docker Configuration
**Update**: `/docker-compose.yml`
```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: propelus_taxonomy
    volumes:
      - ./data/migrations:/docker-entrypoint-initdb.d

  taxonomy-api:
    build: ./services/taxonomy-api
    depends_on:
      - postgres

  translation-service:
    build: ./services/translation-service
    depends_on:
      - postgres

  admin-ui:
    build: ./services/admin-ui
    depends_on:
      - taxonomy-api
```

### Phase 6: Testing (Priority 2)

#### 6.1 Unit Tests
**New Files**:
```
/tests/unit/
├── test_bronze_ingestion.py
├── test_silver_processing.py
├── test_mapping_rules.py
├── test_translation.py
└── test_data_lineage.py
```

#### 6.2 Integration Tests
**New Files**:
```
/tests/integration/
├── test_full_pipeline.py
├── test_api_endpoints.py
└── test_workflows.py
```

### Phase 7: Documentation Consolidation (Priority 3)

#### 7.1 Consolidate Documentation
- Merge AGENTS_ARCHITECTURE.md content into TECHNICAL_ARCHITECTURE.md
- Update IMPLEMENTATION_GUIDE.md with new workflows
- Create API_DOCUMENTATION.md with OpenAPI specs
- Add DEPLOYMENT_GUIDE.md

#### 7.2 Remove Outdated Docs
- Archive old agent-based documentation
- Update all references to master_node_id
- Ensure consistent terminology

## Implementation Checklist

### Week 1: Foundation
- [ ] Run all database migrations
- [ ] Update SQLAlchemy models
- [ ] Create Bronze ingestion Lambda
- [ ] Create Silver processing Lambda
- [ ] Test Bronze → Silver pipeline

### Week 2: Mapping & Rules
- [ ] Create mapping rules Lambda
- [ ] Implement context rules
- [ ] Add issuing authority logic
- [ ] Create human review queue
- [ ] Test mapping pipeline

### Week 3: Translation & API
- [ ] Create translation Lambda
- [ ] Implement all API endpoints
- [ ] Add caching layer
- [ ] Create API documentation
- [ ] Test end-to-end translation

### Week 4: UI & Polish
- [ ] Build admin UI
- [ ] Add monitoring/logging
- [ ] Create deployment scripts
- [ ] Write comprehensive tests
- [ ] Final documentation review

## Configuration Files Needed

### 1. Environment Configuration
**File**: `/.env.example`
```env
DATABASE_URL=postgresql://user:pass@localhost/propelus_taxonomy
REDIS_URL=redis://localhost:6379
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet
LOG_LEVEL=INFO
```

### 2. Database Configuration
**File**: `/services/taxonomy-api/alembic.ini`
```ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql://user:pass@localhost/propelus_taxonomy
```

### 3. Lambda Configuration
**File**: `/lambdas/serverless.yml`
```yaml
service: propelus-taxonomy
provider:
  name: aws
  runtime: python3.11
  region: us-east-1

functions:
  bronzeIngestion:
    handler: bronze_ingestion/handler.handler
    events:
      - s3:
          bucket: ${self:custom.bronzeBucket}
          event: s3:ObjectCreated:*

  silverProcessing:
    handler: silver_processing/handler.handler
    events:
      - sqs:
          arn: ${self:custom.processingQueue}
```

## Success Metrics

### Technical Metrics
- [ ] All migrations run successfully
- [ ] All tests pass (>90% coverage)
- [ ] API response time <200ms
- [ ] Translation accuracy >95%
- [ ] Zero data loss in pipeline

### Business Metrics
- [ ] Support for multiple customer taxonomies
- [ ] Automated mapping for 80% of cases
- [ ] Human review queue <24hr turnaround
- [ ] Complete data lineage tracking
- [ ] Real-time translation service

## Risk Mitigation

### High Priority Risks
1. **Data Migration Failures**
   - Mitigation: Create rollback scripts
   - Test on staging first

2. **Performance Issues**
   - Mitigation: Add caching layer
   - Optimize database queries

3. **Mapping Accuracy**
   - Mitigation: Implement confidence thresholds
   - Human review for low confidence

### Medium Priority Risks
1. **Integration Complexity**
   - Mitigation: Incremental deployment
   - Feature flags for new functionality

2. **Documentation Drift**
   - Mitigation: Auto-generate from code
   - Regular review cycles

## Next Steps

1. **Immediate** (Today):
   - Review and approve this plan
   - Set up development environment
   - Run database migrations

2. **Tomorrow**:
   - Start Lambda function development
   - Update Python models
   - Begin API endpoint implementation

3. **This Week**:
   - Complete Bronze/Silver pipeline
   - Test data ingestion flow
   - Document API contracts

## Questions for Team

1. **Master Taxonomy Creation**: Manual process defined?
2. **Authentication**: OAuth2, API keys, or both?
3. **Deployment**: AWS only or multi-cloud?
4. **Monitoring**: CloudWatch sufficient or need DataDog?
5. **Caching**: Redis confirmed or consider alternatives?

## Dependencies

### External Services
- AWS Aurora PostgreSQL
- AWS Lambda
- AWS Bedrock (for AI mapping)
- Redis (for caching)
- S3 (for data storage)

### Internal Dependencies
- Master taxonomy must exist before testing
- API contracts finalized before Lambda development
- Database migrations complete before model updates

## Conclusion

This plan aligns all project components with the latest requirements from the September 24-25 meetings. The system will support:
- Complete Bronze/Silver/Gold architecture
- Flexible taxonomy mapping (not just to master)
- Full data lineage and traceability
- Real-time translation service
- Human-in-the-loop for low confidence mappings

Priority should be given to database migrations, Lambda functions, and core API endpoints to establish the foundation for the remaining work.