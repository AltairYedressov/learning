# terraform-infra/root/dev/rds/main.tf
module "rds" {
  source = "../../../database"

  vpc_cidr = var.vpc_cidr

  db_name        = var.db_name
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  username       = var.db_username
  environment    = var.environment
  subnet_ids     = data.terraform_remote_state.networking.outputs.private_subnet_ids
  vpc_security_group_ids = [data.terraform_remote_state.networking.outputs.rds_sg_id]

  # tier 1 - always on
  multi_az                = false   # true in prod
  retention_period = 14
  skip_final_snapshot     = false
  deletion_protection     = true

  # tier 3 - off in dev, on in prod
  create_dr_replica          = false
  enable_cross_region_backup = false
}

# DR region provider
provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}


## DR Tier Summary in Your Code

# Tier 1 — always enabled
#   multi_az                 = true/false
#   backup_retention_period  = 14
#   skip_final_snapshot      = false
#   deletion_protection      = true

# Tier 2 — cross region backups
#   enable_cross_region_backup = true   ← flip this on in prod

# Tier 3 — read replica in DR region
#   create_dr_replica = true            ← flip this on in prod