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
    values = ["al2023-ami-2023.*-arm64"]
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
  ami = data.aws_ami.al2023_arm64.id
  # t4g.small -> t4g.medium: AWS resizes an EC2 instance type via an internal
  # stop/start, not a resource replacement — Terraform should therefore show
  # this as an in-place "update" (instance ID unchanged), not a
  # destroy-and-recreate. Confirm the plan output actually shows "update
  # in-place" before applying; if it shows "forces replacement" instead,
  # something else in this diff (see user_data note below) is the cause, not
  # this line.
  instance_type               = "t4g.medium"
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

  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    deploy_script = file("${path.module}/scripts/deploy.sh")
  })

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
