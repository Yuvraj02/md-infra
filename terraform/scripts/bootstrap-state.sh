#!/usr/bin/env bash
# One-time remote state bootstrap for Marketing Digest Terraform.
# Usage: AWS_PROFILE=marketing-digest AWS_REGION=ap-south-1 ./scripts/bootstrap-state.sh
set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="marketing-digest-tfstate-${ACCOUNT_ID}-${REGION}"
TABLE="marketing-digest-tf-locks"

echo "Account: ${ACCOUNT_ID}"
echo "Bucket:  ${BUCKET}"
echo "Table:   ${TABLE}"
echo "Region:  ${REGION}"

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "S3 bucket already exists"
else
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

aws s3api put-bucket-tagging --bucket "${BUCKET}" --tagging \
  'TagSet=[{Key=Project,Value=marketing-digest},{Key=Environment,Value=production},{Key=ManagedBy,Value=terraform}]'

if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "DynamoDB table already exists"
else
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Project,Value=marketing-digest Key=Environment,Value=production Key=ManagedBy,Value=terraform \
    --region "${REGION}"
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

cat > "$(dirname "$0")/../backend.hcl" <<EOF
bucket         = "${BUCKET}"
key            = "production/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${TABLE}"
encrypt        = true
EOF

echo "Wrote backend.hcl — run: terraform init -reconfigure -backend-config=backend.hcl"
