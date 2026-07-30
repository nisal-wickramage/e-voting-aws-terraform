#!/bin/bash

# Script to delete all AWS resources created by e-voting infrastructure
# WARNING: This will permanently delete resources! Use with caution.
# Usage: ./delete-all-resources.sh [region]

REGION="${1:-us-east-1}"
PROJECT_NAME="e-voting"
ENVIRONMENT="dev"

echo "=========================================="
echo "E-VOTING INFRASTRUCTURE DELETION SCRIPT"
echo "=========================================="
echo "Region: $REGION"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo ""
echo "⚠️  WARNING: This will permanently delete:"
echo "   - Load Balancers"
echo "   - Target Groups"
echo "   - ECS Clusters & Services"
echo "   - RDS Databases"
echo "   - Security Groups"
echo "   - CloudWatch Log Groups"
echo "   - ECR Repositories"
echo "   - VPC & Subnets"
echo ""

# Confirm
read -p "Type 'yes' to confirm deletion: " confirmation
if [ "$confirmation" != "yes" ]; then
  echo "Deletion cancelled."
  exit 0
fi

echo ""
echo "Starting resource deletion..."
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function
delete_resource() {
  local resource_type=$1
  local command=$2
  
  echo "▸ Deleting $resource_type..."
  if eval "$command" 2>&1; then
    echo -e "  ${GREEN}✓ Done${NC}"
  else
    echo -e "  ${YELLOW}! Skipped (not found or already deleted)${NC}"
  fi
}

# 1. Delete ECS Services first (depends on ALB)
echo "=== STEP 1: Delete ECS Services ==="
CLUSTER_ARNS=$(aws ecs list-clusters --region $REGION --query "clusterArns[*]" --output text)
for CLUSTER_ARN in $CLUSTER_ARNS; do
  CLUSTER_NAME=$(echo $CLUSTER_ARN | awk -F'/' '{print $NF}')
  if [[ $CLUSTER_NAME == *"$PROJECT_NAME"* ]]; then
    echo "Deleting services in cluster: $CLUSTER_NAME"
    SERVICE_ARNS=$(aws ecs list-services --cluster $CLUSTER_NAME --region $REGION --query "serviceArns[*]" --output text)
    for SERVICE_ARN in $SERVICE_ARNS; do
      SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $NF}')
      delete_resource "ECS Service: $SERVICE_NAME" \
        "aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force --region $REGION"
      sleep 2  # Wait for service to begin deletion
    done
  fi
done

