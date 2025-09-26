# Propelus Taxonomy Framework - Implementation Guide

## Project Overview
This guide provides step-by-step instructions for implementing the Propelus Taxonomy Framework according to the 14-week project plan.

## Architecture Summary

### System Components
1. **Taxonomy API** - Core SSOT service (FastAPI)
2. **Translation Service** - GenAI-powered mapping (LangChain + AWS Bedrock)  
3. **Admin UI** - HITL interface (Streamlit)
4. **Infrastructure** - AWS cloud-native architecture (Terraform)

## Week-by-Week Implementation Plan

### Phase 1: Kickoff & Design (Weeks 1-3)

#### Week 1: Project Kickoff
- [ ] Set up development environments
- [ ] Configure AWS accounts and IAM roles
- [ ] Initialize Git repositories
- [ ] Set up project management tools (Jira, Slack)

#### Week 2: Data Discovery
- [ ] Profile existing profession data
- [ ] Identify data sources and formats
- [ ] Document data quality issues
- [ ] Define taxonomy hierarchy strategy

#### Week 3: Design Finalization
- [ ] Review and approve database schema
- [ ] Finalize API specifications
- [ ] Complete architecture documentation
- [ ] Set up CI/CD pipelines

### Phase 2: Core Build (Weeks 4-7)

#### Week 4: Database Setup
```bash
# Run database migrations
cd data/migrations
psql -U postgres -d taxonomy_db -f 001_create_taxonomy_schema.sql

# Seed initial data
python scripts/seed_data.py
```

#### Week 5: Hierarchy Logic
- Implement parent-child relationships
- Build hierarchy validation rules
- Create materialized paths
- Test with sample data

#### Week 6: Taxonomy API Development
```bash
# Start API locally
cd services/taxonomy-api
pip install -r requirements.txt
uvicorn app.main:app --reload

# Test endpoints
curl http://localhost:8000/api/v1/professions
```

#### Week 7: Admin API Endpoints
- Implement CRUD operations
- Add authentication/authorization
- Set up audit logging
- Create API documentation

### Phase 3: ML & UI Build (Weeks 8-12)

#### Week 8: Translation Engine Design
- Set up AWS Bedrock access
- Design agent pipeline
- Create prompt templates
- Initialize vector store

#### Week 9: GenAI Model Training
```python
# Example translation pipeline
from langchain import LLMChain
from langchain.llms.bedrock import Bedrock

llm = Bedrock(
    model_id="anthropic.claude-3-sonnet",
    region_name="us-east-1"
)

translation_chain = LLMChain(
    llm=llm,
    prompt=TRANSLATION_PROMPT
)
```

#### Week 10: Model Iteration
- Implement confidence scoring
- Add semantic search
- Create fallback strategies
- Optimize performance

#### Week 11: Admin UI Development
```bash
# Start Admin UI
cd services/admin-ui
pip install streamlit pandas plotly
streamlit run app.py
```

#### Week 12: Integration & Audit
- Connect all services
- Implement RBAC
- Set up comprehensive logging
- Create monitoring dashboards

### Phase 4: Validation & Closure (Weeks 13-14)

#### Week 13: UAT & Testing
- End-to-end testing
- Performance testing
- Security testing
- Bug fixes

#### Week 14: Deployment & Handoff
- Deploy to production
- Documentation review
- Knowledge transfer
- Project closure

## Local Development Setup

### Prerequisites
- Docker & Docker Compose
- Python 3.11+
- Node.js 18+ (for UI development)
- AWS CLI configured
- PostgreSQL client tools

### Quick Start
```bash
# Clone repository
git clone https://github.com/propelus/taxonomy-framework.git
cd Propelus_AI

# Start all services
docker-compose up -d

# Check service health
docker-compose ps

# View logs
docker-compose logs -f taxonomy-api

# Access services
# Taxonomy API: http://localhost:8000/docs
# Translation Service: http://localhost:8001/docs
# Admin UI: http://localhost:8501
# PostgreSQL: localhost:5432
# Redis: localhost:6379
```

### Development Workflow
```bash
# Run tests
pytest services/taxonomy-api/tests

# Format code
black services/

# Type checking
mypy services/taxonomy-api

# Database migrations
alembic upgrade head

# Generate API client
openapi-generator generate -i http://localhost:8000/openapi.json
```

## AWS Deployment

