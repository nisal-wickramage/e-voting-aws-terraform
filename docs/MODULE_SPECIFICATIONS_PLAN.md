# Module Specifications Plan

## Overview
This document outlines the specification structure for all 8 modules in the e-voting infrastructure. Each module is designed for independent testing and deployment with minimal blast radius.

## Specification Structure

Each module has a `SPEC.md` file defining:
- **Purpose**: 1-2 line summary
- **Inputs**: Variable names, types, descriptions
- **Outputs**: Output names, descriptions
- **Resources**: AWS resources created
- **Security**: Security group rules, IAM policies
- **Testing**: Expected behavior and edge cases

---

## Module Breakdown

### 1. network (No dependencies)
**Status**: Foundation module
**Purpose**: Create VPC, subnets, route tables, NACLs, and VPC endpoints for private-only architecture

**Key Resources**:
- VPC (10.0.0.0/16)
- Private subnets (2 AZs)
- NAT gateways + EIPs
- Route tables (private)
- VPC endpoints (ECR, S3, CloudWatch Logs, Secrets Manager)
- NACLs for network segmentation

**Outputs**:
- VPC ID, private subnet IDs
- NAT gateway IPs
- VPC endpoint IDs
- Availability zones

---

### 2. database (Depends: network)
**Status**: Stateful infrastructure
**Purpose**: Create RDS PostgreSQL Multi-AZ cluster with security isolation

**Key Resources**:
- DB subnet group (private subnets only)
- RDS PostgreSQL instance (Multi-AZ)
- Security group (ingress from ECS security group)
- Parameter group
- Monitoring role

**Outputs**:
- RDS endpoint (writer and reader)
- RDS port, security group ID
- DB subnet group ID

---

### 3. platform (Depends: network)
**Status**: Container orchestration foundation
**Purpose**: Create ECS cluster and Application Load Balancer in private subnets

**Key Resources**:
- ECS cluster (Fargate capacity provider)
- Application Load Balancer (private subnets)
- Target groups (placeholder)
- Security groups (ALB, ECS)
- ALB listener rules (added by ecs-services)

**Outputs**:
- ECS cluster ARN/name
- ALB ARN, DNS name
- ALB security group ID
- ECS security group ID
- ALB target group ARN (placeholder)

---

### 4. ecs-services (Depends: platform, database)
**Status**: Application microservices
**Purpose**: Deploy microservices as ECS Fargate tasks with ECR repositories

**Key Resources**:
- ECR repositories (per service)
- ECS task definitions
- ECS services
- ALB listener rules
- ALB target groups
- CloudWatch log groups (per service)

**Outputs**:
- ECR repository URLs (per service)
- ECS service ARNs
- CloudWatch log group names

---

### 5. s3-frontend (Depends: network)
**Status**: Static content storage
**Purpose**: Create S3 bucket for frontend SPA with private access

**Key Resources**:
- S3 bucket (private, versioning enabled)
- Bucket policy (CloudFront-only access)
- Bucket encryption (SSE-S3)
- Public access block

**Outputs**:
- S3 bucket name, ARN
- S3 bucket regional domain name

---

### 6. cdn-waf (Depends: platform, s3-frontend)
**Status**: Public entry point
**Purpose**: Expose frontend and API via CloudFront with WAF protection

**Key Resources**:
- WAF IP set (rate limiting)
- WAF rules (geo-blocking, SQL injection, etc.)
- CloudFront distribution (VPC origin → ALB)
- CloudFront distribution (S3 origin → frontend)
- Origin access identity (S3)
- CloudFront security headers

**Outputs**:
- CloudFront domain names (API, frontend)
- WAF ARN

---

### 7. monitoring (Depends: platform, database)
**Status**: Observability infrastructure
**Purpose**: CloudWatch alarms and dashboards for operational visibility

**Key Resources**:
- SNS topics (for alerts)
- CloudWatch alarms (ECS, RDS, ALB)
- CloudWatch dashboards
- Log groups (centralized)
- Metric filters

**Outputs**:
- SNS topic ARNs
- CloudWatch dashboard URLs (display-only)

---

### 8. disaster-recovery (Depends: database, s3-frontend)
**Status**: Data protection and recovery
**Purpose**: Enable automated backups, snapshots, and cross-region replication

**Key Resources**:
- RDS automated backups (enabled in database module, configured here)
- RDS snapshot schedule
- S3 cross-region replication
- S3 bucket versioning (enabled in s3-frontend)
- Recovery procedures (documentation)

**Outputs**:
- RDS backup retention period
- S3 replication status
- Disaster recovery runbook (link)

---

## Dependency Matrix

| Module | network | database | platform | ecs-services | s3-frontend | cdn-waf | monitoring | disaster-recovery |
|--------|---------|----------|----------|--------------|-------------|---------|------------|-------------------|
| network | - | - | - | - | - | - | - | - |
| database | ✓ | - | - | - | - | - | - | - |
| platform | ✓ | - | - | - | - | - | - | - |
| ecs-services | ✓ | ✓ | ✓ | - | - | - | - | - |
| s3-frontend | ✓ | - | - | - | - | - | - | - |
| cdn-waf | - | - | ✓ | ✓ | ✓ | - | - | - |
| monitoring | - | ✓ | ✓ | - | - | - | - | - |
| disaster-recovery | - | ✓ | - | - | ✓ | - | - | - |

---

## Development Workflow

1. **Create SPEC.md** for each module
2. **Implement module** following spec (start with variables.tf)
3. **Test with LocalStack** (tofu init → plan → apply)
4. **Create terragrunt.hcl** with dependency blocks
5. **Test integration** (terragrunt run-all plan)
6. **Document README.md** in module directory

---

## Testing Strategy

### Unit Tests (LocalStack)
- Each module tested in isolation
- Mock outputs for dependencies
- Validation: resource count, security groups, outputs

### Integration Tests (Staging)
- Test module chains (network → platform → ecs-services)
- Validate cross-module connectivity
- Test variable injection via Terragrunt

### Production Validation
- Full environment deployment
- Health checks, latency, failover testing
- Backup/restore procedures

---

## Quick Reference: Deployment Order

```
1. tofu/modules/network                 ← No dependencies
   ↓
2. tofu/modules/database                ← Depends: network
   ├─ tofu/modules/platform             ← Depends: network
   │  └─ tofu/modules/ecs-services      ← Depends: platform + database
   │
   ├─ tofu/modules/s3-frontend          ← Depends: network
   │  └─ tofu/modules/cdn-waf           ← Depends: platform + s3-frontend
   │
   ├─ tofu/modules/monitoring           ← Depends: platform + database
   │
   └─ tofu/modules/disaster-recovery    ← Depends: database + s3-frontend
```
