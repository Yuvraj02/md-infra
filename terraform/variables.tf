variable "aws_region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile used by the provider"
  default     = "marketing-digest"
}

variable "project" {
  type        = string
  description = "Project tag value"
  default     = "marketing-digest"
}

variable "environment" {
  type        = string
  description = "Environment tag value (production | uat)"
  default     = "production"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC IPv4 CIDR"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR (EC2)"
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs for RDS (two AZs required by RDS subnet groups)"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "allowed_cidr" {
  type        = string
  description = "Your public IP as /32 for Jenkins UI (and optional SSH). Required for safe expose."
}

variable "enable_ssh" {
  type        = bool
  description = "Open TCP/22 from allowed_cidr. Prefer SSM (false) when possible."
  default     = false
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type (free tier: t2.micro)"
  default     = "t2.micro"
}

variable "jenkins_http_port" {
  type        = number
  description = "Host port published for Jenkins UI"
  default     = 8080
}

variable "gateway_http_port" {
  type        = number
  description = "Host/node port intended for the gateway HTTP listener"
  default     = 80
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class (free tier: db.t3.micro)"
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  type        = string
  description = "Postgres engine version"
  default     = "16"
}

variable "db_name" {
  type        = string
  description = "Initial Postgres database name"
  default     = "marketing_digest"
}

variable "db_username" {
  type        = string
  description = "Master username for RDS"
  default     = "md_admin"
}

variable "db_allocated_storage" {
  type        = number
  description = "RDS allocated storage in GB (free tier up to 20)"
  default     = 20
}

variable "ecr_repository_names" {
  type        = list(string)
  description = "ECR repository name suffixes under the project"
  default     = ["gateway", "auth", "blog"]
}