### Infrastructure Provisioning
```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars"
```

### Container Deployment
```bash
# Build and push images
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

docker build -t taxonomy-api services/taxonomy-api
docker tag taxonomy-api:latest $ECR_REGISTRY/taxonomy-api:latest
docker push $ECR_REGISTRY/taxonomy-api:latest

# Deploy to ECS
aws ecs update-service --cluster propelus-cluster --service taxonomy-api --force-new-deployment
```

## Key Configuration Files

### Environment Variables (.env)
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/taxonomy_db

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# AWS
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx

# Bedrock
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet
EMBEDDING_MODEL_ID=amazon.titan-embed-text-v1

# API Keys
API_SECRET_KEY=xxx
ADMIN_API_KEY=xxx
```

### Docker Configuration
See `docker-compose.yml` for local development setup.

### Terraform Variables
```hcl
# environments/dev.tfvars
environment = "development"
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
db_instance_class = "db.t3.medium"
redis_node_type = "cache.t3.micro"
```

## API Integration Examples

### Taxonomy Query
```python
import requests

response = requests.get(
    "http://localhost:8000/api/v1/professions/search",
    params={"query": "nurse", "limit": 10}
)
professions = response.json()
```

### Translation Request
```python
translation_request = {
    "input_text": "RN",
    "context": {"state": "FL"},
    "options": {
        "include_alternatives": True,
        "min_confidence": 0.7
    }
}

response = requests.post(
    "http://localhost:8001/api/v1/translate",
    json=translation_request
)
result = response.json()
```

## Monitoring & Observability

### Key Metrics
- API latency (p50, p95, p99)
- Translation accuracy
- Cache hit rates
- Database performance
- Error rates

### Dashboards
- CloudWatch dashboards for AWS resources
- Prometheus + Grafana for application metrics
- ELK stack for log aggregation

### Alerts
```yaml
# Example CloudWatch alarm
APILatencyAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    MetricName: Duration
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 1000
    ComparisonOperator: GreaterThanThreshold
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
```bash
# Check PostgreSQL status
docker-compose ps postgres
docker-compose logs postgres

# Test connection
psql -h localhost -U postgres -d taxonomy_db
```

2. **Redis Connection Issues**
```bash
# Check Redis status
docker-compose ps redis
redis-cli ping
```

3. **AWS Bedrock Access Denied**
```bash
# Verify IAM permissions
aws bedrock list-foundation-models --region us-east-1

# Check credentials
aws sts get-caller-identity
```

4. **Service Discovery Issues**
```bash
# Check service registration
docker-compose ps
docker network ls
```

## Performance Optimization

### Database
- Create appropriate indexes
- Use connection pooling
- Implement query caching
- Regular VACUUM and ANALYZE

### API
- Implement response caching
- Use async/await patterns
- Batch processing for bulk operations
- Rate limiting

### GenAI Translation
- Cache embeddings and translations
- Batch inference requests
- Use appropriate model sizes
- Implement circuit breakers

## Security Best Practices

1. **Secrets Management**
   - Use AWS Secrets Manager
   - Rotate credentials regularly
   - Never commit secrets to Git

2. **Network Security**
   - Implement VPC isolation
   - Use Security Groups properly
   - Enable WAF for public endpoints

3. **Data Protection**
   - Encrypt at rest and in transit
   - Implement data masking
   - Regular backups

4. **Access Control**
   - Implement RBAC
   - Use SSO where possible
   - Audit all access

## Support & Resources

### Documentation
- [API Documentation](http://localhost:8000/docs)
- [Architecture Guide](docs/architecture/TECHNICAL_ARCHITECTURE.md)
- [Database Schema](data/migrations/001_create_taxonomy_schema.sql)

### Team Contacts
- **Technical Lead**: tech-lead@propelus.com
- **DevOps**: devops@propelus.com
- **Support**: support@propelus.com

### External Resources
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [LangChain Documentation](https://docs.langchain.com/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

## Next Steps

1. **Immediate Actions**
   - Set up development environment
   - Review architecture documentation
   - Begin Week 1 tasks

2. **Ongoing Activities**
   - Daily standup meetings
   - Weekly progress reports
   - Continuous integration testing

3. **Future Enhancements**
   - Multi-language support
   - Advanced analytics dashboard
   - Mobile application
   - API rate limiting and monetization