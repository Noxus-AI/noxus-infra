resource "random_password" "postgres_root_password" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "aws_db_subnet_group" "postgres" {
  count       = var.deploy_postgres ? 1 : 0
  name        = "${local.name_prefix}-postgres-subnet-group"
  subnet_ids  = module.vpc.private_subnets
  description = "Subnet group for PostgreSQL RDS instance"
}

resource "aws_security_group" "postgres" {
  count       = var.deploy_postgres ? 1 : 0
  name        = "${local.name_prefix}-postgres-sg"
  description = "Security group for PostgreSQL RDS instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-postgres-sg"
  }
}

resource "aws_db_parameter_group" "postgres" {
  count  = var.deploy_postgres ? 1 : 0
  family = "postgres15"
  name   = "${local.name_prefix}-postgres-params"

  parameter {
    apply_method = "pending-reboot"
    name         = "max_connections"
    value        = "LEAST({DBInstanceClassMemory/9531392},5000)"
  }
}

resource "aws_db_instance" "postgresql_instance" {
  count             = var.deploy_postgres ? 1 : 0
  identifier        = "${local.name_prefix}-noxus-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.postgres_instance_class
  allocated_storage = 100
  storage_type      = "gp3"

  # If snapshot_identifier is provided, don't set the initial database name
  db_name  = var.snapshot_identifier == null ? "spot" : null
  username = "postgres"
  password = random_password.postgres_root_password.result

  # Restore from snapshot if provided
  snapshot_identifier = var.snapshot_identifier

  db_subnet_group_name   = aws_db_subnet_group.postgres[0].name
  vpc_security_group_ids = [aws_security_group.postgres[0].id]
  parameter_group_name   = aws_db_parameter_group.postgres[0].name

  skip_final_snapshot = true
  deletion_protection = false

  backup_window      = "22:00-23:00"
  maintenance_window = "Mon:23:00-Mon:23:30"

  multi_az            = false
  publicly_accessible = false

  # Allow password changes when restoring from snapshot
  lifecycle {
    ignore_changes = [snapshot_identifier]
  }

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
