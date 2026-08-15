output "jenkins_elastic_ip" {
  description = "Public Elastic IP for Jenkins UI"
  value       = module.compute.jenkins_elastic_ip
}

output "jenkins_instance_id" {
  description = "Jenkins EC2 instance id"
  value       = module.compute.jenkins_instance_id
}

output "cluster_elastic_ip" {
  description = "Public Elastic IP for gateway / cluster"
  value       = module.compute.cluster_elastic_ip
}

output "cluster_instance_id" {
  description = "k3s + Argo CD EC2 instance id"
  value       = module.compute.cluster_instance_id
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
  description = "Map of short name to ECR repository URL"
  value       = module.ecr.repository_urls
}

output "ssm_jenkins_command" {
  description = "SSM session to Jenkins host"
  value       = "aws ssm start-session --target ${module.compute.jenkins_instance_id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "ssm_cluster_command" {
  description = "SSM session to k3s / Argo CD host"
  value       = "aws ssm start-session --target ${module.compute.cluster_instance_id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "jenkins_url" {
  description = "Jenkins UI via nginx on :80 (allowlisted to allowed_cidr)"
  value       = "http://${module.compute.jenkins_elastic_ip}"
}
