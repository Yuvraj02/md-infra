module "network" {
  source = "./modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  allowed_cidr         = var.allowed_cidr
  enable_ssh           = var.enable_ssh
  jenkins_http_port    = var.jenkins_http_port
  gateway_http_port    = var.gateway_http_port
  tags                 = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  name_prefix       = local.name_prefix
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.ec2_security_group_id
  instance_type     = var.instance_type
  jenkins_http_port = var.jenkins_http_port
  project           = var.project
  environment       = var.environment
  tags              = local.common_tags
}

module "database" {
  source = "./modules/database"

  name_prefix       = local.name_prefix
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.rds_security_group_id
  instance_class    = var.db_instance_class
  engine_version    = var.db_engine_version
  db_name           = var.db_name
  username          = var.db_username
  allocated_storage = var.db_allocated_storage
  tags              = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  project          = var.project
  repository_names = var.ecr_repository_names
  tags             = local.common_tags
}
