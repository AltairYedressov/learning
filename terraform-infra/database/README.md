# Database Module - RDS MySQL

This module creates an Amazon RDS MySQL database instance with production-ready defaults: encrypted storage, automated backups, IAM authentication, Performance Insights, and optional disaster recovery (cross-region read replica and backup replication). It places the database in private subnets so it is not accessible from the internet -- only resources inside the VPC (like your EKS worker nodes) can reach it.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Primary Region (us-east-1)                       │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                           VPC                                  │  │
│  │                                                                │  │
│  │   ┌──────────────────────────────────────────────────────┐     │  │
│  │   │              Private Subnets                          │     │  │
│  │   │                                                      │     │  │
│  │   │  ┌─────────────────────────────────────────────┐     │     │  │
│  │   │  │           RDS MySQL Instance                 │     │     │  │
│  │   │  │                                              │     │     │  │
│  │   │  │  Engine: MySQL 8.0                           │     │     │  │
│  │   │  │  Instance: db.t3.micro (dev)                 │     │     │  │
│  │   │  │  Port: 3306                                  │     │     │  │
│  │   │  │  Storage: gp3, encrypted (AES256)            │     │     │  │
│  │   │  │  Autoscaling: 20GB -> 100GB                  │     │     │  │
│  │   │  │  Multi-AZ: OFF (dev) / ON (prod)             │     │     │  │
│  │   │  │  Password: AWS Secrets Manager (auto-rotate) │     │     │  │
│  │   │  │  IAM Auth: Enabled                           │     │     │  │
│  │   │  │  Backups: 14-day retention                   │     │     │  │
│  │   │  │  Security Group: database-sg (port 3306)     │     │     │  │
│  │   │  └─────────────────────────────────────────────┘     │     │  │
│  │   │                                                      │     │  │
│  │   │  ┌─────────────────────────────────────────────┐     │     │  │
│  │   │  │        DB Subnet Group                       │     │     │  │
│  │   │  │  (groups private subnets for RDS)            │     │     │  │
│  │   │  └─────────────────────────────────────────────┘     │     │  │
│  │   └──────────────────────────────────────────────────────┘     │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                    Backups (14 days)                                  │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
              (optional, for prod)
                               │
┌──────────────────────────────┼───────────────────────────────────────┐
│                     DR Region (us-west-2)                            │
│                                                                      │
│  ┌───────────────────────────┐  ┌────────────────────────────────┐  │
│  │ Cross-Region Read Replica │  │ Cross-Region Backup Copy       │  │
│  │ (Tier 3 DR)               │  │ (Tier 2 DR)                    │  │
│  │                           │  │                                │  │
│  │ Promote to primary if     │  │ Automated backup replication   │  │
│  │ us-east-1 fails           │  │ with KMS encryption            │  │
│  └───────────────────────────┘  └────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## File Descriptions

| File | Purpose |
|------|---------|
| `main.tf` | Creates three resources: (1) the primary RDS instance with all configuration options (storage, engine, networking, backups, monitoring, encryption, blue/green updates), (2) a DB subnet group that places the database in private subnets, and (3) optional DR resources -- a cross-region read replica and cross-region automated backup replication. |
| `variables.tf` | Declares all input variables (30+ variables) with sensible defaults. Covers storage, engine, networking, backups, monitoring, DR, and more. |
| `outputs.tf` | Exports the database endpoint, port, name, ARN, DR replica endpoint, subnet group name, and the Secrets Manager ARN where the master password is stored. |
| `data-blocks.tf` | Looks up the VPC (by CIDR), private subnets (by `Type=private` tag), and the `database-sg` security group. These are resources created by the networking module. |

## Resources Created

1. **`aws_db_instance.default`** - The primary MySQL database instance.
2. **`aws_db_subnet_group.default`** - Groups the private subnets together so RDS knows where to place the database.
3. **`aws_db_instance.dr_replica`** (optional) - A cross-region read replica in us-west-2 for disaster recovery. Only created when `create_dr_replica = true`.
4. **`aws_db_instance_automated_backups_replication.dr`** (optional) - Replicates automated backups to the DR region. Only created when `enable_cross_region_backup = true`.

## Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| **Core** | | | | |
| `db_name` | `string` | Yes | - | Database name. |
| `engine` | `string` | Yes | - | Database engine (e.g., `mysql`). |
| `engine_version` | `string` | Yes | - | Engine version (e.g., `8.0`). |
| `instance_class` | `string` | Yes | - | Instance type (e.g., `db.t3.micro`). |
| `username` | `string` | Yes | - | Master username. |
| `environment` | `string` | Yes | - | Environment name for tagging. |
| `port` | `number` | No | `3306` | Database port. |
| **Storage** | | | | |
| `allocated_storage` | `number` | No | `20` | Initial storage in GB. |
| `max_allocated_storage` | `number` | No | `100` | Max storage for autoscaling in GB. |
| `storage_type` | `string` | No | `"gp3"` | Storage type: `gp2`, `gp3`, or `io1`. |
| `storage_encrypted` | `bool` | No | `true` | Enable storage encryption. |
| `kms_key_id` | `string` | No | `null` | KMS key for encryption. Uses AWS default if null. |
| **Networking** | | | | |
| `vpc_cidr` | `string` | Yes | - | VPC CIDR, used to look up the VPC. |
| `subnet_ids` | `list(string)` | Yes | - | Subnet IDs for the DB subnet group. |
| `vpc_security_group_ids` | `string` | Yes | - | Security group ID for the database. |
| `publicly_accessible` | `bool` | No | `false` | Make database accessible from the internet (always `false` in prod). |
| `multi_az` | `bool` | No | `false` | Deploy a standby in another AZ for high availability. |
| `db_subnet_group_name` | `string` | No | `null` | Existing subnet group name (module creates one if null). |
| `parameter_group_name` | `string` | No | `null` | Custom parameter group name. |
| **Authentication** | | | | |
| `manage_master_user_password` | `bool` | No | `true` | Let AWS manage and auto-rotate the master password via Secrets Manager. |
| `iam_database_authentication_enabled` | `bool` | No | `true` | Enable IAM database authentication (connect with IAM role instead of password). |
| **Backups** | | | | |
| `retention_period` | `number` | No | `14` | Days to retain automated backups. |
| `backup_window` | `string` | No | `"03:00-04:00"` | Daily UTC time window for automated backups. |
| `backup_target` | `string` | No | `"region"` | Where to store backups: `region` or `outposts`. |
| `copy_tags_to_snapshot` | `bool` | No | `true` | Copy instance tags to snapshots. |
| `delete_automated_backups` | `bool` | No | `false` | Delete automated backups when DB is deleted. |
| `skip_final_snapshot` | `bool` | No | `false` | Skip the final snapshot when deleting. Set `false` for production. |
| `snapshot_identifier` | `string` | No | `null` | Restore from an existing snapshot. |
| **Maintenance** | | | | |
| `maintenance_window` | `string` | No | `"Mon:00:00-Mon:03:00"` | Weekly maintenance window. |
| `auto_minor_version_upgrade` | `bool` | No | `true` | Automatically upgrade minor versions. |
| **Monitoring** | | | | |
| `monitoring_interval` | `number` | No | `60` | Enhanced monitoring interval in seconds. |
| `monitoring_role_arn` | `string` | No | `null` | IAM role ARN for enhanced monitoring. |
| `performance_insights_enabled` | `bool` | No | `true` | Enable Performance Insights. |
| `performance_insights_retention_period` | `number` | No | `null` | Days to retain Performance Insights data. |
| **Protection** | | | | |
| `deletion_protection` | `bool` | No | `false` | Prevent accidental deletion. |
| `blue_green_update_enabled` | `bool` | No | `false` | Enable RDS Blue/Green deployments for low-downtime updates. |
| **Disaster Recovery** | | | | |
| `create_dr_replica` | `bool` | No | `false` | Create a cross-region read replica. |
| `enable_cross_region_backup` | `bool` | No | `false` | Replicate backups to the DR region. |
| `dr_region` | `string` | No | `"us-west-2"` | DR region for replica and backup replication. |
| `dr_kms_key_id` | `string` | No | `null` | KMS key in DR region for encrypted backups. |

