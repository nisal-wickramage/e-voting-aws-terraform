include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/sqs-queue"
}

inputs = {
  project_name              = "e-voting"
  environment               = "dev"
  queue_name                = "async-api-requests"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days
  enable_dlq                = true
  dlq_max_receive_count     = 3

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
  }
}
