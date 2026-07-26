# Disaster Recovery Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/disaster-recovery"
}

dependency "database" {
  config_path = "../database"

  mock_outputs = {
    rds_cluster_id = "e-voting-dev-cluster"
  }
}

inputs = {
  project_name  = "e-voting"
  environment   = "dev"
  rds_cluster_id = dependency.database.outputs.rds_cluster_id

  # Backup Configuration
  rds_backup_retention_days = 7
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  # Encryption
  enable_backup_encryption = false  # Not needed for dev
  kms_key_id              = null

  # Manual snapshots
  enable_manual_snapshots = true
  snapshot_retention_days = 14

  # Monitoring
  enable_backup_monitoring        = true
  backup_failure_threshold_count  = 1

  tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "disaster-recovery"
  }
}
