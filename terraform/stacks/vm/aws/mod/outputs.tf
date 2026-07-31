output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "postgres_endpoint" {
  description = "PostgreSQL instance endpoint"
  value       = var.deploy_postgres ? aws_db_instance.postgresql_instance[0].endpoint : null
}

output "postgres_password" {
  description = "PostgreSQL root password"
  value       = random_password.postgres_root_password.result
  sensitive   = true
}
