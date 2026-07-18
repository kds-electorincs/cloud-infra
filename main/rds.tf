# main/rds.tf

# --- DB subnet group: spans both private subnets (AWS requires 2+ AZs) -----

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = "${var.project}-db-subnet-group"
    Project = "kds-electronics"
  }
}

# --- RDS PostgreSQL instance -------------------------------------------

resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = "18.4"

  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 7
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project}-db-final-snapshot"

  tags = {
    Name    = "${var.project}-db"
    Project = "kds-electronics"
  }
}
