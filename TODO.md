# Propelus AI - Development TODO List

## 🔴 Critical Priority (Week 1)

### Database & Migrations
- [ ] Run migration 001_create_taxonomy_schema.sql
- [ ] Run migration 002_bronze_silver_gold_architecture.sql
- [ ] Run migration 003_issuing_authorities_and_context.sql
- [ ] Run migration 004_sept25_refinements.sql
- [ ] Create rollback scripts for all migrations
- [ ] Test migrations on local database
- [ ] Document migration order and dependencies

### Core Python Models
- [ ] Update `/services/taxonomy-api/app/models/taxonomy.py` with missing models:
  - [ ] Add BronzeDataSources model
  - [ ] Add SilverAttributeTypes model
  - [ ] Add ProcessingLog model
  - [ ] Add MasterTaxonomyVersions model
  - [ ] Add APIContracts model
  - [ ] Add AuditLogEnhanced model
- [ ] Add model relationships and foreign keys
- [ ] Add model validation methods
- [ ] Add data lineage helper methods
- [ ] Create model unit tests
- [ ] Deprecate `/services/taxonomy-api/app/models/profession.py`

### Bronze Layer Implementation
- [ ] Create `/lambdas/bronze_ingestion/handler.py`
  - [ ] Implement S3 file reader
  - [ ] Implement CSV parser
  - [ ] Implement JSON parser
  - [ ] Implement Excel parser
  - [ ] Create source tracking record
  - [ ] Store in bronze_taxonomies table
  - [ ] Store in bronze_professions table
  - [ ] Trigger Silver processing
- [ ] Create `/lambdas/bronze_ingestion/requirements.txt`
- [ ] Create unit tests for Bronze ingestion
- [ ] Create integration tests for S3 triggers

## 🟡 High Priority (Week 1-2)

### Silver Layer Processing
- [ ] Create `/lambdas/silver_processing/handler.py`
  - [ ] Read from Bronze tables
  - [ ] Parse and structure taxonomy data
  - [ ] Create taxonomy records in silver_taxonomies
  - [ ] Create node types in silver_taxonomies_nodes_types
  - [ ] Create nodes in silver_taxonomies_nodes
  - [ ] Extract and store attributes
  - [ ] Handle professions data
  - [ ] Create processing log entries
  - [ ] Trigger mapping rules Lambda
- [ ] Create data quality validation rules
- [ ] Implement error handling and retry logic
- [ ] Create unit tests for Silver processing
- [ ] Document data transformation rules

### Mapping Rules Engine
- [ ] Create `/lambdas/mapping_rules/handler.py`
  - [ ] Load rules from silver_mapping_taxonomies_rules
  - [ ] Implement priority-based execution
  - [ ] Implement regex matching
  - [ ] Implement exact matching
  - [ ] Implement fuzzy matching
  - [ ] Calculate confidence scores
  - [ ] Apply context rules (ACLS, ARRT, etc.)
  - [ ] Check issuing authorities
  - [ ] Flag for human review when confidence < 90%
  - [ ] Store results in silver_mapping_taxonomies
- [ ] Create `/lambdas/mapping_rules/rules_engine.py`
- [ ] Create unit tests for each rule type
- [ ] Test confidence score calculations

### Translation Service
- [ ] Create `/lambdas/translation/handler.py`
  - [ ] Parse translation request
  - [ ] Validate source and target taxonomies
  - [ ] Look up Gold layer mappings
  - [ ] Apply context rules
  - [ ] Apply issuing authority overrides
  - [ ] Handle multiple matches
  - [ ] Return translation response
  - [ ] Log translation patterns
- [ ] Implement caching layer for common translations
- [ ] Create performance tests
- [ ] Document translation logic

## 🟢 Medium Priority (Week 2)

