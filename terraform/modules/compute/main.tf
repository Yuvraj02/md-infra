data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "ec2" {
  name = "${var.name_prefix}-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy" "secrets_read" {
  name = "${var.name_prefix}-secrets-read"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/rds/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2"
  role = aws_iam_role.ec2.name

  tags = var.tags
}

locals {
  jenkins_user_data = templatefile("${path.module}/user_data_jenkins.sh.tpl", {
    jenkins_http_port = var.jenkins_http_port
    project           = var.project
    environment       = var.environment
    aws_region        = data.aws_region.current.name
    aws_account_id    = data.aws_caller_identity.current.account_id
  })

  cluster_user_data = templatefile("${path.module}/user_data_cluster.sh.tpl", {
    project        = var.project
    environment    = var.environment
    aws_region     = data.aws_region.current.name
    aws_account_id = data.aws_caller_identity.current.account_id
  })
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.ci_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.jenkins_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data                   = local.jenkins_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins"
    Role = "ci"
  })
}

resource "aws_instance" "cluster" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.cluster_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.cluster_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data                   = local.cluster_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s"
    Role = "k3s"
  })
}

resource "aws_eip" "jenkins" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-eip"
    Role = "ci"
  })
}

resource "aws_eip_association" "jenkins" {
  instance_id   = aws_instance.jenkins.id
  allocation_id = aws_eip.jenkins.id
}

resource "aws_eip" "cluster" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster-eip"
    Role = "k3s"
  })
}

resource "aws_eip_association" "cluster" {
  instance_id   = aws_instance.cluster.id
  allocation_id = aws_eip.cluster.id
}
