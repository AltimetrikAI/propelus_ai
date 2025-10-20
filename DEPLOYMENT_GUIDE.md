# Propelus AI Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the Propelus AI Taxonomy Framework to production.

---

## Prerequisites

### Required

- AWS Account with appropriate IAM permissions
- PostgreSQL 15+ (Aurora recommended for production)
- Node.js 20+
- AWS CLI configured
- Git repository access

### Optional

- Redis (for Translation Lambda caching)
- AWS Bedrock access (for AI-powered matching)

---

## Phase 1: Database Setup

### Production Setup Scripts (Recommended)

For production deployments, use the complete setup scripts in `data/production/`. These scripts include all optimizations from the data engineer.

See [Production Setup README](./data/production/README.md) for complete instructions.

**Quick Setup**:
```bash
cd data/production

# 1. Setup roles and database
psql -h <aurora-endpoint> -U postgres -f 01-setup-roles.sql

# 2. Install extensions
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 02-extensions.sql

# 3. Create tables
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f production-ddl.sql

# 4-9. Create indexes (200+)
for i in 05 06 07 08 09 10; do
  psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f ${i}-indexes-*.sql
done

# 10. Seed N/A node
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 03-seed-na-node.sql

# 11. Transfer ownership
psql -h <aurora-endpoint> -U lambda_user -d taxonomy -f 04-ownership-transfer.sql
```

### Alternative: Step-by-Step Setup

#### Step 1: Provision Aurora PostgreSQL

```bash
# Create Aurora PostgreSQL cluster (via AWS Console or CLI)
aws rds create-db-cluster \
  --db-cluster-identifier propelus-taxonomy-prod \
  --engine aurora-postgresql \
  --engine-version 15.4 \
  --master-username propelus_admin \
  --master-user-password <secure-password> \
  --database-name propelus_taxonomy \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name propelus-db-subnet
```

### Step 2: Run Base Migrations (001-012)

```bash
# Connect to database
export PGHOST=<your-aurora-endpoint>
export PGPORT=5432
export PGDATABASE=taxonomy
export PGUSER=lambda_user
export PGPASSWORD=<your-password>
export PGSSLMODE=require

# Run migrations in order
cd Propelus_AI
psql < scripts/migrations/001-create-na-node-type.sql
psql < scripts/migrations/002-create-hierarchy-helper-functions.sql
psql < scripts/migrations/003-update-node-natural-key.sql
psql < scripts/migrations/004-schema-alignment.sql
# ... continue through 012
```

### Step 3: Run Data Model Updates (013-024)

```bash
# Run new migrations in order
cd data/migrations
psql < 013_bronze_load_details_updates.sql
psql < 014_bronze_taxonomies_updates.sql
psql < 015_silver_taxonomies_updates.sql
psql < 016_silver_nodes_types_updates.sql
psql < 017_silver_nodes_updates.sql
psql < 018_silver_attribute_types_updates.sql
psql < 019_silver_nodes_attributes_updates.sql
psql < 020_create_silver_taxonomies_versions.sql
psql < 021_create_silver_mapping_taxonomies_versions.sql
psql < 022_silver_mapping_rules_updates.sql
psql < 023_silver_mapping_taxonomies_updates.sql
psql < 024_create_gold_mapping_taxonomies.sql
```

### Step 4: Verify Database

```sql
-- Check all tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Verify migrations
SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema = 'public';
-- Should be 30+ tables

-- Verify version tables
SELECT table_name FROM information_schema.tables
WHERE table_name IN ('silver_taxonomies_versions', 'silver_mapping_taxonomies_versions', 'gold_mapping_taxonomies');
```

---

## Phase 2: Lambda Function Deployment

### Lambda 1: Ingestion & Cleansing

```bash
cd lambdas/ingestion_and_cleansing

# Install dependencies
npm install

# Build TypeScript
npm run build

# Package for Lambda
npm run package

# Create Lambda function
aws lambda create-function \
  --function-name propelus-ingestion-cleansing \
  --runtime nodejs20.x \
  --role arn:aws:iam::ACCOUNT_ID:role/propelus-lambda-role \
  --handler dist/handler.handler \
  --zip-file fileb://function.zip \
  --timeout 300 \
  --memory-size 1024 \
  --environment Variables="{
    PGHOST=<aurora-endpoint>,
    PGPORT=5432,
    PGDATABASE=taxonomy,
    PGSCHEMA=taxonomy_schema,
    PGUSER=lambda_user,
    PGPASSWORD=<password>,
    PGSSLMODE=require
  }"

# Or update existing
aws lambda update-function-code \
  --function-name propelus-ingestion-cleansing \
  --zip-file fileb://function.zip
```

### Lambda 2: Taxonomy Mapping Command

