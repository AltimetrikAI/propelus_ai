# Technical Architecture - Propelus Taxonomy Framework

## System Overview

The Propelus Taxonomy Framework is a cloud-native, microservices-based solution designed to standardize healthcare profession data through a hierarchical taxonomy and AI-powered translation capabilities.

## Architecture Principles

1. **Microservices Architecture**: Loosely coupled services for scalability
2. **API-First Design**: All interactions through well-defined REST APIs
3. **Event-Driven Communication**: Asynchronous processing for translation jobs
4. **Cloud-Native**: Built for AWS with managed services
5. **Security by Design**: Zero-trust, encryption at rest and in transit

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     External Consumers                      │
│         (Data Solutions Product, Analytics Teams)           │
└────────────┬────────────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────────────┐
│                      API Gateway (AWS)                      │
│                    Rate Limiting | Auth                     │
└────────────┬────────────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────────────┐
│                    Application Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Taxonomy API │  │ Translation  │  │   Admin UI   │     │
│  │   (FastAPI)  │  │   Service    │  │  (Streamlit) │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼─────────────────┼─────────────┘
          │                  │                  │
┌─────────▼──────────────────▼─────────────────▼─────────────┐
│                      Data Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Aurora Postgres│ │Redis Cache   │  │  S3 Storage  │     │
│  │   (SSOT)     │  │              │  │  (Audit Logs)│     │
│  └──────┬───────┘  └──────────────┘  └──────────────┘     │
└─────────┼───────────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────────┐
│                    Analytics Layer                          │
│                  Snowflake (Replicated)                     │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Taxonomy API Service
**Technology**: Python FastAPI
**Responsibilities**:
- CRUD operations for taxonomy hierarchy
- Search and filter endpoints
- Hierarchy validation logic
- Alias management
- Versioning support

**Key Endpoints**:
```
GET    /api/v1/professions           # List all professions
GET    /api/v1/professions/{id}      # Get profession details
GET    /api/v1/professions/search    # Search professions
POST   /api/v1/professions           # Create profession (admin)
PUT    /api/v1/professions/{id}      # Update profession (admin)
DELETE /api/v1/professions/{id}      # Delete profession (admin)
GET    /api/v1/hierarchy             # Get full hierarchy tree
```

### 2. Translation Service
**Technology**: Python with LangChain/LangGraph
**AI Model**: AWS Bedrock (Claude 3 Sonnet/Haiku)
**Responsibilities**:
- Preprocess input profession text
- Semantic matching using vector embeddings
- Multi-agent translation pipeline
- Confidence scoring
- Fallback strategies

**Architecture Pattern**: Agentic Framework
```
Input → Preprocessor → Semantic Search → LLM Translation → Validator → Output
                              ↓                   ↓
                        Vector Store      Confidence Scorer
```

### 3. Admin UI (HITL)
**Technology**: Streamlit
**Features**:
- Review translation suggestions
- Manual mapping overrides
- Audit log viewer
- Taxonomy editor
- Analytics dashboard
- RBAC implementation

### 4. Data Architecture

#### Primary Database Schema (Aurora PostgreSQL)
```sql
-- Core taxonomy table
CREATE TABLE professions (
    id UUID PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    parent_id UUID REFERENCES professions(id),
    level INT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Aliases for alternative names
CREATE TABLE profession_aliases (
    id UUID PRIMARY KEY,
    profession_id UUID REFERENCES professions(id),
    alias VARCHAR(255) NOT NULL,
    source VARCHAR(100),
    created_at TIMESTAMP
);

-- Translation history
CREATE TABLE translations (
    id UUID PRIMARY KEY,
    input_text TEXT NOT NULL,
    matched_profession_id UUID REFERENCES professions(id),
    confidence_score DECIMAL(3,2),
    method VARCHAR(50), -- 'ai', 'exact', 'fuzzy', 'manual'
    metadata JSONB,
    reviewed BOOLEAN DEFAULT false,
    created_at TIMESTAMP
);

-- Audit logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY,
    entity_type VARCHAR(50),
    entity_id UUID,
    action VARCHAR(50),
    user_id VARCHAR(255),
    changes JSONB,
    created_at TIMESTAMP
);
```

### 5. Infrastructure Components

#### AWS Services
- **Compute**: ECS Fargate for containerized services
- **Database**: Aurora PostgreSQL (Multi-AZ)
- **Cache**: ElastiCache Redis
- **Storage**: S3 for audit logs and model artifacts
- **AI/ML**: Bedrock for foundation models
- **Monitoring**: CloudWatch, X-Ray
- **Security**: Secrets Manager, IAM, VPC

#### CI/CD Pipeline
```
GitHub → GitHub Actions → ECR → ECS Deployment
                ↓
        Run Tests & Quality Checks
```

## Security Architecture

### Authentication & Authorization
- **API Gateway**: AWS Cognito or API Keys
- **Admin UI**: SSO integration (SAML/OAuth)
- **Service-to-Service**: mTLS

### Data Security
- Encryption at rest (AWS KMS)
- Encryption in transit (TLS 1.3)
- Data masking for PII
- Audit logging for compliance

## Scalability Considerations

1. **Horizontal Scaling**: All services containerized for auto-scaling
2. **Caching Strategy**: Redis for frequently accessed taxonomy data
3. **Async Processing**: SQS/SNS for translation job queuing
4. **Database Optimization**: Read replicas for query distribution
5. **CDN**: CloudFront for static assets

## Monitoring & Observability

### Key Metrics
- API response times (p50, p95, p99)
- Translation accuracy score
- Cache hit ratio
- Database connection pool utilization
- Model inference latency

### Logging Strategy
- Structured logging (JSON format)
- Centralized log aggregation (CloudWatch Logs)
- Distributed tracing (AWS X-Ray)

## Disaster Recovery

- **RTO**: 4 hours
- **RPO**: 1 hour
- **Backup Strategy**: Automated daily snapshots
- **Multi-Region**: Passive standby in secondary region

## Development Workflow

### Local Development
```bash
# Start local stack
docker-compose up

# Services available at:
# - Taxonomy API: http://localhost:8000
# - Translation Service: http://localhost:8001
# - Admin UI: http://localhost:8501
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379
```

### Environment Strategy
- **Local**: Docker Compose
- **Dev**: Isolated AWS account
- **Staging**: Production-like environment
- **Production**: Full HA setup

## Technology Stack Summary

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Python | 3.11+ |
| API Framework | FastAPI | 0.100+ |
| ORM | SQLAlchemy | 2.0+ |
| AI Framework | LangChain | 0.1+ |
| Database | PostgreSQL | 15+ |
| Cache | Redis | 7+ |
| Container | Docker | 24+ |
| Orchestration | ECS Fargate | Latest |
| IaC | Terraform | 1.5+ |
| CI/CD | GitHub Actions | Latest |