### API Endpoints
- [ ] Create `/services/taxonomy-api/app/api/v1/endpoints/ingestion.py`
  - [ ] POST /api/v1/ingestion/bronze/taxonomies
  - [ ] POST /api/v1/ingestion/bronze/professions
  - [ ] GET /api/v1/ingestion/status/{source_id}
  - [ ] GET /api/v1/ingestion/sources
- [ ] Create `/services/taxonomy-api/app/api/v1/endpoints/mapping.py`
  - [ ] POST /api/v1/mappings/create
  - [ ] GET /api/v1/mappings/pending-review
  - [ ] POST /api/v1/mappings/{mapping_id}/approve
  - [ ] POST /api/v1/mappings/{mapping_id}/reject
  - [ ] GET /api/v1/mappings/confidence-distribution
- [ ] Create `/services/taxonomy-api/app/api/v1/endpoints/translation.py`
  - [ ] POST /api/v1/translate
  - [ ] GET /api/v1/translate/patterns
  - [ ] POST /api/v1/translate/feedback
- [ ] Create `/services/taxonomy-api/app/api/v1/endpoints/admin.py`
  - [ ] GET /api/v1/admin/review-queue
  - [ ] POST /api/v1/admin/master-taxonomy/nodes
  - [ ] PUT /api/v1/admin/master-taxonomy/nodes/{node_id}
  - [ ] GET /api/v1/admin/data-lineage/{mapping_id}
- [ ] Update existing endpoints to use target_node_id
- [ ] Add authentication middleware
- [ ] Add rate limiting
- [ ] Create API documentation (OpenAPI/Swagger)

### Human Review Interface
- [ ] Create `/services/admin-ui/pages/review_queue.py`
  - [ ] Display pending mappings
  - [ ] Show confidence scores
  - [ ] Show suggested matches
  - [ ] Implement approve/reject buttons
  - [ ] Add notes field for reviewers
- [ ] Create `/services/admin-ui/pages/mapping_history.py`
- [ ] Create `/services/admin-ui/pages/data_lineage.py`
- [ ] Implement search and filter functionality
- [ ] Add export functionality for approved mappings

## 🔵 Lower Priority (Week 2-3)

### Master Taxonomy Management
- [ ] Create `/scripts/create_master_taxonomy.py`
  - [ ] Define 6-level hierarchy structure
  - [ ] Create Industry level (Level 1)
  - [ ] Create Profession Group level (Level 2)
  - [ ] Create Broad Occupation level (Level 3)
  - [ ] Create Detailed Occupation level (Level 4)
  - [ ] Create Occupation Specialty level (Level 5)
  - [ ] Create Profession level (Level 6)
- [ ] Create sample master taxonomy data
- [ ] Create taxonomy validation script
- [ ] Document taxonomy structure

### Context Rules Implementation
- [ ] Create context rules for national certifications:
  - [ ] ACLS → American Heart Association
  - [ ] BLS → American Heart Association
  - [ ] PALS → American Heart Association
  - [ ] ARRT → American Registry of Radiologic Technologists
  - [ ] NRP → American Academy of Pediatrics
- [ ] Implement state override logic for national certs
- [ ] Create rule priority system
- [ ] Test rule execution order
- [ ] Document all context rules

### Infrastructure Setup
- [ ] Create `/infrastructure/terraform/main.tf`
- [ ] Create `/infrastructure/terraform/rds.tf` for Aurora PostgreSQL
- [ ] Create `/infrastructure/terraform/lambda.tf` for Lambda functions
- [ ] Create `/infrastructure/terraform/api_gateway.tf`
- [ ] Create `/infrastructure/terraform/s3.tf` for data buckets
- [ ] Create `/infrastructure/terraform/iam.tf` for roles
- [ ] Create `/infrastructure/terraform/cloudwatch.tf` for monitoring
- [ ] Update `/docker-compose.yml` with all services
- [ ] Create `.env.example` with all environment variables
- [ ] Create `/scripts/deploy.sh` deployment script

