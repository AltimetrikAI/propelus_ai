# Propelus Taxonomy Framework - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "propelus-taxonomy"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Database Configuration
variable "database_name" {
  description = "Name of the main database"
  type        = string
  default     = "propelus_taxonomy"
}

variable "database_username" {
  description = "Master username for database"
  type        = string
  default     = "propelus_admin"
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "database_backup_retention" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

# Lambda Configuration
variable "lambda_architecture" {
  description = "Lambda function architecture"
  type        = string
  default     = "x86_64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Lambda architecture must be x86_64 or arm64."
  }
}

# AI/ML Configuration
variable "bedrock_model_id" {
  description = "AWS Bedrock model ID for AI processing"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "bedrock_region" {
  description = "AWS region for Bedrock service"
  type        = string
  default     = "us-east-1"
}

# Monitoring & Alerting
variable "alerts_sns_topic_arn" {
  description = "SNS topic ARN for alerts (optional)"
  type        = string
  default     = ""
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "Log level must be DEBUG, INFO, WARN, or ERROR."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

# Security
variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable AWS WAF for API Gateway"
  type        = bool
  default     = true
}

variable "api_rate_limit" {
  description = "API Gateway rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "api_burst_limit" {
  description = "API Gateway burst limit"
  type        = number
  default     = 2000
}

# Scaling
variable "enable_auto_scaling" {
  description = "Enable auto scaling for RDS and Redis"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 10
}

# Backup & Recovery
variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for RDS"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions"
  type        = number
  default     = 100
}

# Feature Flags
variable "enable_translation_caching" {
  description = "Enable Redis caching for translations"
  type        = bool
  default     = true
}

variable "enable_data_lineage" {
  description = "Enable detailed data lineage tracking"
  type        = bool
  default     = true
}

variable "enable_ai_mapping" {
  description = "Enable AI-powered mapping with Bedrock"
  type        = bool
  default     = true
}

# Development Settings
variable "create_test_data" {
  description = "Create test data for development environment"
  type        = bool
  default     = false
}

variable "enable_debug_logging" {
  description = "Enable debug logging for development"
  type        = bool
  default     = false
}

# API Configuration
variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

variable "api_domain_name" {
  description = "Custom domain name for API (optional)"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for custom domain"
  type        = string
  default     = ""
}

# Data Retention
variable "bronze_data_retention_days" {
  description = "S3 lifecycle policy - days to retain Bronze layer data"
  type        = number
  default     = 90
}

variable "silver_data_retention_days" {
  description = "S3 lifecycle policy - days to retain Silver layer data"
  type        = number
  default     = 365
}

variable "gold_data_retention_days" {
  description = "S3 lifecycle policy - days to retain Gold layer data"
  type        = number
  default     = 2555  # 7 years
}

# Compliance
variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all services"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit for all services"
  type        = bool
  default     = true
}

variable "compliance_mode" {
  description = "Compliance mode (none, hipaa, sox)"
  type        = string
  default     = "hipaa"
  validation {
    condition     = contains(["none", "hipaa", "sox"], var.compliance_mode)
    error_message = "Compliance mode must be none, hipaa, or sox."
  }
}