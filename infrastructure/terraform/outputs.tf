# Propelus Taxonomy Framework - Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# Database Outputs
output "rds_cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = module.rds.cluster_reader_endpoint
  sensitive   = true
}

output "database_name" {
  description = "Name of the database"
  value       = var.database_name
}

output "database_port" {
  description = "Database port"
  value       = module.rds.cluster_port
}

# Redis Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.redis.primary_endpoint
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = module.redis.port
}

# S3 Outputs
output "bronze_bucket_name" {
  description = "Name of the Bronze layer S3 bucket"
  value       = module.s3.bronze_bucket_name
}

output "silver_bucket_name" {
  description = "Name of the Silver layer S3 bucket"
  value       = module.s3.silver_bucket_name
}

output "gold_bucket_name" {
  description = "Name of the Gold layer S3 bucket"
  value       = module.s3.gold_bucket_name
}

output "s3_bucket_arns" {
  description = "ARNs of all S3 buckets"
  value = {
    bronze = module.s3.bronze_bucket_arn
    silver = module.s3.silver_bucket_arn
    gold   = module.s3.gold_bucket_arn
  }
}

# Lambda Outputs
output "lambda_function_names" {
  description = "Names of Lambda functions"
  value = {
    for k, v in module.lambda_functions : k => v.function_name
  }
}

output "lambda_function_arns" {
  description = "ARNs of Lambda functions"
  value = {
    for k, v in module.lambda_functions : k => v.function_arn
  }
  sensitive = true
}

# SQS Outputs
output "sqs_queue_urls" {
  description = "URLs of SQS queues"
  value = {
    silver_processing = module.sqs.silver_processing_queue_url
    mapping_rules    = module.sqs.mapping_rules_queue_url
    dead_letter      = module.sqs.dlq_url
  }
}

output "sqs_queue_arns" {
  description = "ARNs of SQS queues"
  value = {
    silver_processing = module.sqs.silver_processing_queue_arn
    mapping_rules    = module.sqs.mapping_rules_queue_arn
    dead_letter      = module.sqs.dlq_arn
  }
  sensitive = true
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = module.api_gateway.api_url
}

output "api_gateway_stage_url" {
  description = "Stage URL of the API Gateway"
  value       = module.api_gateway.stage_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_id
}

# CloudWatch Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "log_group_names" {
  description = "Names of CloudWatch log groups"
  value = {
    for k, v in module.lambda_functions : k => v.log_group_name
  }
}

# IAM Outputs
output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
  sensitive   = true
}

output "api_gateway_role_arn" {
  description = "ARN of API Gateway role"
  value       = module.iam.api_gateway_role_arn
  sensitive   = true
}

# Security Outputs
output "security_group_ids" {
  description = "IDs of security groups"
  value = {
    rds    = module.rds.security_group_id
    redis  = module.redis.security_group_id
    lambda = module.vpc.lambda_security_group_id
  }
}

# Environment Configuration
output "environment_variables" {
  description = "Common environment variables for applications"
  value = {
    DATABASE_URL             = module.rds.connection_string
    REDIS_URL               = module.redis.connection_string
    S3_BRONZE_BUCKET        = module.s3.bronze_bucket_name
    S3_SILVER_BUCKET        = module.s3.silver_bucket_name
    S3_GOLD_BUCKET          = module.s3.gold_bucket_name
    SILVER_PROCESSING_QUEUE = module.sqs.silver_processing_queue_url
    MAPPING_RULES_QUEUE     = module.sqs.mapping_rules_queue_url
    AWS_REGION              = var.aws_region
    ENVIRONMENT             = var.environment
    LOG_LEVEL               = var.log_level
    BEDROCK_MODEL_ID        = var.bedrock_model_id
    BEDROCK_REGION          = var.bedrock_region
  }
  sensitive = true
}

# Deployment Information
output "deployment_info" {
  description = "Information about the deployment"
  value = {
    environment       = var.environment
    region           = var.aws_region
    project_name     = var.project_name
    deployment_time  = timestamp()
    terraform_version = ">=1.0"
  }
}

# Health Check Endpoints
output "health_check_endpoints" {
  description = "Health check endpoints for monitoring"
  value = {
    api_health         = "${module.api_gateway.stage_url}/health"
    translation_health = "${module.api_gateway.stage_url}/translate/health"
    admin_dashboard    = "${module.api_gateway.stage_url}/admin/dashboard"
  }
}

# DNS and SSL (if configured)
output "custom_domain_name" {
  description = "Custom domain name for API (if configured)"
  value       = var.api_domain_name != "" ? var.api_domain_name : null
}

# Cost Optimization Info
output "cost_optimization_settings" {
  description = "Cost optimization settings applied"
  value = {
    auto_scaling_enabled       = var.enable_auto_scaling
    reserved_concurrency      = var.reserved_concurrency
    cost_optimization_enabled = var.enable_cost_optimization
  }
}

# Compliance Information
output "compliance_settings" {
  description = "Compliance settings applied"
  value = {
    compliance_mode           = var.compliance_mode
    encryption_at_rest       = var.enable_encryption_at_rest
    encryption_in_transit    = var.enable_encryption_in_transit
    point_in_time_recovery   = var.enable_point_in_time_recovery
    backup_retention_days    = var.database_backup_retention
  }
}

# Feature Flags Status
output "feature_flags" {
  description = "Status of feature flags"
  value = {
    translation_caching = var.enable_translation_caching
    data_lineage       = var.enable_data_lineage
    ai_mapping         = var.enable_ai_mapping
    waf_enabled        = var.enable_waf
    vpc_endpoints      = var.enable_vpc_endpoints
  }
}

# Connection Strings (for applications)
output "connection_info" {
  description = "Connection information for applications"
  value = {
    database = {
      host     = module.rds.cluster_endpoint
      port     = module.rds.cluster_port
      database = var.database_name
      username = var.database_username
    }
    redis = {
      host = module.redis.primary_endpoint
      port = module.redis.port
    }
    api = {
      base_url  = module.api_gateway.api_url
      stage_url = module.api_gateway.stage_url
    }
  }
  sensitive = true
}

# Monitoring URLs
output "monitoring_urls" {
  description = "URLs for monitoring and observability"
  value = {
    cloudwatch_dashboard = module.monitoring.dashboard_url
    cloudwatch_logs     = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
    api_gateway_logs    = "https://console.aws.amazon.com/apigateway/home?region=${var.aws_region}#/apis/${module.api_gateway.api_id}/stages/prod/logs"
    lambda_insights     = "https://console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions"
  }
}