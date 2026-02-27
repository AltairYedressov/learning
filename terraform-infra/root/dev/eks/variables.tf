variable "cluster_name" {
  type = string
}

variable "k8s_version" {
  type    = string
  default = "1.34"
}

variable "environment" {
  type = string
}
variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}