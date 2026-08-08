# Step 1: Create ECS Cluster
# Creates the ECS cluster with Fargate capacity support and Container Insights configuration
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-cluster"
    }
  )
}

# Step 2: Create ECS Cluster Capacity Providers
# Registers FARGATE and FARGATE_SPOT as capacity providers for the cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  count = 1  # Placeholder for step 2 logic

  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1  # Always use at least 1 on-demand task
    weight            = 100
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = 0
    capacity_provider = "FARGATE_SPOT"
  }
}
