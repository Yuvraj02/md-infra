output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "jenkins_private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "jenkins_elastic_ip" {
  value = aws_eip.jenkins.public_ip
}

output "cluster_instance_id" {
  value = aws_instance.cluster.id
}

output "cluster_private_ip" {
  value = aws_instance.cluster.private_ip
}

output "cluster_elastic_ip" {
  value = aws_eip.cluster.public_ip
}

output "instance_role_arn" {
  value = aws_iam_role.ec2.arn
}
