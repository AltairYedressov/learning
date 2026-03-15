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