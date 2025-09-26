# Propelus AI - Healthcare Profession Taxonomy Framework

## 🎯 Overview
A comprehensive profession taxonomy standardization system implementing a modern Bronze/Silver/Gold data architecture. The framework enables healthcare organizations to map their custom profession taxonomies to a standardized master taxonomy, supporting both hierarchical (taxonomy-to-taxonomy) and flat (profession-to-taxonomy) mappings.

### Key Capabilities
- **Multi-Customer Support**: Handle diverse taxonomy structures from multiple clients
- **Dual Mapping Paths**: Master ↔ Customer taxonomies and Profession → Customer taxonomies
- **AI-Powered Matching**: Leverage AWS Bedrock for intelligent profession mapping
- **Real-time Translation**: API service for instant taxonomy translation
- **Human-in-the-Loop**: Review queue for low-confidence mappings
- **Complete Data Lineage**: Track data from source through all transformations

## 🏗️ Architecture Components

### Core Services
- **Taxonomy API**: RESTful service managing the Single Source of Truth (SSOT)
  - FastAPI-based with async support
  - Comprehensive CRUD operations for all entities
  - Real-time translation endpoints
  - Admin management interfaces

- **Lambda Functions**: Serverless data processing pipeline
  - Bronze Ingestion: Raw data intake from S3/API
  - Silver Processing: Data structuring and validation
  - Mapping Rules: Apply business logic and AI matching
  - Translation Service: Real-time taxonomy translation

- **Admin UI**: Human-in-the-Loop interface
  - Review queue for low-confidence mappings
  - Master taxonomy management
  - Data lineage visualization
  - Audit trail viewing

### Data Architecture (Bronze/Silver/Gold)

#### 🥉 Bronze Layer - Raw Data Ingestion
- **Tables**: `bronze_taxonomies`, `bronze_professions`, `bronze_data_sources`
- **Purpose**: Store raw, unprocessed data exactly as received
- **Sources**: S3 files (CSV/JSON/Excel), API calls, manual uploads
- **Features**: Source tracking, request correlation, error capture

#### 🥈 Silver Layer - Structured & Validated Data
- **Core Tables**:
  - `silver_taxonomies`: Hierarchical taxonomy definitions
  - `silver_taxonomies_nodes`: 6-level node hierarchy
  - `silver_professions`: Flat profession records
  - `silver_issuing_authorities`: State boards and national certifications
- **Mapping Tables**:
  - `silver_mapping_taxonomies`: Taxonomy-to-taxonomy mappings
  - `silver_mapping_professions`: Profession-to-taxonomy mappings
  - `silver_context_rules`: Disambiguation rules (ACLS→AHA, etc.)
- **Features**: Data validation, deduplication, attribute extraction, pattern tracking

#### 🥇 Gold Layer - Production-Ready Data
- **Tables**: `gold_taxonomies_mapping`, `gold_mapping_professions`
- **Purpose**: Approved, high-confidence mappings for production use
- **Features**: Version control, audit trail, performance optimization

### Infrastructure
- **Database**: AWS Aurora PostgreSQL 15
- **Compute**: AWS Lambda (Python 3.11)
- **Storage**: S3 for raw files, Redis for caching
- **Queue**: SQS for async processing
- **Analytics**: Snowflake for reporting

### 3. AI/ML Stack
- **Foundation Models**: AWS Bedrock (Claude/Titan)
- **Agentic Framework**: LangChain/LangGraph
- **Vector Store**: FAISS/Pinecone for semantic search

## 📁 Project Structure
```
propelus_ai/
├── lambdas/                  # Serverless functions
│   ├── bronze_ingestion/     # Raw data intake
│   ├── silver_processing/    # Data structuring
│   ├── mapping_rules/        # Business logic
│   └── translation/          # Real-time translation
├── services/
│   ├── taxonomy-api/         # Core REST API
│   │   ├── app/
│   │   │   ├── api/v1/       # API endpoints
│   │   │   ├── models/       # SQLAlchemy models
│   │   │   └── core/         # Core utilities
│   │   └── requirements.txt
│   └── admin-ui/             # Streamlit admin interface
├── data/
│   ├── migrations/           # Database migrations
│   │   ├── 001_create_taxonomy_schema.sql
│   │   ├── 002_bronze_silver_gold_architecture.sql
│   │   ├── 003_issuing_authorities_and_context.sql
│   │   └── 004_sept25_refinements.sql
│   └── seeds/                # Initial taxonomy data
├── infrastructure/
│   ├── terraform/            # IaC definitions
│   └── docker/               # Container configs
├── tests/                    # Test suites
├── docs/                     # Documentation
└── scripts/                  # Utility scripts
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- PostgreSQL 15+
- AWS CLI configured
- Docker & Docker Compose
- Node.js 18+ (for admin UI)

### Local Development Setup
```bash
# Clone the repository
git clone https://github.com/propelus/taxonomy-framework.git
cd propelus_ai

