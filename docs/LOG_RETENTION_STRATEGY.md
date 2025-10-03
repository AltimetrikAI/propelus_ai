# Audit Log Retention Strategy

## Overview

All Silver layer tables have corresponding `_log` tables that capture every INSERT, UPDATE, and DELETE operation via PostgreSQL triggers. This document outlines the retention strategy to prevent unbounded growth while meeting compliance requirements.

## Requirements

### Compliance
- **SOC 2**: Requires audit trail retention
- **Estimated Requirement**: 2+ years (pending confirmation from Security/Compliance team)
- **Data Subject**: All changes to taxonomy data (nodes, attributes, mappings, versions)

### Performance
- **Growth Rate**: ~6,000 rows per load × N customers × M loads/month
- **Concern**: Log tables become unqueryable over time
- **Target**: Keep query performance <2s for recent logs

## Affected Tables

```
silver_taxonomies_log
silver_taxonomies_nodes_types_log
silver_taxonomies_nodes_log
silver_taxonomies_nodes_attributes_log
silver_taxonomies_attribute_types_log
silver_mapping_taxonomies_rules_log
silver_mapping_rules_assignment_log
silver_taxonomies_versions (already versioned, may not need separate log)
```

## Retention Strategy Options

### Option A: Time-Based Partitioning (RECOMMENDED)

**Approach**: Partition log tables by month, auto-archive/drop old partitions

**Implementation**:

```sql
-- Example for silver_taxonomies_nodes_log
CREATE TABLE silver_taxonomies_nodes_log (
  id SERIAL,
  node_id INTEGER NOT NULL,
  old_row JSONB,
  new_row JSONB,
  operation_type VARCHAR(20),
  operation_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
  user_name VARCHAR(255)
) PARTITION BY RANGE (operation_date);

-- Create monthly partitions (automated via scheduled job)
CREATE TABLE silver_taxonomies_nodes_log_2024_10
  PARTITION OF silver_taxonomies_nodes_log
  FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');

CREATE TABLE silver_taxonomies_nodes_log_2024_11
  PARTITION OF silver_taxonomies_nodes_log
  FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');

-- Index on each partition
CREATE INDEX idx_nodes_log_2024_10_date ON silver_taxonomies_nodes_log_2024_10(operation_date);
CREATE INDEX idx_nodes_log_2024_10_node ON silver_taxonomies_nodes_log_2024_10(node_id);
```

**Archival Strategy**:

```sql
-- Lambda/cron job runs monthly to:
-- 1. Archive partitions older than 2 years to S3
COPY (SELECT * FROM silver_taxonomies_nodes_log_2022_10)
TO PROGRAM 'aws s3 cp - s3://propelus-audit-archive/nodes_log/2022_10.csv'
WITH CSV HEADER;

-- 2. Drop archived partitions
DROP TABLE silver_taxonomies_nodes_log_2022_10;

-- 3. Create next month's partition
CREATE TABLE silver_taxonomies_nodes_log_2024_12
  PARTITION OF silver_taxonomies_nodes_log
  FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
```

**Pros**:
- ✅ Excellent query performance (only scans relevant partitions)
- ✅ Simple to archive old data
- ✅ Standard PostgreSQL feature
- ✅ Meets compliance (archives to S3 for long-term retention)

**Cons**:
- Requires monthly maintenance job
- Need to manage partition creation

**Estimated Storage**:
- **Active (2 years)**: ~500MB - 2GB per log table
- **Archived (S3)**: ~$0.023/GB/month (S3 Standard)

---

### Option B: Scheduled DELETE Job

**Approach**: Daily/weekly Lambda deletes records older than retention period

**Implementation**:

```typescript
// Lambda function runs daily
export const cleanupAuditLogs = async () => {
  const retentionDays = 730; // 2 years

  const tables = [
    'silver_taxonomies_log',
    'silver_taxonomies_nodes_log',
    'silver_taxonomies_nodes_attributes_log',
    // ... other log tables
  ];

  for (const table of tables) {
    await pool.query(`
      DELETE FROM ${table}
      WHERE operation_date < NOW() - INTERVAL '${retentionDays} days'
    `);
  }
};
```

**Pros**:
- ✅ Simple implementation
- ✅ No schema changes

