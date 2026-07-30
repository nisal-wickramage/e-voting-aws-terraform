#!/bin/bash

# Script to check if AWS resources already exist
# Usage: ./check-existing-resources.sh [region]

REGION="${1:-us-east-1}"
PROJECT_NAME="e-voting"
ENVIRONMENT="dev"

echo "=========================================="
echo "Checking for existing AWS resources"
echo "Region: $REGION"
echo "=========================================="
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if resource exists
check_resource() {
  local resource_type=$1
  local resource_name=$2
  local command=$3
  
  echo -n "Checking for $resource_type: $resource_name ... "
  
  result=$(eval "$command" 2>&1)
  
  if echo "$result" | grep -q "does not exist\|ResourceNotFoundException\|not found"; then
    echo -e "${GREEN}NOT FOUND${NC}"
    return 1
  elif echo "$result" | grep -q "$resource_name"; then
    echo -e "${RED}EXISTS${NC}"
    echo "  Details: $result" | head -n 3
    return 0
  else
    echo -e "${YELLOW}UNKNOWN${NC}"
    return 2
  fi
}

echo "--- LOAD BALANCERS ---"
aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[?LoadBalancerName=='${PROJECT_NAME}-alb']" \
  --output table

echo ""
echo "--- TARGET GROUPS ---"
aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?TargetGroupName=='${PROJECT_NAME}-default-tg']" \
  --output table

echo ""
echo "--- CLOUDWATCH LOG GROUPS ---"
aws logs describe-log-groups \
  --region $REGION \
  --log-group-name-prefix "/ecs/${PROJECT_NAME}-cluster" \
  --output table

echo ""
echo "--- ECS CLUSTERS ---"
aws ecs list-clusters \
  --region $REGION \
  --output json | grep -i "${PROJECT_NAME}-cluster" && echo "ECS Cluster found" || echo "ECS Cluster not found"

echo ""
echo "--- SECURITY GROUPS ---"
aws ec2 describe-security-groups \
  --region $REGION \
  --filters "Name=group-name,Values=${PROJECT_NAME}-alb-sg,${PROJECT_NAME}-ecs-sg" \
  --query "SecurityGroups[*].[GroupId,GroupName]" \
  --output table

echo ""
echo "--- SUBNETS ---"
aws ec2 describe-subnets \
  --region $REGION \
  --query "Subnets[?Tags[?Key=='Name' && contains(Value, '${PROJECT_NAME}')]].[SubnetId,Tags[0].Value]" \
  --output table

echo ""
echo "--- VPC ---"
aws ec2 describe-vpcs \
  --region $REGION \
  --query "Vpcs[?Tags[?Key=='Name' && contains(Value, '${PROJECT_NAME}')]].[VpcId,Tags[0].Value]" \
  --output table

echo ""
echo "--- RDS INSTANCES ---"
aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?contains(DBInstanceIdentifier, '${PROJECT_NAME}')].[DBInstanceIdentifier,DBInstanceStatus]" \
  --output table

echo ""
echo "--- ECR REPOSITORIES ---"
aws ecr describe-repositories \
  --region $REGION \
  --query "repositories[?contains(repositoryName, '${PROJECT_NAME}')].[repositoryName,repositoryUri]" \
  --output table 2>/dev/null || echo "No ECR repositories found"

echo ""
echo "--- S3 BUCKETS ---"
aws s3 ls --region $REGION | grep -i "$PROJECT_NAME" || echo "No S3 buckets found with $PROJECT_NAME"

echo ""
echo "--- CLOUDFRONT DISTRIBUTIONS ---"
aws cloudfront list-distributions \
  --query "DistributionList.Items[?contains(Comment, '${PROJECT_NAME}')].[DomainName,Id,Comment,Enabled]" \
  --output table 2>/dev/null || echo "No CloudFront distributions found"

echo ""
echo "--- CLOUDFRONT ORIGIN ACCESS IDENTITIES ---"
aws cloudfront list-cloud-front-origin-access-identities \
  --query "CloudFrontOriginAccessIdentityList.Items[*].[Id,Comment]" \
  --output table 2>/dev/null || echo "No CloudFront OAIs found"

echo ""
echo "--- WAF WEB ACLs ---"
aws wafv2 list-web-acls \
  --region $REGION \
  --scope CLOUDFRONT \
  --query "WebACLs[?contains(Name, '${PROJECT_NAME}')].[Name,Id,ARN]" \
  --output table 2>/dev/null || echo "No WAF Web ACLs found"

echo ""
echo "--- SNS TOPICS ---"
aws sns list-topics \
  --region $REGION \
  --query "Topics[?contains(TopicArn, '${PROJECT_NAME}')].[TopicArn]" \
  --output table 2>/dev/null || echo "No SNS topics found"

echo ""
echo "--- SQS QUEUES ---"
aws sqs list-queues \
  --region $REGION \
  --query "QueueUrls[?contains(@, '${PROJECT_NAME}')]" \
  --output text 2>/dev/null || echo "No SQS queues found"

echo ""
echo "--- ROUTE53 HOSTED ZONES ---"
aws route53 list-hosted-zones-by-name \
  --query "HostedZones[?contains(Name, '${PROJECT_NAME}')].[Name,Id]" \
  --output table 2>/dev/null || echo "No Route53 hosted zones found"

echo ""
echo "--- IAM ROLES ---"
aws iam list-roles \
  --query "Roles[?contains(RoleName, '${PROJECT_NAME}')].[RoleName,Arn]" \
  --output table 2>/dev/null || echo "No IAM roles found"

echo ""
echo "--- SECRETS MANAGER SECRETS ---"
aws secretsmanager list-secrets \
  --region $REGION \
  --query "SecretList[?contains(Name, '${PROJECT_NAME}')].[Name,ARN]" \
  --output table 2>/dev/null || echo "No Secrets Manager secrets found"

echo ""
echo "--- CLOUDWATCH ALARMS ---"
aws cloudwatch describe-alarms \
  --region $REGION \
  --query "MetricAlarms[?contains(AlarmName, '${PROJECT_NAME}')].[AlarmName,StateValue]" \
  --output table 2>/dev/null || echo "No CloudWatch alarms found"

echo ""
echo "=========================================="
echo "Resource check complete"
echo "=========================================="
