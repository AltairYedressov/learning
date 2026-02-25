variable "vpc_id" {
  type        = string
  description = "VPC ID, required for subnets"
}

variable "environment" {
  type = string
}

variable "subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    public            = bool
  }))
}