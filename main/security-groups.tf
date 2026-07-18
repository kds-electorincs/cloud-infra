# main/security-groups.tf

# --- CloudFront managed prefix list (AWS-maintained, no manual updates) -----

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# --- Backend EC2 security group ---------------------------------------------

resource "aws_security_group" "backend_ec2" {
  name        = "${var.project}-backend-ec2"
  description = "Backend EC2: SSH from admin IP, HTTP from CloudFront only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-backend-ec2-sg"
    Project = "kds-electronics"
  }
}

resource "aws_security_group_rule" "backend_ssh" {
  security_group_id = aws_security_group.backend_ec2.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # TEMPORARY: open to all IPs due to mobile hotspot IP rotation during
  # the 2-4 week Phase 1 deployment window. Key-based auth only (no
  # password login), so brute-force login is not viable, but this still
  # exposes SSH to internet-wide scanning/probing traffic.
  # MUST be narrowed to a fixed IP/CIDR or replaced with SSM Session
  # Manager before final/production deployment. Decision made and
  # accepted knowingly on 2026-07-16 — see conversation history.
  description = "SSH open to all (TEMP, Phase 1 only)"
}

resource "aws_security_group_rule" "backend_http_from_cloudfront" {
  security_group_id = aws_security_group.backend_ec2.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  description       = "HTTP from CloudFront origin-facing IPs only"
}

resource "aws_security_group_rule" "backend_egress_all" {
  security_group_id = aws_security_group.backend_ec2.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound (RDS, S3, package repos, etc.)"
}

# --- RDS security group ------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds"
  description = "RDS: PostgreSQL access from backend EC2 only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-rds-sg"
    Project = "kds-electronics"
  }
}

resource "aws_security_group_rule" "rds_from_backend" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.backend_ec2.id
  description              = "PostgreSQL from backend EC2 SG only"
}