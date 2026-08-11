# Production values for Marketing Digest free-tier bootstrap.
# Replace allowed_cidr with your public IP before apply:
#   curl -s https://checkip.amazonaws.com

aws_region  = "us-east-1"
aws_profile = "marketing-digest"

project     = "marketing-digest"
environment = "production"

# REQUIRED: lock Jenkins (and optional SSH) to your IP
allowed_cidr = "49.207.204.89/32" # replace with x.x.x.x/32 before real use

enable_ssh        = false
instance_type     = "t2.micro"
jenkins_http_port = 8080
gateway_http_port = 80

db_instance_class    = "db.t3.micro"
db_engine_version    = "16"
db_name              = "marketing_digest"
db_username          = "md_admin"
db_allocated_storage = 20

ecr_repository_names = ["gateway", "auth", "blog"]
