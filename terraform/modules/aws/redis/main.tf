resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-redis"
  description = "Redis access for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-redis" })
}

resource "aws_vpc_security_group_ingress_rule" "cidrs" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"
  description       = "Redis from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "security_groups" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Redis from ${each.value}"
}

resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name}-redis"
  family = "redis${split(".", var.engine_version)[0]}"

  # The platform treats Redis as a cache plus a queue-coordination store. allkeys-lru
  # keeps it serving under memory pressure instead of returning OOM on write, which
  # surfaces as run failures rather than degraded caching.
  parameter {
    name  = "maxmemory-policy"
    value = var.maxmemory_policy
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_password" "auth_token" {
  count = var.transit_encryption_enabled ? 1 : 0

  length  = 48
  special = false
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Noxus platform Redis for ${var.name}"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters         = var.replica_count + 1
  automatic_failover_enabled = var.replica_count > 0
  multi_az_enabled           = var.replica_count > 0

  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.this.id]
  parameter_group_name = aws_elasticache_parameter_group.this.name

  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled ? random_password.auth_token[0].result : null

  snapshot_retention_limit = var.snapshot_retention_days
  maintenance_window       = var.maintenance_window
  apply_immediately        = var.apply_immediately

  tags = merge(var.tags, { Name = "${var.name}-redis" })

  lifecycle {
    ignore_changes = [auth_token]
  }
}
