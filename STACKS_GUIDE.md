# Terragrunt Stacks - Complete Guide

This guide demonstrates how to use Terragrunt stacks to compose infrastructure from reusable modules.

## What Are Stacks?

Stacks are **predefined compositions of modules** that work together to deliver specific functionality. Instead of managing individual modules, you deploy an entire stack:

```
Stack = Collection of interdependent modules with proper ordering
```

## The Three Stacks Included

### Stack 1: Basic API
**File**: `stacks/basic-api/terragrunt.stack.hcl`

**What it deploys**:
```
Unit Name           Module Path              Depends On
─────────────────────────────────────────────────────────
network             terragrunt/dev/network   (none)
cluster             terragrunt/dev/cluster   network
database            terragrunt/dev/database  network
notification        terragrunt/dev/notification (none)
ecs_service_api     terragrunt/dev/ecs-service-api  cluster, database
ecs_migrations      terragrunt/dev/ecs-migrations   cluster, database
ecs_alarms          terragrunt/dev/ecs-alarms       ecs_service_api, notification
rds_alarms          terragrunt/dev/rds-alarms       database, notification
cdn_waf             terragrunt/dev/cdn-waf          cluster
```

**Total units**: 9
**Services created**: 1 (API)

### Stack 2: Web App
**File**: `stacks/web-app/terragrunt.stack.hcl`

**What it deploys** (everything from basic-api PLUS):
```
Unit Name           Module Path              Depends On
─────────────────────────────────────────────────────────
s3_frontend         terragrunt/dev/s3-frontend  (none)
cdn_waf             terragrunt/dev/cdn-waf      cluster, s3_frontend
```

**Total units**: 10 (adds S3 and CDN dual-origin)
**Services created**: 1 API + Frontend

### Stack 3: Multi-Service API
**File**: `stacks/multi-service-api/terragrunt.stack.hcl`

**What it deploys**:
```
Unit Name           Module Path              Depends On
─────────────────────────────────────────────────────────
network             terragrunt/dev/network   (none)
cluster             terragrunt/dev/cluster   network
database            terragrunt/dev/database  network
notification        terragrunt/dev/notification (none)
sqs_queue           terragrunt/dev/sqs-queue-async-api (none)
ecs_service_api     terragrunt/dev/ecs-service-api  cluster, database
ecs_service_async   terragrunt/dev/ecs-service-async-api  cluster, database, sqs_queue
ecs_migrations      terragrunt/dev/ecs-migrations   cluster, database
ecs_alarms          terragrunt/dev/ecs-alarms       ecs_service_api, ecs_service_async, notification
rds_alarms          terragrunt/dev/rds-alarms       database, notification
sqs_alarms          terragrunt/dev/sqs-alarms       sqs_queue, notification
cdn_waf             terragrunt/dev/cdn-waf          cluster
```

**Total units**: 12
**Services created**: 2 (API + Worker), 1 Queue

## Deploying a Stack

### Step 1: Generate the Stack
```bash
cd stacks/basic-api
terragrunt stack generate
```

### Step 2: Initialize
```bash
terragrunt stack run -- init
```

### Step 3: Plan
```bash
terragrunt stack run -- plan
```

### Step 4: Apply
```bash
terragrunt stack run -- apply
```

### Step 5: View Outputs
```bash
terragrunt stack output
```

## Composition Pattern

Each stack is built from reusable module blocks:

```hcl
unit "service_name" {
  source = "../../terragrunt/dev/module-path"
  description = "What this unit does"
  after = [unit.dependency1, unit.dependency2]
}
```

## Use Case Mapping

**Building a REST API?**
→ Use `stacks/basic-api`

**Building a web application?**
→ Use `stacks/web-app`

**Building a microservices platform?**
→ Use `stacks/multi-service-api`

**Building something custom?**
→ Create your own stack by combining units

## Getting Started

1. **Understand modules**: Review `tofu/modules/*/README.md`
2. **Deploy basic stack**: `cd stacks/basic-api && terragrunt stack run -- apply`
3. **Customize**: Modify service configuration in `terragrunt/dev/`
4. **Create your stack**: Combine units in `stacks/your-stack/`
5. **Go production**: Adjust sizing and add backup/DR

---

**Ready to deploy? Start with `stacks/basic-api`! 🚀**
