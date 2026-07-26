# Database Module - RDS PostgreSQL Instance

# DB Subnet Group - allows RDS to be placed in multiple AZs
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-db-subnet-group"
    }
  )
}

# RDS Security Group - allows inbound from ECS on port 5432
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

# RDS PostgreSQL Instance - smallest production-grade instance
resource "aws_db_instance" "main" {
  identifier              = "${var.project_name}-db"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.main.name

  # High availability and backups
  multi_az                    = var.db_multi_az
  publicly_accessible         = false
  backup_retention_period     = var.db_backup_retention_days
  backup_window               = "03:00-04:00"
  maintenance_window          = "mon:04:00-mon:05:00"
  copy_tags_to_snapshot       = true
  delete_automated_backups    = false
  skip_final_snapshot         = var.db_skip_final_snapshot
  final_snapshot_identifier   = var.db_skip_final_snapshot ? null : "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance and monitoring
  performance_insights_enabled    = var.environment != "dev" ? true : false
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-db"
    }
  )

  depends_on = [aws_db_parameter_group.main]
}

# Custom parameter group for PostgreSQL 15
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-postgres15"
  family = "postgres15"

  # Log all statements for audit
  parameter {
    name  = "log_statement"
    value = var.environment == "prod" ? "ddl" : "all"
  }

  # Connection pooling friendly settings
  parameter {
    name  = "max_connections"
    value = var.environment == "dev" ? "100" : "200"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-postgres15-params"
    }
  )
}

# CloudWatch alarm for low storage
resource "aws_cloudwatch_metric_alarm" "db_low_storage" {
  alarm_name          = "${var.project_name}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.db_allocated_storage * 1024 * 1024 * 1024 * 0.1  # 10% of allocated
  alarm_description   = "Alert when RDS free storage is below 10%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}
