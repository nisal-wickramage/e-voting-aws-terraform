# Step 4 & 5: Create Security Groups for ALB and ECS
# Uses separate rule resources to avoid circular dependencies
# ALB SG: Allows HTTPS from VPC CIDR, all outbound
# ECS SG: Allows inbound from ALB, all outbound

# Step 4: ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-sg"
    }
  )
}

# ALB Ingress: HTTPS from CloudFront (via VPC CIDR)
resource "aws_vpc_security_group_ingress_rule" "alb_https_from_vpc" {
  security_group_id = aws_security_group.alb.id

  description = "HTTPS from CloudFront (via VPC CIDR)"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = var.vpc_cidr

  tags = {
    Name = "${var.project_name}-alb-https-in"
  }
}

# ALB Ingress: HTTP for inter-service communication
resource "aws_vpc_security_group_ingress_rule" "alb_http_from_ecs" {
  security_group_id = aws_security_group.alb.id

  description              = "HTTP from ECS tasks"
  from_port                = 80
  to_port                  = 80
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "${var.project_name}-alb-http-in"
  }
}

# Step 5: ECS Security Group
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-sg"
    }
  )
}

# ECS Ingress: Ephemeral ports from ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_ephemeral_from_alb" {
  security_group_id = aws_security_group.ecs.id

  description              = "Ephemeral ports from ALB"
  from_port                = 1024
  to_port                  = 65535
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "${var.project_name}-ecs-ephemeral-in"
  }
}

# ECS Ingress: HTTP from ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_http_from_alb" {
  security_group_id = aws_security_group.ecs.id

  description              = "HTTP from ALB"
  from_port                = 80
  to_port                  = 80
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "${var.project_name}-ecs-http-in"
  }
}
