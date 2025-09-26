# Propelus AI Taxonomy Framework - Deployment Guide

## Overview

This guide covers deployment options for the Propelus AI Taxonomy Framework, from local development to production environments.

## Table of Contents

1. [Local Development](#local-development)
2. [Production Deployment](#production-deployment)
3. [Environment Configuration](#environment-configuration)
4. [Database Setup](#database-setup)
5. [Monitoring Setup](#monitoring-setup)
6. [Troubleshooting](#troubleshooting)

## Local Development

### Docker Compose (Recommended)

#### Standard Development Stack
```bash
# Start core services
docker-compose up -d

# Start with development tools
docker-compose --profile dev up -d

# Start with monitoring stack
docker-compose --profile monitoring up -d
```

#### Services Included
- PostgreSQL database with migrations
- Redis cache
- Taxonomy API service
- Admin UI (Streamlit)
- PgAdmin (dev profile)
- Redis Commander (dev profile)
- LocalStack for AWS simulation (dev profile)

#### Access Points
- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Admin UI**: http://localhost:8501
- **PgAdmin**: http://localhost:8080
- **Redis Commander**: http://localhost:8081
- **Grafana**: http://localhost:3000 (monitoring profile)

### Manual Setup

#### Prerequisites
```bash
# Install Python dependencies
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Install Node.js dependencies (if any)
npm install

# Set up environment
cp .env.example .env
```

#### Database Setup
```bash
# Start PostgreSQL
brew services start postgresql  # macOS
sudo systemctl start postgresql  # Linux

# Create database
createdb propelus_taxonomy

# Run migrations
psql -d propelus_taxonomy -f data/migrations/001_create_taxonomy_schema.sql
psql -d propelus_taxonomy -f data/migrations/002_bronze_silver_gold_architecture.sql
psql -d propelus_taxonomy -f data/migrations/003_issuing_authorities_and_context.sql
psql -d propelus_taxonomy -f data/migrations/004_sept25_refinements.sql
```

#### Start Services
```bash
# Terminal 1: Start API
cd services/taxonomy-api
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2: Start Admin UI
cd services/admin-ui
streamlit run app.py --server.port 8501

# Terminal 3: Start Redis
redis-server
```

## Production Deployment

### AWS Infrastructure (Terraform)

#### 1. Prerequisites
- AWS CLI configured
- Terraform >= 1.0 installed
- Appropriate AWS permissions

#### 2. Setup State Backend
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://propelus-terraform-state

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name propelus-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

#### 3. Deploy Infrastructure
```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Create workspace for environment
terraform workspace new production

# Plan deployment
terraform plan -var-file="environments/production.tfvars"

# Apply infrastructure
terraform apply -var-file="environments/production.tfvars"
```

#### 4. Deploy Applications

##### Lambda Functions
```bash
# Package and deploy Lambda functions
./scripts/deploy-lambdas.sh production

# Or manually for each function
cd lambdas/bronze_ingestion
zip -r bronze_ingestion.zip .
aws lambda update-function-code --function-name propelus-taxonomy-bronze-ingestion-prod --zip-file fileb://bronze_ingestion.zip
```

##### API Gateway
```bash
# Deploy API Gateway stages
aws apigateway create-deployment --rest-api-id YOUR_API_ID --stage-name prod
```

### Kubernetes (Alternative)

#### 1. Setup Kubernetes Cluster
```bash
# Create EKS cluster
eksctl create cluster --name propelus-taxonomy --version 1.28 --region us-east-1

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name propelus-taxonomy
```

#### 2. Deploy with Helm
```bash
cd infrastructure/kubernetes

# Install dependencies
helm repo add postgresql https://charts.bitnami.com/bitnami
helm repo add redis https://charts.bitnami.com/bitnami

# Deploy database
helm install propelus-postgres postgresql/postgresql -f values-postgres.yaml

# Deploy Redis
helm install propelus-redis redis/redis -f values-redis.yaml

# Deploy application
helm install propelus-taxonomy ./helm-chart -f values-production.yaml
```

## Environment Configuration

### Environment Files

#### .env.production
```bash
# Database
DATABASE_URL=postgresql://username:password@prod-db-cluster.us-east-1.rds.amazonaws.com:5432/propelus_taxonomy
REDIS_URL=redis://prod-redis-cluster.cache.amazonaws.com:6379

# AWS Services
AWS_REGION=us-east-1
S3_BRONZE_BUCKET=propelus-taxonomy-bronze-prod
S3_SILVER_BUCKET=propelus-taxonomy-silver-prod
S3_GOLD_BUCKET=propelus-taxonomy-gold-prod

# Lambda Functions
BRONZE_INGESTION_LAMBDA=propelus-taxonomy-bronze-ingestion-prod
SILVER_PROCESSING_LAMBDA=propelus-taxonomy-silver-processing-prod
MAPPING_RULES_LAMBDA=propelus-taxonomy-mapping-rules-prod
TRANSLATION_LAMBDA=propelus-taxonomy-translation-prod

# Security
ENCRYPTION_KEY=your-32-char-production-key-here
API_KEY_REQUIRED=true
ENABLE_AUDIT_LOGGING=true

# Performance
AUTO_APPROVAL_THRESHOLD=95.0
LAMBDA_MEMORY_SIZE=2048
REDIS_CONNECTION_POOL_SIZE=50
```

### Secrets Management

#### AWS Secrets Manager
```bash
# Create secrets
aws secretsmanager create-secret \
  --name propelus/taxonomy/database \
  --secret-string '{"username":"admin","password":"secure_password"}'

aws secretsmanager create-secret \
  --name propelus/taxonomy/api-keys \
  --secret-string '{"encryption_key":"32-char-key","jwt_secret":"jwt-secret"}'
```

#### Environment Variables in Lambda
```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# Use in Lambda functions
db_secrets = get_secret('propelus/taxonomy/database')
DATABASE_URL = f"postgresql://{db_secrets['username']}:{db_secrets['password']}@{DB_HOST}:5432/propelus_taxonomy"
```

## Database Setup

### RDS Aurora PostgreSQL

#### 1. Cluster Configuration
- **Engine**: Aurora PostgreSQL 15.4
- **Instance Class**: db.r6g.large (minimum)
- **Multi-AZ**: Yes (production)
- **Backup Retention**: 7 days (minimum)
- **Encryption**: Enabled

#### 2. Performance Optimization
```sql
-- Recommended PostgreSQL settings
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
SELECT pg_reload_conf();
```

#### 3. Monitoring Queries
```sql
-- Check database performance
SELECT * FROM pg_stat_database WHERE datname = 'propelus_taxonomy';

-- Check slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC LIMIT 10;

-- Check connection count
SELECT count(*) FROM pg_stat_activity;
```

### Database Migrations

#### Production Migration Process
```bash
# 1. Backup current database
pg_dump -h $DB_HOST -U $DB_USER -d propelus_taxonomy > backup-$(date +%Y%m%d).sql

# 2. Test migrations on staging
psql -h $STAGING_DB_HOST -U $DB_USER -d propelus_taxonomy -f new_migration.sql

# 3. Apply to production (during maintenance window)
psql -h $PROD_DB_HOST -U $DB_USER -d propelus_taxonomy -f new_migration.sql

# 4. Verify migration
psql -h $PROD_DB_HOST -U $DB_USER -d propelus_taxonomy -c "\dt"
```

## Monitoring Setup

### CloudWatch Integration

#### 1. Custom Metrics
```python
import boto3

cloudwatch = boto3.client('cloudwatch')

def put_metric(metric_name, value, unit='Count'):
    cloudwatch.put_metric_data(
        Namespace='PropellusTaxonomy',
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit
            }
        ]
    )

# Example usage
put_metric('MappingSuccess', 1)
put_metric('ProcessingLatency', 1500, 'Milliseconds')
```

#### 2. Alarms
```bash
# High error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Propelus-High-Error-Rate" \
  --alarm-description "High error rate in taxonomy processing" \
  --metric-name ErrorRate \
  --namespace PropellusTaxonomy \
  --statistic Average \
  --period 300 \
  --threshold 5.0 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

### Grafana Dashboards

#### Import Dashboard
```bash
# Copy dashboard configuration
cp infrastructure/monitoring/grafana/dashboards/propelus-taxonomy.json /var/lib/grafana/dashboards/

# Restart Grafana
docker-compose restart grafana
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Issues
```bash
# Check database connectivity
psql -h $DB_HOST -U $DB_USER -d propelus_taxonomy -c "SELECT version();"

# Check connection pool
# In application logs, look for:
# "pool connection errors"
# "max connections reached"
```

#### 2. Lambda Function Timeouts
```bash
# Increase timeout in Terraform
resource "aws_lambda_function" "bronze_ingestion" {
  timeout = 900  # 15 minutes
  memory_size = 1024  # Increase memory
}

# Check CloudWatch logs
aws logs tail /aws/lambda/propelus-taxonomy-bronze-ingestion-prod --follow
```

#### 3. Redis Connection Issues
```bash
# Test Redis connectivity
redis-cli -h $REDIS_HOST -p 6379 ping

# Check memory usage
redis-cli -h $REDIS_HOST info memory
```

### Health Checks

#### API Health Check
```bash
curl -f http://your-api-domain.com/health
```

#### Database Health Check
```sql
SELECT
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit
FROM pg_stat_database
WHERE datname = 'propelus_taxonomy';
```

### Performance Monitoring

#### Key Metrics to Monitor
1. **API Response Time**: < 200ms average
2. **Lambda Duration**: < 30s for processing functions
3. **Database Connections**: < 80% of max
4. **Redis Memory Usage**: < 80% of available
5. **Queue Depth**: < 100 messages
6. **Error Rate**: < 1%

#### Alerting Thresholds
- **Critical**: > 5% error rate, > 10s response time
- **Warning**: > 1% error rate, > 2s response time
- **Info**: Deployment events, configuration changes

## Security Checklist

### Production Security
- [ ] Database encryption at rest enabled
- [ ] SSL/TLS for all connections
- [ ] VPC with private subnets
- [ ] Security groups with minimal access
- [ ] IAM roles with least privilege
- [ ] Secrets stored in AWS Secrets Manager
- [ ] CloudTrail logging enabled
- [ ] WAF enabled for API Gateway
- [ ] Regular security scans

### Compliance (HIPAA)
- [ ] Audit logging enabled
- [ ] Data retention policies configured
- [ ] Access controls documented
- [ ] Incident response plan
- [ ] Regular backup testing
- [ ] Business Associate Agreements (BAAs)

---

*Last Updated: January 26, 2025*
*Version: 1.0*