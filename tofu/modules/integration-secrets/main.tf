# ============================================================
# Secrets Manager Secret
# ============================================================

resource "aws_secretsmanager_secret" "integration" {
  name                    = "${var.project_name}/${var.environment}/${var.secret_name}"
  recovery_window_in_days = var.recovery_window_in_days
  force_overwrite_replica_secret = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.secret_name}-${var.environment}"
    }
  )
}

# ============================================================
# Secret Version (contains the actual secret data)
# ============================================================

resource "aws_secretsmanager_secret_version" "integration" {
  secret_id      = aws_secretsmanager_secret.integration.id
  secret_string  = var.secret_string
}

# ============================================================
# Secret Rotation (optional)
# ============================================================

resource "aws_secretsmanager_secret_rotation" "integration" {
  count             = var.enable_rotation ? 1 : 0
  secret_id         = aws_secretsmanager_secret.integration.id

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [aws_secretsmanager_secret_version.integration]
}