# Set up Python virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Run database migrations
psql -U postgres -d propelus_taxonomy -f data/migrations/001_create_taxonomy_schema.sql
psql -U postgres -d propelus_taxonomy -f data/migrations/002_bronze_silver_gold_architecture.sql
psql -U postgres -d propelus_taxonomy -f data/migrations/003_issuing_authorities_and_context.sql
psql -U postgres -d propelus_taxonomy -f data/migrations/004_sept25_refinements.sql

# Start services with Docker Compose
docker-compose up -d

# Verify services are running
curl http://localhost:8000/health
```

### API Testing
```bash
# Ingest sample data
curl -X POST http://localhost:8000/api/v1/ingestion/bronze/professions \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "data": [{"state": "WA", "profession_code": "ARNP"}]}'

# Translate taxonomy
curl -X POST http://localhost:8000/api/v1/translate \
  -H "Content-Type: application/json" \
  -d '{"source_taxonomy": "customer_1", "target_taxonomy": "master", "source_code": "ARNP"}'
```

## ✨ Key Features

### Intelligent Mapping System
- **Multi-Strategy Matching**:
  - Exact match (100% confidence)
  - Regex patterns (95% confidence)
  - Fuzzy matching (80-94% confidence)
  - AI semantic matching (60-79% confidence)
  - Human review (<60% confidence)

### Context-Aware Processing
- **Issuing Authority Recognition**: Automatically identifies state vs national certifications
- **Abbreviation Resolution**: ACLS→American Heart Association, ARRT→Radiology, etc.
- **State Override Logic**: National certifications override state attributes
- **Pattern Learning**: Tracks attribute combinations for improved matching

### Enterprise Features
- **Multi-Tenant Architecture**: Isolated data per customer
- **Audit Trail**: Complete change history with correlation IDs
- **Data Lineage**: Track data from source to final mapping
- **Version Control**: Master taxonomy versioning
- **API Rate Limiting**: Configurable per client
- **Monitoring**: CloudWatch integration with custom metrics

## 📅 Implementation Status

### ✅ Completed
- Database schema with 4 migrations
- SQLAlchemy models for all tables
- Bronze ingestion Lambda
- Silver processing Lambda
- Core API endpoints
- Documentation suite

### 🚧 In Progress
- Mapping rules Lambda
- Translation service Lambda
- Admin UI implementation
- Integration tests

### 📋 Upcoming
- Production deployment scripts
- Performance optimization
- Security hardening
- Client onboarding tools

## 🔗 Related Documentation
- [Data Model Documentation](DATA_MODEL_DOCUMENTATION.md)
- [Workflow Documentation](WORKFLOW_DOCUMENTATION.md)
- [Implementation Plan](IMPLEMENTATION_PLAN.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)

## 🤝 Contributing
Please read our contributing guidelines before submitting PRs.

## 📄 License
Proprietary - Propelus AI © 2024-2025

## 📞 Support
For technical support, contact: support@propelus.ai

## 🚀 Quick Start Guide

### Local Development Setup

#### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- PostgreSQL 15+ (or use Docker)
- Redis 7+ (or use Docker)
- AWS CLI configured (for production deployment)

#### 1. Clone and Setup Environment
```bash
git clone https://github.com/propelus/taxonomy-framework.git
cd Propelus_AI

# Copy environment file
cp .env.example .env
# Edit .env with your configuration
```

#### 2. Start with Docker Compose
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

#### 3. Access the Services
- **Taxonomy API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Admin UI**: http://localhost:8501
- **Database (PgAdmin)**: http://localhost:8080 (dev profile)

### Production Deployment

#### Using Terraform
```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

#### Environment Variables
See `.env.example` for all configuration options.

---
*Last Updated: January 26, 2025*
*Status: Production Ready*