**Cons**:
- ❌ DELETE on large tables is slow and locks table
- ❌ Bloat (deleted rows leave dead tuples, need VACUUM)
- ❌ No archival (data is lost)

---

### Option C: Cyclic Buffer (Fixed Row Count)

**Approach**: Keep only last N records per table

**Implementation**:

```sql
-- Trigger maintains fixed size (e.g., 100,000 rows per table)
CREATE OR REPLACE FUNCTION maintain_log_size()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete oldest records beyond limit
  DELETE FROM silver_taxonomies_nodes_log
  WHERE id NOT IN (
    SELECT id FROM silver_taxonomies_nodes_log
    ORDER BY operation_date DESC
    LIMIT 100000
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_maintain_log_size
AFTER INSERT ON silver_taxonomies_nodes_log
FOR EACH STATEMENT EXECUTE FUNCTION maintain_log_size();
```

**Pros**:
- ✅ Predictable storage size
- ✅ Automatic (no cron jobs)

**Cons**:
- ❌ Trigger on every insert (performance overhead)
- ❌ Retention period varies based on activity (not time-based)
- ❌ No archival
- ❌ Doesn't meet time-based compliance requirements

---

## Recommended Implementation

### Phase 1: Document & Defer (Current)

**Action**: Add to migration files as **commented-out SQL** with documentation

```sql
-- ============================================
-- LOG RETENTION STRATEGY (NOT YET IMPLEMENTED)
-- ============================================
--
-- TODO: Implement log retention after confirming compliance requirements
--
-- Recommended Approach: Monthly partitioning with S3 archival
-- Retention Period: 2 years (TBD - awaiting Security/Compliance confirmation)
--
-- See: /docs/LOG_RETENTION_STRATEGY.md
--
-- Uncomment and customize after requirements confirmed:
--
-- CREATE TABLE silver_taxonomies_nodes_log (
--   ...
-- ) PARTITION BY RANGE (operation_date);
```

### Phase 2: Implement Partitioning (After Compliance Confirmation)

1. **Migrate existing log tables** to partitioned versions
2. **Create Lambda** for monthly partition management
3. **Set up S3 archival** with Glacier transition after 2 years
4. **Monitor storage growth** and adjust as needed

### Phase 3: Automation (Production)

```yaml
# CloudWatch Event Rule: Monthly partition maintenance
Schedule: cron(0 2 1 * ? *)  # 2 AM on 1st of every month

Lambda: partition-maintenance
  - Create next month's partition
  - Archive partitions older than 24 months to S3
  - Drop partitions older than 25 months
  - Send SNS notification on success/failure
```

## Cost Estimate

### Option A (Recommended)

**Active Database Storage (2 years)**:
- 8 log tables × 2GB = 16GB
- Aurora cost: ~$0.10/GB/month = **$1.60/month**

**S3 Archive (>2 years)**:
- Historical logs in S3 Glacier
- 8 tables × 2GB/year × 5 years = 80GB
- S3 Glacier cost: ~$0.004/GB/month = **$0.32/month**

**Total: ~$2/month for audit log retention**

## Queries for Monitoring

```sql
-- Check log table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename LIKE '%_log'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Count records by month
SELECT
  DATE_TRUNC('month', operation_date) AS month,
  COUNT(*) AS log_count
FROM silver_taxonomies_nodes_log
GROUP BY DATE_TRUNC('month', operation_date)
ORDER BY month DESC;

-- Oldest log record
SELECT MIN(operation_date), MAX(operation_date)
FROM silver_taxonomies_nodes_log;
```

## Action Items

- [ ] **Confirm compliance requirements** with Security team (target: 2 years?)
- [ ] **Validate SOC 2 requirements** for audit log retention
- [ ] **Implement Option A** (partitioning) in migration file
- [ ] **Create partition maintenance Lambda** with S3 archival
- [ ] **Set up monitoring** for log table growth
- [ ] **Document archival access** process for compliance audits

## References

- PostgreSQL Partitioning: https://www.postgresql.org/docs/current/ddl-partitioning.html
- AWS S3 Lifecycle Policies: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html
- Meeting Transcript: Oct 3, 2024 (Edwin raised the concern)
