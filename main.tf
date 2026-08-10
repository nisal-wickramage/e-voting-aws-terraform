# E-Voting AWS Infrastructure - Single Apply Deployment
# All modules are orchestrated here in dependency order

# ===== 1. Network Layer (No dependencies) =====
module "network" {
  source = "./tofu/modules/network"

  project_name     = var.project_name
  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  availability_zones = var.availability_zones
  
  # Subnet CIDR allocation for 3 tiers (web, app, db) across 2 AZs
  private_subnet_cidrs = {
    web = ["10.0.1.0/21", "10.0.9.0/21"]
    app = ["10.0.17.0/21", "10.0.25.0/21"]
    db  = ["10.0.33.0/21", "10.0.41.0/21"]
  }
  
  # VPC Endpoints for AWS services
  vpc_endpoint_services = ["s3", "dynamodb", "ec2", "elasticloadbalancing", "cloudwatch", "secretsmanager", "ecr.api", "ecr.dkr", "logs"]
  
  common_tags = local.common_tags
}

# ===== 2. Database (Depends: network) =====
module "database" {
  source = "./tofu/modules/database"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids_by_tier["db"]
  ecs_security_group_id   = module.cluster.ecs_security_group_id
  db_instance_class       = var.db_instance_class
  db_allocated_storage    = var.db_allocated_storage
  db_username             = var.db_username
  db_password             = var.db_password
  db_name                 = var.db_name
  db_backup_retention_days = var.rds_backup_retention_days

  common_tags = local.common_tags

  depends_on = [module.network, module.cluster]
}

# ===== 3. ECS Cluster & ALB (Depends: network) =====
module "cluster" {
  source = "./tofu/modules/cluster"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.network.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.network.private_subnet_ids_by_tier["app"]
  cluster_name       = "${var.project_name}-${var.environment}-cluster"
  alb_name           = "${var.project_name}-${var.environment}-alb"

  common_tags = local.common_tags

  depends_on = [module.network]
}

# ===== 4. ECS API Service (Depends: cluster, database) =====
module "ecs_api" {
  source = "./tofu/modules/ecs-api"

  project_name                = var.project_name
  environment                 = var.environment
  service_name                = "api"
  cluster_name                = module.cluster.ecs_cluster_name
  cluster_arn                 = module.cluster.ecs_cluster_arn
  container_port              = var.container_port
  container_image             = var.container_image
  desired_count               = var.desired_count
  ecs_subnet_ids              = module.network.private_subnet_ids_by_tier["app"]
  ecs_security_group_ids      = [module.cluster.ecs_security_group_id]
  ecs_task_execution_role_arn = module.cluster.ecs_task_execution_role_arn
  alb_target_group_arn        = module.cluster.default_target_group_arn
  alb_listener_arn            = module.cluster.alb_listener_arn
  
  # Database credentials
  db_host     = module.database.rds_endpoint
  db_port     = module.database.rds_port
  db_username = var.db_username
  db_password = var.db_password
  db_name     = var.db_name
  
  common_tags = local.common_tags

  depends_on = [module.cluster, module.database]
}

# ===== 5. S3 Frontend (Depends: network) =====
module "s3_frontend" {
  source = "./tofu/modules/s3-frontend"

  project_name       = var.project_name
  environment        = var.environment
  enable_versioning  = var.enable_versioning

  tags = local.common_tags

  depends_on = [module.network]
}

# ===== 6. CloudFront & WAF (Depends: cluster, s3-frontend) =====
module "cdn_waf" {
  source = "./tofu/modules/cdn-waf"

  project_name    = var.project_name
  environment     = var.environment
  enable_waf      = var.enable_waf
  
  # ALB origin for API
  alb_domain_name = module.cluster.alb_dns_name
  
  # S3 origin for frontend
  s3_bucket_regional_domain_name = module.s3_frontend.bucket_regional_domain_name
  cloudfront_oai_id              = module.s3_frontend.cloudfront_oai_id
  cloudfront_oai_iam_arn         = module.s3_frontend.cloudfront_oai_iam_arn

  depends_on = [module.cluster, module.s3_frontend]
}

# ===== 7. Disaster Recovery (Depends: database) =====
module "disaster_recovery" {
  source = "./tofu/modules/disaster-recovery"

  project_name                = var.project_name
  environment                 = var.environment
  rds_identifier              = module.database.rds_identifier
  rds_backup_retention_days   = var.rds_backup_retention_days

  tags = local.common_tags

  depends_on = [module.database]
}
