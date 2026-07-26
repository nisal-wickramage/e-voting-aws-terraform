# Step 3: Create CloudWatch Log Group for ECS Container Insights
# Placeholder - implementation in next step

resource "aws_cloudwatch_log_group" "ecs" {
  count = var.enable_container_insights ? 1 : 0

  name              = "/ecs/${var.cluster_name}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-logs"
    }
  )
}
