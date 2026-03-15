data "aws_vpc" "projectx" {
  cidr_block = var.vpc_cidr
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Type"
    values = ["private"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.projectx.id]
  }
}

data "aws_security_group" "database_sg" {
  filter {
    name   = "group-name"
    values = ["database-sg"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.projectx.id]
  }
}