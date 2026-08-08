# Step 6 & 7: Create Application Load Balancer and Target Group
# ALB: Internal, in private subnets, cross-zone load balancing
# Target Group: HTTP routing with health checks

# Step 6: Application Load Balancer
# Internal ALB in private subnets for ECS services
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection       = var.alb_enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

# Step 7: Default Target Group
# HTTP target group for ECS services with health checks
resource "aws_lb_target_group" "default" {
  name        = "${var.project_name}-default-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  deregistration_delay = var.deregistration_delay

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-default-tg"
    }
  )
}

# Default ALB listener
# Routes HTTP traffic to default target group
resource "aws_lb_listener" "default" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}
