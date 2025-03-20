output "rds_endpoint" {
  value       = aws_db_instance.postgres.endpoint
  description = "Database connection link"
}