```bash
cd lambdas/taxonomy_mapping_command

# Install dependencies
npm install

# Build TypeScript
npm run build

# Package for Lambda
npm run package

# Create Lambda function
aws lambda create-function \
  --function-name propelus-taxonomy-mapping-command \
  --runtime nodejs20.x \
  --role arn:aws:iam::ACCOUNT_ID:role/propelus-lambda-role \
  --handler dist/handler.handler \
  --zip-file fileb://function.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment Variables="{
    PGHOST=<aurora-endpoint>,
    PGPORT=5432,
    PGDATABASE=taxonomy,
    PGSCHEMA=taxonomy_schema,
    PGUSER=lambda_user,
    PGPASSWORD=<password>,
    PGSSLMODE=require
  }"
```

### Lambda 3: Mapping Rules

```bash
cd lambdas/mapping_rules

npm install
npm run build
npm run package

aws lambda create-function \
  --function-name propelus-mapping-rules \
  --runtime nodejs20.x \
  --role arn:aws:iam::ACCOUNT_ID:role/propelus-lambda-role \
  --handler dist/handler.handler \
  --zip-file fileb://function.zip \
  --timeout 300 \
  --memory-size 1024 \
  --environment Variables="{
    PGHOST=<aurora-endpoint>,
    PGPORT=5432,
    PGDATABASE=taxonomy,
    PGSCHEMA=taxonomy_schema,
    PGUSER=lambda_user,
    PGPASSWORD=<password>,
    PGSSLMODE=require,
    BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,
    AWS_REGION=us-east-1
  }"
```

### Lambda 4: Translation

```bash
cd lambdas/translation

npm install
npm run build
npm run package

aws lambda create-function \
  --function-name propelus-translation \
  --runtime nodejs20.x \
  --role arn:aws:iam::ACCOUNT_ID:role/propelus-lambda-role \
  --handler dist/handler.handler \
  --zip-file fileb://function.zip \
  --timeout 60 \
  --memory-size 512 \
  --environment Variables="{
    PGHOST=<aurora-endpoint>,
    PGPORT=5432,
    PGDATABASE=taxonomy,
    PGSCHEMA=taxonomy_schema,
    PGUSER=lambda_user,
    PGPASSWORD=<password>,
    PGSSLMODE=require,
    REDIS_ENABLED=true,
    REDIS_HOST=<redis-endpoint>,
    REDIS_PORT=6379
  }"
```

---

## Phase 3: Infrastructure Setup

### Step 1: Create S3 Bucket

```bash
# Create bucket for taxonomy uploads
aws s3 mb s3://propelus-taxonomy-uploads-prod

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket propelus-taxonomy-uploads-prod \
  --versioning-configuration Status=Enabled

# Configure lifecycle policy (optional)
aws s3api put-bucket-lifecycle-configuration \
  --bucket propelus-taxonomy-uploads-prod \
  --lifecycle-configuration file://s3-lifecycle.json
```

### Step 2: Configure S3 Trigger

```bash
# Add S3 trigger to Ingestion Lambda
aws lambda add-permission \
  --function-name propelus-ingestion-cleansing \
  --statement-id s3-trigger \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::propelus-taxonomy-uploads-prod

# Configure S3 notification
aws s3api put-bucket-notification-configuration \
  --bucket propelus-taxonomy-uploads-prod \
  --notification-configuration file://s3-notification.json
```

### Step 3: Create EventBridge Rules

```bash
# Rule: Trigger Mapping Command after Ingestion completes
aws events put-rule \
  --name propelus-trigger-mapping-command \
  --event-pattern '{
    "source": ["propelus.ingestion"],
    "detail-type": ["Ingestion Complete"],
    "detail": {
      "status": ["success"]
    }
  }'

# Add Lambda target
aws events put-targets \
  --rule propelus-trigger-mapping-command \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT:function:propelus-taxonomy-mapping-command"
```

### Step 4: Deploy Step Functions Workflow

```bash
# Create Step Functions state machine
aws stepfunctions create-state-machine \
  --name propelus-taxonomy-processing \
  --definition file://infrastructure/step-functions/taxonomy-processing-workflow.json \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/propelus-stepfunctions-role
```

---

## Phase 4: Seed Data

### Step 1: Create Mapping Rules

```sql
-- Insert command-based mapping rules
INSERT INTO silver_mapping_taxonomies_rules (
  name, enabled, command, AI_mapping_flag, Human_mapping_flag
) VALUES
  ('Exact Match', true, 'equals', false, false),
  ('Contains Match', true, 'contains', false, false),
  ('Starts With', true, 'startswith', false, false),
  ('Regex Match', true, 'regex', false, false);

-- Create rule assignments with priorities
INSERT INTO silver_mapping_taxonomies_rules_assignment (
  mapping_rule_id, master_node_type_id, node_type_id, priority, enabled
)
SELECT
  r.mapping_rule_id,
  1, -- master node type
  2, -- customer node type
  CASE r.command
    WHEN 'equals' THEN 1
    WHEN 'startswith' THEN 2
    WHEN 'contains' THEN 3
    WHEN 'regex' THEN 4
  END as priority,
  true
FROM silver_mapping_taxonomies_rules r
WHERE r.AI_mapping_flag = false;
```

