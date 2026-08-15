# Production values for Marketing Digest.
# Replace allowed_cidr with your public IP before apply:
#   curl -s https://checkip.amazonaws.com

aws_region  = "ap-south-1"
aws_profile = "marketing-digest"

project     = "marketing-digest"
environment = "production"

# Jenkins UI is public on :80 (nginx). Rely on Jenkins login; prefer HTTPS later.
allowed_cidr = "0.0.0.0/0"

enable_ssh            = false
ci_instance_type      = "t3.micro"
cluster_instance_type = "t3.medium"
jenkins_http_port     = 8080
gateway_http_port     = 80

db_instance_class    = "db.t3.micro"
db_engine_version    = "16"
db_name              = "marketing_digest"
db_username          = "md_admin"
db_allocated_storage = 20

ecr_repository_names = ["gateway", "auth", "blog"]
