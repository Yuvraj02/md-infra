output "elastic_ip" {
  description = "Public Elastic IP for Jenkins and gateway"
  value       = module.compute.elastic_ip
}

output "instance_id" {
  description = "EC2 instance id (SSM / console)"
  value       = module.compute.instance_id
}

output "instance_private_ip" {
  value = module.compute.private_ip
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "rds_endpoint" {
  description = "RDS Postgres hostname"
  value       = module.database.endpoint
}

output "rds_port" {
  value = module.database.port
}

output "rds_db_name" {
  value = module.database.db_name
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN for master DB credentials"
  value       = module.database.secret_arn
}

output "ecr_repository_urls" {
  description = "Map of short name → ECR repository URL"
  value       = module.ecr.repository_urls
}

output "ssm_start_session_command" {
  description = "Copy-paste SSM session command"
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "jenkins_url" {
  description = "Jenkins UI (allowlisted to allowed_cidr)"
  value       = "http://${module.compute.elastic_ip}:${var.jenkins_http_port}"
}
