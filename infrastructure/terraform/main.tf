# Propelus Taxonomy Infrastructure
# Main Terraform configuration for AWS resources

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  backend "s3" {
    bucket         = "propelus-terraform-state"
    key            = "taxonomy/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "Propelus-Taxonomy"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DataTeam"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local variables
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedAt   = timestamp()
  }
  
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr
  
  azs             = local.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  
  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  
  tags = local.common_tags
}

# Security Groups
module "security_groups" {
  source = "./modules/security-groups"
  
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  tags        = local.common_tags
}

# RDS Aurora PostgreSQL
module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 8.0"
  
  name           = "${local.name_prefix}-aurora"
  engine         = "aurora-postgresql"
  engine_version = "15.4"
  
  instances = {
    1 = {
      instance_class      = var.db_instance_class
      publicly_accessible = false
    }
    2 = {
      instance_class      = var.db_instance_class
      publicly_accessible = false
    }
  }
  
  vpc_id               = module.vpc.vpc_id
  subnets              = module.vpc.private_subnets
  create_security_group = false
  vpc_security_group_ids = [module.security_groups.rds_security_group_id]
  
  database_name   = var.database_name
  master_username = var.database_username
  master_password = random_password.aurora_password.result
  
  storage_encrypted = true
  apply_immediately = var.environment != "production"
  
  backup_retention_period = var.environment == "production" ? 30 : 7
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = local.common_tags
}

# Random password for Aurora
resource "random_password" "aurora_password" {
  length  = 32
  special = true
}

# Store Aurora password in Secrets Manager
resource "aws_secretsmanager_secret" "aurora_password" {
  name_prefix = "${local.name_prefix}-aurora-password"
  description = "Aurora PostgreSQL master password"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "aurora_password" {
  secret_id = aws_secretsmanager_secret.aurora_password.id
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.aurora_password.result
    engine   = "aurora-postgresql"
    host     = module.aurora.cluster_endpoint
    port     = module.aurora.cluster_port
    dbname   = var.database_name
  })
}

# ElastiCache Redis
module "redis" {
  source = "./modules/elasticache"
  
  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  security_group_ids     = [module.security_groups.redis_security_group_id]
  node_type              = var.redis_node_type
  number_cache_clusters  = var.environment == "production" ? 2 : 1
  
  tags = local.common_tags
}

# S3 Buckets
resource "aws_s3_bucket" "audit_logs" {
  bucket = "${local.name_prefix}-audit-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "model_artifacts" {
  bucket = "${local.name_prefix}-model-artifacts-${data.aws_caller_identity.current.account_id}"
  
  tags = local.common_tags
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs.name
      }
    }
  }
  
  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.environment == "production" ? 30 : 7
  
  tags = local.common_tags
}

# Application Load Balancer
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"
  
  name = "${local.name_prefix}-alb"
  
  load_balancer_type = "application"
  
  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.security_groups.alb_security_group_id]
  
  enable_deletion_protection = var.environment == "production"
  enable_http2              = true
  enable_cross_zone_load_balancing = true
  
  access_logs = {
    enabled = true
    bucket  = aws_s3_bucket.alb_logs.id
  }
  
  target_groups = [
    {
      name_prefix      = "tax-"
      backend_protocol = "HTTP"
      backend_port     = 8000
      target_type      = "ip"
      
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 10
        protocol            = "HTTP"
        matcher             = "200"
      }
    },
    {
      name_prefix      = "trans-"
      backend_protocol = "HTTP"
      backend_port     = 8001
      target_type      = "ip"
      
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 10
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  ]
  
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      action_type        = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]
  
  tags = local.common_tags
}

# S3 Bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${local.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = local.common_tags
}

# IAM Roles for ECS Tasks
module "ecs_task_execution_role" {
  source = "./modules/iam-roles"
  
  name_prefix = local.name_prefix
  type        = "ecs_task_execution"
  tags        = local.common_tags
}

module "ecs_task_role" {
  source = "./modules/iam-roles"
  
  name_prefix = local.name_prefix
  type        = "ecs_task"
  tags        = local.common_tags
}

# ECR Repositories
resource "aws_ecr_repository" "taxonomy_api" {
  name                 = "${local.name_prefix}-taxonomy-api"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = local.common_tags
}

resource "aws_ecr_repository" "translation_service" {
  name                 = "${local.name_prefix}-translation-service"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = local.common_tags
}

resource "aws_ecr_repository" "admin_ui" {
  name                 = "${local.name_prefix}-admin-ui"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = local.common_tags
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.aurora.cluster_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.redis.primary_endpoint
  sensitive   = true
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.lb_dns_name
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    taxonomy_api        = aws_ecr_repository.taxonomy_api.repository_url
    translation_service = aws_ecr_repository.translation_service.repository_url
    admin_ui           = aws_ecr_repository.admin_ui.repository_url
  }
}