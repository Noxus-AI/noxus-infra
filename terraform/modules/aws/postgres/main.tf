resource "random_password" "root" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-postgres"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-postgres"
  description = "PostgreSQL access for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-postgres" })
}

resource "aws_vpc_security_group_ingress_rule" "cidrs" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "PostgreSQL from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "security_groups" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from ${each.value}"
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-postgres"
  family = "postgres${split(".", var.engine_version)[0]}"

  # RDS defaults max_connections to a value derived from instance memory that is far
  # below what the platform opens: every backend and worker pod holds its own pool
  # (POSTGRES_POOL_SIZE, default 64). Run PgBouncer as well — this only raises the
  # ceiling, it does not make per-pod pools cheap.
  parameter {
    name         = "max_connections"
    value        = "LEAST({DBInstanceClassMemory/9531392},5000)"
    apply_method = "pending-reboot"
  }

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"

  engine = "postgres"
  # pgvector ships with RDS PostgreSQL from 15.2 on; the migrations run
  # CREATE EXTENSION vector, so an older major will fail on first boot.
  engine_version              = var.engine_version
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_id

  multi_az = var.multi_az

  db_name  = var.initial_database
  username = var.username
  password = random_password.root.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  snapshot_identifier = var.snapshot_identifier

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name}-postgres-final" : null

  performance_insights_enabled = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]

  tags = merge(var.tags, { Name = "${var.name}-postgres" })

  lifecycle {
    # Password rotation is handled out of band; a plan should not offer to reset it.
    ignore_changes = [password]
  }
}
