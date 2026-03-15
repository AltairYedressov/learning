variable "vpc_cidr" {
  type        = string
  description = "VPC cidr range where database is deployed"
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Username of database"
}

variable "environment" {
  type = string
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "List of sg"
}