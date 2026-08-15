variable "name_prefix" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "jenkins_security_group_id" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "ci_instance_type" {
  type = string
}

variable "cluster_instance_type" {
  type = string
}

variable "jenkins_http_port" {
  type = number
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