## Outputs

| Output | Description |
|--------|-------------|
| `db_endpoint` | Primary database connection endpoint (hostname:port). |
| `db_port` | Database port number. |
| `db_name` | Database name. |
| `db_arn` | ARN of the database instance. |
| `dr_replica_endpoint` | DR replica endpoint (null if DR replica is not created). |
| `subnet_group_name` | Name of the DB subnet group. |
| `db_secret_arn` | ARN of the Secrets Manager secret containing the master password. Applications read credentials from here. |

## Dependency Chain

```
Networking module (must exist first)
    │
    ├── VPC           (looked up by CIDR in data-blocks.tf)
    ├── Private subnets (looked up by Type=private tag)
    └── database-sg    (looked up by name)
            │
            └── This module creates:
                    │
                    ├── DB Subnet Group (uses private subnets)
                    │       │
                    │       └── RDS Instance (uses subnet group + security group)
                    │               │
                    │               ├── (optional) DR Read Replica in us-west-2
                    │               └── (optional) Backup Replication to us-west-2
                    │
                    └── Secrets Manager (auto-created by AWS for master password)
```

## Disaster Recovery Tiers

The module supports three tiers of disaster recovery, progressively increasing protection:

| Tier | Feature | Dev | Prod | Description |
|------|---------|-----|------|-------------|
| 1 | Multi-AZ + Backups + Final Snapshot + Deletion Protection | Partial | Full | Basic HA and backup protection. |
| 2 | Cross-Region Backup Replication | OFF | ON | Copies automated backups to us-west-2. |
| 3 | Cross-Region Read Replica | OFF | ON | A live replica in us-west-2 that can be promoted to primary. |

## Usage Example

```hcl
module "rds" {
  source = "../../../database"

  providers = {
    aws    = aws
    aws.dr = aws.dr    # DR region provider (us-west-2)
  }

  vpc_cidr               = "10.0.0.0/16"
  db_name                = "myapp_db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "admin"
  environment            = "dev"
  subnet_ids             = data.aws_subnets.private.ids
  vpc_security_group_ids = data.aws_security_group.database_sg.id

  # DR settings -- flip these on for production
  multi_az                   = false
  create_dr_replica          = false
  enable_cross_region_backup = false
}
```

## Key Concepts for Beginners

- **RDS (Relational Database Service)**: AWS's managed database service. AWS handles patching, backups, and hardware -- you just use the database.
- **Multi-AZ**: RDS maintains a synchronous standby copy in a different Availability Zone. If the primary fails, AWS automatically fails over to the standby. Doubles the cost but provides high availability.
- **DB Subnet Group**: Tells RDS which subnets it can use. The database is placed in private subnets so it cannot be reached from the internet.
- **Secrets Manager**: AWS stores and automatically rotates the master password. Your application reads the password from Secrets Manager at runtime -- no hardcoded credentials.
- **IAM Database Authentication**: Instead of using a password, your application (running with an IAM role) generates a temporary authentication token. More secure than passwords.
- **Blue/Green Deployment**: RDS creates a "green" copy of your database, applies changes (like engine upgrades), and then switches traffic from "blue" (old) to "green" (new) with minimal downtime.
- **Read Replica**: A read-only copy of your database. The cross-region replica in this module serves as a DR target -- if the primary region goes down, you promote the replica to become the new primary.
- **gp3 Storage**: The latest generation of SSD storage for RDS. Cheaper than gp2 with configurable IOPS and throughput.
