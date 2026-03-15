resource "aws_db_instance" "default" {
  # storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  # engine
  engine         = var.engine
  engine_version = var.engine_version

  # instance
  instance_class = var.instance_class
  db_name        = var.db_name
  port           = var.port

  # credentials
  username                            = var.username
  manage_master_user_password         = true
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # network
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  # parameter group
  parameter_group_name = var.parameter_group_name

  # backups
  backup_retention_period  = var.retention_period
  backup_window            = var.backup_window
  backup_target            = var.backup_target
  copy_tags_to_snapshot    = var.copy_tags_to_snapshot
  delete_automated_backups = var.delete_automated_backups

  # snapshots
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.db_name
  snapshot_identifier       = var.snapshot_identifier

  # maintenance
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn

  # performance insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  # protection
  deletion_protection = var.deletion_protection

  # blue/green
  blue_green_update {
    enabled = var.blue_green_update_enabled
  }

  tags = {
    Name        = var.db_name
    environment = var.environment
  }
}

# ─── Subnet Group ────────────────────────────────
resource "aws_db_subnet_group" "default" {
  name        = "${var.db_name}-subnet-group"
  subnet_ids  = [data.aws_subnets.private.ids]
  description = "Subnet group for ${var.db_name}"

  tags = {
    Name        = "${var.db_name}-subnet-group"
    environment = var.environment
  }
}

# ─── Tier 3 — Cross Region Read Replica ──────────
resource "aws_db_instance" "dr_replica" {
  count = var.create_dr_replica ? 1 : 0

  identifier                 = "${var.db_name}-dr"
  replicate_source_db        = aws_db_instance.default.arn
  instance_class             = var.instance_class
  publicly_accessible        = false
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.db_name}-dr-final"
  backup_retention_period    = var.retention_period
  deletion_protection        = var.deletion_protection
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  maintenance_window         = var.maintenance_window

  # monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn

  # performance insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  tags = {
    Name        = "${var.db_name}-dr"
    environment = var.environment
    role        = "dr-replica"
  }

  provider = aws.dr # ← points to DR region
}

# ─── Cross Region Snapshot Copy ──────────────────
resource "aws_db_instance_automated_backups_replication" "dr" {
  count = var.enable_cross_region_backup ? 1 : 0

  source_db_instance_arn = aws_db_instance.default.arn
  retention_period       = var.retention_period
  kms_key_id             = var.dr_kms_key_id

  provider = aws.dr # ← copies backups to DR region
}