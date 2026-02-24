vpc_cidr     = "10.0.0.0/16"
project_name = "projectx"
environment  = "dev"

subnets = {
  public-1 = {
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    public            = true
  }

  public-2 = {
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    public            = true
  }

  private-1 = {
    cidr_block        = "10.0.101.0/24"
    availability_zone = "us-east-1a"
    public            = false
  }

  private-2 = {
    cidr_block        = "10.0.102.0/24"
    availability_zone = "us-east-1b"
    public            = false
  }
}