# 2. Delete ALB and Target Groups
echo ""
echo "=== STEP 2: Delete Load Balancers & Target Groups ==="
ALB_ARNS=$(aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME')].LoadBalancerArn" \
  --output text)

for ALB_ARN in $ALB_ARNS; do
  ALB_NAME=$(echo $ALB_ARN | awk -F'/' '{print $NF}' | cut -d'-' -f1-3)
  
  # Delete target groups associated with this ALB
  TG_ARNS=$(aws elbv2 describe-target-groups \
    --region $REGION \
    --load-balancer-arn $ALB_ARN \
    --query "TargetGroups[*].TargetGroupArn" \
    --output text 2>/dev/null)
  
  for TG_ARN in $TG_ARNS; do
    delete_resource "Target Group: $TG_ARN" \
      "aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION"
  done
  
  # Delete ALB
  delete_resource "Load Balancer: $ALB_NAME" \
    "aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION"
done

# 3. Delete ECS Clusters
echo ""
echo "=== STEP 3: Delete ECS Clusters ==="
CLUSTER_ARNS=$(aws ecs list-clusters --region $REGION --query "clusterArns[*]" --output text)
for CLUSTER_ARN in $CLUSTER_ARNS; do
  CLUSTER_NAME=$(echo $CLUSTER_ARN | awk -F'/' '{print $NF}')
  if [[ $CLUSTER_NAME == *"$PROJECT_NAME"* ]]; then
    delete_resource "ECS Cluster: $CLUSTER_NAME" \
      "aws ecs delete-cluster --cluster $CLUSTER_ARN --region $REGION"
  fi
done

# 4. Delete RDS Instances
echo ""
echo "=== STEP 4: Delete RDS Instances ==="
DB_INSTANCES=$(aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?contains(DBInstanceIdentifier, '$PROJECT_NAME')].DBInstanceIdentifier" \
  --output text)

for DB_INSTANCE in $DB_INSTANCES; do
  delete_resource "RDS Instance: $DB_INSTANCE" \
    "aws rds delete-db-instance --db-instance-identifier $DB_INSTANCE --skip-final-snapshot --region $REGION"
done

# 5. Delete RDS Subnet Groups
echo ""
echo "=== STEP 5: Delete RDS Subnet Groups ==="
DB_SUBNET_GROUPS=$(aws rds describe-db-subnet-groups \
  --region $REGION \
  --query "DBSubnetGroups[?contains(DBSubnetGroupName, '$PROJECT_NAME')].DBSubnetGroupName" \
  --output text 2>/dev/null)

for SUBNET_GROUP in $DB_SUBNET_GROUPS; do
  delete_resource "RDS Subnet Group: $SUBNET_GROUP" \
    "aws rds delete-db-subnet-group --db-subnet-group-name $SUBNET_GROUP --region $REGION"
done

# 6. Delete CloudWatch Log Groups
echo ""
echo "=== STEP 6: Delete CloudWatch Log Groups ==="
LOG_GROUPS=$(aws logs describe-log-groups \
  --region $REGION \
  --query "logGroups[?contains(logGroupName, '$PROJECT_NAME')].logGroupName" \
  --output text)

for LOG_GROUP in $LOG_GROUPS; do
  delete_resource "Log Group: $LOG_GROUP" \
    "aws logs delete-log-group --log-group-name $LOG_GROUP --region $REGION"
done

# 7. Delete ECR Repositories
echo ""
echo "=== STEP 7: Delete ECR Repositories ==="
ECR_REPOS=$(aws ecr describe-repositories \
  --region $REGION \
  --query "repositories[?contains(repositoryName, '$PROJECT_NAME')].repositoryName" \
  --output text 2>/dev/null)

for REPO in $ECR_REPOS; do
  delete_resource "ECR Repository: $REPO" \
    "aws ecr delete-repository --repository-name $REPO --force --region $REGION"
done

# 8. Delete Security Groups
echo ""
echo "=== STEP 8: Delete Security Groups ==="
sleep 10  # Wait for dependent resources to fully delete
SG_IDS=$(aws ec2 describe-security-groups \
  --region $REGION \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "SecurityGroups[?GroupName != 'default'].GroupId" \
  --output text 2>/dev/null)

for SG_ID in $SG_IDS; do
  delete_resource "Security Group: $SG_ID" \
    "aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
done

# 9. Delete Subnets
echo ""
echo "=== STEP 9: Delete Subnets ==="
SUBNET_IDS=$(aws ec2 describe-subnets \
  --region $REGION \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "Subnets[*].SubnetId" \
  --output text)

for SUBNET_ID in $SUBNET_IDS; do
  delete_resource "Subnet: $SUBNET_ID" \
    "aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION"
done

# 10. Delete NAT Gateways
echo ""
echo "=== STEP 10: Delete NAT Gateways ==="
NGWS=$(aws ec2 describe-nat-gateways \
  --region $REGION \
  --filter "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "NatGateways[*].NatGatewayId" \
  --output text 2>/dev/null)

for NGW_ID in $NGWS; do
  delete_resource "NAT Gateway: $NGW_ID" \
    "aws ec2 delete-nat-gateway --nat-gateway-id $NGW_ID --region $REGION"
done

# Wait for NAT Gateway to be deleted before deleting Elastic IPs
sleep 30

# 11. Delete Elastic IPs (associated with NAT Gateways)
echo ""
echo "=== STEP 11: Delete Elastic IPs ==="
EIP_ALLOC_IDS=$(aws ec2 describe-addresses \
  --region $REGION \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "Addresses[*].AllocationId" \
  --output text 2>/dev/null)

for ALLOC_ID in $EIP_ALLOC_IDS; do
  delete_resource "Elastic IP: $ALLOC_ID" \
    "aws ec2 release-address --allocation-id $ALLOC_ID --region $REGION"
done

# 12. Delete Route Tables
echo ""
echo "=== STEP 12: Delete Route Tables ==="
RT_IDS=$(aws ec2 describe-route-tables \
  --region $REGION \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "RouteTables[*].RouteTableId" \
  --output text)

for RT_ID in $RT_IDS; do
  # Skip main route table
  IS_MAIN=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $RT_ID \
    --query "RouteTables[0].Associations[?Main==\`true\`]" --output text)
  
  if [ -z "$IS_MAIN" ]; then
    delete_resource "Route Table: $RT_ID" \
      "aws ec2 delete-route-table --route-table-id $RT_ID --region $REGION"
  fi
done

# 13. Delete Network ACLs
echo ""
echo "=== STEP 13: Delete Network ACLs ==="
NACL_IDS=$(aws ec2 describe-network-acls \
  --region $REGION \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "NetworkAcls[*].NetworkAclId" \
  --output text)

for NACL_ID in $NACL_IDS; do
  delete_resource "Network ACL: $NACL_ID" \
    "aws ec2 delete-network-acl --network-acl-id $NACL_ID --region $REGION"
done

# 14. Delete VPCs
echo ""
echo "=== STEP 14: Delete VPCs ==="
VPC_IDS=$(aws ec2 describe-vpcs \
  --region $REGION \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" \
  --query "Vpcs[*].VpcId" \
  --output text)

for VPC_ID in $VPC_IDS; do
  delete_resource "VPC: $VPC_ID" \
    "aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION"
done

# 15. Delete Parameter Groups (RDS)
echo ""
echo "=== STEP 15: Delete RDS Parameter Groups ==="
PARAM_GROUPS=$(aws rds describe-db-parameter-groups \
  --region $REGION \
  --query "DBParameterGroups[?contains(DBParameterGroupName, '$PROJECT_NAME')].DBParameterGroupName" \
  --output text 2>/dev/null)

for PARAM_GROUP in $PARAM_GROUPS; do
  delete_resource "Parameter Group: $PARAM_GROUP" \
    "aws rds delete-db-parameter-group --db-parameter-group-name $PARAM_GROUP --region $REGION"
done

echo ""
echo "=========================================="
echo "✓ Resource deletion complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify resources are deleted in AWS Console"
echo "2. Run 'terragrunt run-all destroy' to clean up Terraform/OpenTofu state"
echo "3. Clear Terraform state files if needed"
