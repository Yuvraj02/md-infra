output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "jenkins_security_group_id" {
  value = aws_security_group.jenkins.id
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
