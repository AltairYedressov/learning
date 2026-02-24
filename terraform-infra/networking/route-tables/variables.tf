variable "vpc_id" {
  type        = string
  description = "VPC ID, required for subnets"
}

variable "igw_id" {
  type = string
}

variable "subnet_ids" {
  type        = map(string)
  description = "Map of subnet IDs keyed by subnet name"
}

variable "subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    public            = bool
  }))
}