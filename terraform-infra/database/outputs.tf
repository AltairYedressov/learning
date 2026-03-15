# terraform-infra/database/outputs.tf
output "db_endpoint" {
  value       = aws_db_instance.default.endpoint
  description = "Primary database endpoint"
}

output "db_port" {
  value       = aws_db_instance.default.port
  description = "Database port"
}

output "db_name" {
  value       = aws_db_instance.default.db_name
  description = "Database name"
}

output "db_arn" {
  value       = aws_db_instance.default.arn
  description = "Database ARN"
}

output "dr_replica_endpoint" {
  value       = var.create_dr_replica ? aws_db_instance.dr_replica[0].endpoint : null
  description = "DR replica endpoint - promote this if primary region fails"
}

output "subnet_group_name" {
  value       = aws_db_subnet_group.default.name
  description = "DB subnet group name"
}

output "db_secret_arn" {
  value       = aws_db_instance.default.master_user_secret[0].secret_arn
  description = "ARN of secret in Secrets Manager - app reads from here"
}