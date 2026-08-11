# Remote state — configure via:
#   terraform init -backend-config=backend.hcl
# Copy backend.hcl.example → backend.hcl (gitignored) or run scripts/bootstrap-state.sh
terraform {
  backend "s3" {}
}