### Step 2: Load Master Taxonomy

```bash
# Upload master taxonomy Excel file
aws s3 cp Master_-1_-1.xlsx s3://propelus-taxonomy-uploads-prod/

# Or trigger via API
curl -X POST https://api.propelus.ai/v1/ingest \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <api-key>" \
  -d @master-taxonomy-payload.json
```

---

## Phase 5: Monitoring & Alarms

### CloudWatch Alarms

```bash
# Lambda error alarm
aws cloudwatch put-metric-alarm \
  --alarm-name propelus-ingestion-errors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=propelus-ingestion-cleansing

# Database connection alarm
aws cloudwatch put-metric-alarm \
  --alarm-name propelus-db-connections \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 60 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

### CloudWatch Dashboards

Create dashboard to monitor:
- Lambda invocations, duration, errors
- Database connections, CPU, memory
- S3 upload events
- Step Functions execution status

---

## Phase 6: Testing

### Smoke Tests

```bash
# Test ingestion
aws lambda invoke \
  --function-name propelus-ingestion-cleansing \
  --payload file://test-event-ingestion.json \
  output.json

# Test mapping command
aws lambda invoke \
  --function-name propelus-taxonomy-mapping-command \
  --payload file://test-event-mapping.json \
  output.json

# Test translation
curl -X POST https://api.propelus.ai/v1/translate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <api-key>" \
  -d '{
    "source_taxonomy": "customer_123",
    "target_taxonomy": "master",
    "source_code": "RN"
  }'
```

### Verify Database

```sql
-- Check data loaded
SELECT COUNT(*) FROM bronze_load_details WHERE load_status = 'completed';
SELECT COUNT(*) FROM silver_taxonomies_nodes WHERE status = 'active';
SELECT COUNT(*) FROM silver_mapping_taxonomies WHERE status = 'active';
SELECT COUNT(*) FROM gold_mapping_taxonomies;

-- Check version tracking
SELECT * FROM silver_taxonomies_versions ORDER BY created_at DESC LIMIT 5;
```

---

## Rollback Procedures

### Lambda Rollback

```bash
# List versions
aws lambda list-versions-by-function \
  --function-name propelus-ingestion-cleansing

# Rollback to previous version
aws lambda update-alias \
  --function-name propelus-ingestion-cleansing \
  --name PROD \
  --function-version <previous-version>
```

### Database Rollback

*Note: Migrations are not automatically reversible. Manual rollback required.*

```sql
-- Example: Rollback migration 024
DROP TABLE IF EXISTS gold_mapping_taxonomies CASCADE;
-- Restore from backup if needed
```

---

## Security Checklist

- [ ] Database credentials stored in AWS Secrets Manager
- [ ] Lambda functions use least-privilege IAM roles
- [ ] VPC configuration for Lambda and RDS
- [ ] S3 bucket encryption enabled
- [ ] API Gateway with API key authentication
- [ ] CloudWatch Logs encryption enabled
- [ ] Database encrypted at rest (Aurora encryption)
- [ ] Database encrypted in transit (SSL/TLS)

---

## Performance Tuning

### Lambda Optimization

- **Memory**: Start with 512MB, increase if timeout occurs
- **Timeout**: Ingestion 300s, Mapping 300s, Translation 60s
- **Provisioned Concurrency**: Enable for Translation Lambda (high traffic)

### Database Optimization

```sql
-- Add custom indexes if needed
CREATE INDEX CONCURRENTLY idx_custom_query ON silver_taxonomies_nodes(column);

-- Analyze tables
ANALYZE bronze_load_details;
ANALYZE silver_taxonomies_nodes;
ANALYZE silver_mapping_taxonomies;
```

---

## Maintenance

### Weekly Tasks

- Review CloudWatch metrics and alarms
- Check Lambda error logs
- Verify database backups
- Review Gold layer sync accuracy

### Monthly Tasks

- Review and optimize database indexes
- Analyze Lambda performance metrics
- Update mapping rules based on feedback
- Audit inactive taxonomies

---

## Support

For deployment issues:
- **Infrastructure**: Check CloudFormation/Pulumi logs
- **Lambda**: Review CloudWatch Logs
- **Database**: Check Aurora logs and performance insights
- **Documentation**: See main README.md

---

**Last Updated**: January 26, 2025
**Version**: 4.0.0
