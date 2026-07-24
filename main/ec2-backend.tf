# main/ec2-backend.tf

# --- SSH key pair -------------------------------------------------------
# Public key only. Private key stays on the admin's machine, never in
# Terraform state beyond this public half.

resource "aws_key_pair" "backend" {
  key_name   = "${var.project}-backend-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3m6xW+qZApK3KTt04BaAc8+S+Ym9MSQWWZ9WSFRIOl kds-backend"

  tags = {
    Project = "kds-electronics"
  }
}

# --- AMI lookup: latest Amazon Linux 2023, arm64 (Graviton/t4g) -------------

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Instance profile: attaches the existing backend IAM role to EC2 -------

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project}-backend"
  role = aws_iam_role.backend.name
}

# --- Backend EC2 instance ----------------------------------------------

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.al2023_arm64.id
  instance_type               = "t4g.small"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.backend_ec2.id]
  key_name                    = aws_key_pair.backend.key_name
  iam_instance_profile        = aws_iam_instance_profile.backend.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # --- Java 25 via Amazon Corretto ---------------------------------------
    rpm --import https://yum.corretto.aws/corretto.key
    curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
    dnf install -y java-25-amazon-corretto-devel

    # --- nginx ---------------------------------------------------------------
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # --- systemd unit for the backend jar (jar deployed separately) --------
    mkdir -p /opt/kds/backend
    cat > /etc/systemd/system/kds-backend.service <<'UNIT'
    [Unit]
    Description=KDS backend Spring Boot service
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/kds/backend
    ExecStart=/usr/bin/java -jar /opt/kds/backend/app.jar
    Restart=always
    User=ec2-user

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    # Not starting kds-backend yet — jar isn't deployed until a manual step.
  EOF

  tags = {
    Name    = "${var.project}-backend"
    Project = "kds-electronics"
  }
}

# --- Elastic IP -----------------------------------------------------------

resource "aws_eip" "backend" {
  instance = aws_instance.backend.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project}-backend-eip"
    Project = "kds-electronics"
  }
}
