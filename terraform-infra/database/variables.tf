variable "db_name" {
  type        = string
  description = "Database name"
}

variable "engine" {
  type        = string
  description = "Database engine type"
}

variable "engine_version" {
  type        = string
  description = "Database engine version"
}

variable "instance_class" {
  type        = string
  description = "Instance type of database"
}

variable "username" {
  type        = string
  description = "Username of database"
}

variable "manage_master_user_password" {
  type        = bool
  description = "Let AWS manage and rotate the master password automatically"
  default     = true
}

variable "retention_period" {
  type        = number
  description = "The days to retain backups for"
  default     = 14
}

variable "backup_target" {
  type        = string
  description = " Specifies where automated backups and manual snapshots are stored. Possible values are region (default) and outposts"
  default     = "region"
}

variable "backup_window" {
  type        = string
  description = "The daily time range (in UTC) during which automated backups are created if they are enabled"
  default     = "03:00-04:00"
}

variable "blue_green_update_enabled" {
  type        = bool
  description = "Enables low-downtime updates using RDS Blue/Green deployments"
  default     = false
}

variable "copy_tags_to_snapshot" {
  type        = bool
  description = "Copy all Instance tags to snapshots"
  default     = true
}

variable "delete_automated_backups" {
  type        = bool
  description = " Specifies whether to remove automated backups immediately after the DB instance is deleted"
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Protects database from accidental deletion"
  default     = false
}

variable "monitoring_interval" {
  type        = number
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance"
  default     = 60
}

variable "monitoring_role_arn" {
  type        = string
  description = "The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs."
  default     = null
}
variable "performance_insights_enabled" {
  type        = bool
  description = "Specifies whether Performance Insights are enabled"
  default     = true
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Amount of time in days to retain Performance Insights data. Valid values are 7, 731 (2 years) or a multiple of 31"
  default     = 7
}

variable "snapshot_identifier" {
  type        = string
  description = "Specifies whether or not to create this database from a snapshot"
  default     = null
}

variable "vpc_security_group_ids" {
  type        = string
  description = "List of VPC security groups to associate"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted."
  default     = false
}
variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage for autoscaling in GB"
  default     = 100
}

variable "storage_type" {
  type        = string
  description = "Storage type gp2, gp3, io1"
  default     = "gp3"
}

variable "storage_encrypted" {
  type        = bool
  description = "Enable storage encryption"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN for storage encryption"
  default     = null # uses AWS default key if null
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment for high availability"
  default     = false # true in prod
}

variable "publicly_accessible" {
  type        = bool
  description = "Make database publicly accessible"
  default     = false # always false in prod
}

variable "db_subnet_group_name" {
  type        = string
  description = "DB subnet group name - which subnets DB lives in"
  default     = null
}

variable "parameter_group_name" {
  type        = string
  description = "DB parameter group name"
  default     = null
}

variable "port" {
  type        = number
  description = "Database port"
  default     = 3306 # mysql default
}

variable "maintenance_window" {
  type        = string
  description = "Weekly maintenance window e.g. Mon:00:00-Mon:03:00"
  default     = "Mon:00:00-Mon:03:00"
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Enable automatic minor version upgrades"
  default     = true
}

variable "environment" {
  type        = string
  description = "Environment name e.g. dev, prod"
}

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Enable IAM database authentication instead of password"
  default     = false
}

# ─── Subnet Group ────────────────────────────────
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for DB subnet group"
}

# ─── DR Variables ────────────────────────────────
variable "create_dr_replica" {
  type        = bool
  description = "Create a cross-region read replica for disaster recovery"
  default     = false # enable in prod
}

variable "enable_cross_region_backup" {
  type        = bool
  description = "Replicate automated backups to DR region"
  default     = false # enable in prod
}

variable "dr_region" {
  type        = string
  description = "DR region for replica and backup replication"
  default     = "us-west-2"
}

variable "dr_kms_key_id" {
  type        = string
  description = "KMS key ARN in DR region for encrypted backup replication"
  default     = null
}

variable "vpc_cidr" {
  type        = string
  description = "VPC cidr range where database is deployed"
}

