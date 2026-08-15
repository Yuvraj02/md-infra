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

# Kept for module API compatibility; Jenkins UI is exposed on :80 via nginx.
# The container still listens on this port on loopback only.
variable "jenkins_http_port" {
  type        = number
  description = "Legacy Jenkins container port (not opened on the SG; nginx uses :80)"
  default     = 8080
}

variable "gateway_http_port" {
  type = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
