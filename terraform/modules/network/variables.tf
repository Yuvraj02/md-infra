variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "allowed_cidr" {
  type = string
}

variable "enable_ssh" {
  type = bool
}

variable "jenkins_http_port" {
  type = number
}

variable "gateway_http_port" {
  type = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
