include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/integration-secrets"
}

inputs = {
  # Example: Database password secret
  secret_name = "e-voting-db-credentials"
  secret_string = jsonencode({
    username = "postgres"
    password = "your-secure-password-here"  # Replace with actual password or use environment variable
    engine   = "postgres"
    host     = "db.example.com"
    port     = 5432
    dbname   = "e_voting"
  })
  
  recovery_window_in_days = 7
  enable_rotation         = false
  rotation_days           = 30

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
  }
}
