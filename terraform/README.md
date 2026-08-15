# Terraform — Marketing Digest AWS platform

Infrastructure as code for the **production** AWS bootstrap:

- 1× `t3.micro` EC2 — **Jenkins only** (CI)
- 1× `t3.medium` EC2 — **k3s + Argo CD + apps**
- Elastic IPs on both hosts (no ALB)
- RDS Postgres (`db.t3.micro`, private)
- ECR repos for `gateway`, `auth`, `blog`

All resources are tagged with `Project`, `Environment`, and `ManagedBy`.

**Region: `ap-south-1` (Mumbai).** Moving from another region is a **new stack** (new state bucket + recreate resources), not an in-place move.

**This directory does not run `terraform apply` for you.** Complete Phase 0–2 below, then apply from your laptop.

---

## Phase 0 — AWS account hygiene (Console)

Do this once as **root**, then stop using root day-to-day. Region: **`ap-south-1`**.

1. Confirm region **Mumbai (`ap-south-1`)** in the console header.
2. **Root security**
   - Enable MFA on the root user
   - Strong root password
   - Do **not** create access keys for root
3. **Billing guardrails**
   - Billing → Billing preferences → enable Free Tier usage alerts
   - Create a CloudWatch billing alarm (e.g. estimated charges > `$5`) to your email
   - Optional: AWS Budgets → monthly budget for free-tier awareness
4. **IAM admin user (human)**
   - Create user e.g. `yuvraj-admin`
   - Attach `AdministratorAccess` (bootstrap only; tighten later)
   - Console password + MFA
5. **IAM user for Terraform / CLI**
   - Create user e.g. `terraform-marketing-digest`
   - Attach a policy that allows at least:
     - VPC / EC2 / EIP
     - RDS
     - ECR
     - IAM roles & instance profiles (for the EC2 role)
     - S3 + DynamoDB (Terraform state)
     - Secrets Manager (DB password)
     - CloudWatch Logs / SSM (optional but recommended)
   - Create **one** access key; store it in a password manager — never commit it
6. Optional: enable CloudTrail (management events only).

Suggested managed policy for a fast start (still broad): `AdministratorAccess` on the Terraform user for the first apply, then replace with least privilege.

### One-time: RDS service-linked role

RDS needs `AWSServiceRoleForRDS`. The Terraform user often cannot create it.
As an **admin** user (or root), run once:

```bash
aws iam create-service-linked-role --aws-service-name rds.amazonaws.com
```

Or in IAM console: Roles → Create role → AWS service → RDS → create the service-linked role.
Then re-run `terraform apply`.

---

## Phase 1 — Local CLI

```bash
# AWS CLI v2 + Terraform >= 1.5
aws configure --profile marketing-digest
# Access key / secret from terraform-marketing-digest
# Default region: ap-south-1
# Default output: json

export AWS_PROFILE=marketing-digest
aws sts get-caller-identity
```

Optional: install the Session Manager plugin so you can reach the instance without opening SSH:

```bash
aws ssm start-session --target <instance-id> --region ap-south-1
```

---

## Phase 2 — Remote state (create once, outside main stack)

Terraform state must not live in git. Create these **once** with the CLI (or console), then fill `backend.hcl`.

```bash
export AWS_PROFILE=marketing-digest
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="marketing-digest-tfstate-${ACCOUNT_ID}-ap-south-1"
REGION=ap-south-1

# ap-south-1 requires LocationConstraint (use scripts/bootstrap-state.sh)
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging \
  'TagSet=[{Key=Project,Value=marketing-digest},{Key=Environment,Value=production},{Key=ManagedBy,Value=terraform}]'

aws dynamodb create-table \
  --table-name marketing-digest-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=marketing-digest Key=Environment,Value=production Key=ManagedBy,Value=terraform \
  --region "$REGION"
```

Copy the example backend config and set the bucket name:

```bash
cp backend.hcl.example backend.hcl
# edit bucket = "marketing-digest-tfstate-<account-id>"
```

`backend.hcl` is gitignored.

---

## Phase 3 — Plan / apply (this stack)

```bash
cd md-infra/terraform
export AWS_PROFILE=marketing-digest

# Set your public IP so Jenkins/SSH rules are locked down:
#   allowed_cidr = "x.x.x.x/32"
# in envs/production/terraform.tfvars (or pass -var)

terraform init -backend-config=backend.hcl
terraform plan  -var-file=envs/production/terraform.tfvars
terraform apply -var-file=envs/production/terraform.tfvars
```

### Outputs to save

- `jenkins_elastic_ip` / `jenkins_url` — Jenkins UI
- `cluster_elastic_ip` — gateway / public app entry
- `jenkins_instance_id` / `cluster_instance_id` — SSM targets
- `rds_endpoint` — Postgres host
- `ecr_repository_urls` — image push targets
- `ssm_jenkins_command` / `ssm_cluster_command`

### Smoke checks after apply

1. `terraform output ssm_jenkins_command` then open a session; `docker ps` should show Jenkins
2. `terraform output ssm_cluster_command`; `kubectl get nodes` and `kubectl -n argocd get pods`
3. From your laptop (IP allowlisted): Jenkins URL from `terraform output jenkins_url`
4. From the cluster host: connectivity to RDS on 5432
5. `aws ecr describe-repositories --region ap-south-1`

User-data: Jenkins host installs Docker + Jenkins + nginx (HTTP :80 reverse proxy to loopback :8080); cluster host installs k3s + Argo CD. First boot on the cluster can take several minutes while images pull.

Applying this stack **destroys the old all-in-one `t2.micro`** and replaces it with the two new instances.

---

## Tags

| Key | Production value |
|-----|------------------|
| `Project` | `marketing-digest` |
| `Environment` | `production` |
| `ManagedBy` | `terraform` |

Use `Environment=uat` later for a second stack; do not overload this production stack.

---

## Explicit non-goals (this stack)

EKS, ALB/NLB, NAT Gateway, Multi-AZ RDS, Argo CD on the Jenkins host.

---

## Layout

```text
terraform/
  README.md
  versions.tf
  providers.tf
  backend.tf
  backend.hcl.example
  variables.tf
  locals.tf
  main.tf
  outputs.tf
  envs/production/terraform.tfvars
  modules/
    network/
    compute/
    database/
    ecr/
  scripts/
    bootstrap-state.sh
```