### Testing Suite
- [ ] Create `/tests/unit/test_bronze_ingestion.py`
- [ ] Create `/tests/unit/test_silver_processing.py`
- [ ] Create `/tests/unit/test_mapping_rules.py`
- [ ] Create `/tests/unit/test_translation.py`
- [ ] Create `/tests/unit/test_data_lineage.py`
- [ ] Create `/tests/integration/test_full_pipeline.py`
- [ ] Create `/tests/integration/test_api_endpoints.py`
- [ ] Create `/tests/integration/test_workflows.py`
- [ ] Create `/tests/fixtures/sample_data.py`
- [ ] Set up pytest configuration
- [ ] Set up code coverage reporting

## ⚪ Nice to Have (Week 3-4)

### Documentation
- [ ] Update TECHNICAL_ARCHITECTURE.md with new design
- [ ] Create API_DOCUMENTATION.md with full specs
- [ ] Create DEPLOYMENT_GUIDE.md
- [ ] Create TROUBLESHOOTING.md
- [ ] Update README.md with quick start guide
- [ ] Create developer onboarding guide
- [ ] Archive deprecated documentation

### Monitoring & Observability
- [ ] Set up CloudWatch dashboards
- [ ] Create alerts for failed processing
- [ ] Implement distributed tracing
- [ ] Create performance metrics
- [ ] Set up error tracking (Sentry/Rollbar)
- [ ] Create health check endpoints
- [ ] Implement circuit breakers

### Performance Optimization
- [ ] Add Redis caching layer
- [ ] Optimize database queries
- [ ] Implement connection pooling
- [ ] Add database indexes
- [ ] Implement batch processing
- [ ] Add async processing where applicable

### Security Enhancements
- [ ] Implement OAuth2 authentication
- [ ] Add API key rotation
- [ ] Implement field-level encryption
- [ ] Add audit logging for all changes
- [ ] Implement rate limiting per client
- [ ] Add input validation and sanitization
- [ ] Create security scanning pipeline

## 📋 Checklist Before Production

### Code Quality
- [ ] All unit tests passing (>90% coverage)
- [ ] All integration tests passing
- [ ] Code review completed
- [ ] No critical security vulnerabilities
- [ ] Performance benchmarks met

### Documentation
- [ ] API documentation complete
- [ ] Deployment guide tested
- [ ] Runbook created for operations
- [ ] Architecture diagrams updated
- [ ] Change log updated

### Infrastructure
- [ ] Staging environment tested
- [ ] Backup and recovery tested
- [ ] Monitoring alerts configured
- [ ] Logging aggregation working
- [ ] Secrets management configured

### Business Requirements
- [ ] Supports multiple customer taxonomies ✓
- [ ] Bronze/Silver/Gold architecture implemented ✓
- [ ] Human review workflow functional ✓
- [ ] Translation service operational ✓
- [ ] Data lineage tracking complete ✓
- [ ] Confidence scoring implemented ✓

## 🚀 Deployment Phases

### Phase 1: Foundation (Current)
- Database migrations
- Core models
- Basic Lambda functions

### Phase 2: Core Features
- Mapping engine
- Translation service
- Basic API

### Phase 3: Admin Features
- Human review UI
- Master taxonomy management
- Monitoring

### Phase 4: Production Ready
- Performance optimization
- Security hardening
- Full documentation

## 📝 Notes

### Blockers
- Need actual master taxonomy data
- Need production AWS credentials
- Need client API specifications

### Decisions Needed
- Confirm authentication method (OAuth2 vs API keys)
- Confirm confidence thresholds (90% auto-approve?)
- Confirm data retention policies
- Confirm SLA for human review queue

### Technical Debt
- Refactor translation service from agents
- Remove deprecated profession.py model
- Consolidate duplicate documentation

---
*Last Updated: 2025-01-24*
*Total Tasks: 150+*
*Estimated Completion: 4 weeks*