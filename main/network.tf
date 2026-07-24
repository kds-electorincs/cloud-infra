# main/network.tf

# --- VPC ----------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/20"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project}-vpc"
    Project = "kds-electronics"
  }
}

# --- Internet gateway -----------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-igw"
    Project = "kds-electronics"
  }
}

# --- Public subnet (backend EC2) -------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false # Elastic IP assigned explicitly at the EC2 stage, not auto-assign

  tags = {
    Name    = "${var.project}-public-1a"
    Project = "kds-electronics"
    Tier    = "public"
  }
}

# --- Private subnets (RDS) --------------------------------------------------
# Two AZs required: AWS DB subnet groups need at least 2 AZs even for
# single-AZ RDS deployments. Only 1a will actually host the RDS instance.

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/28"
  availability_zone = "${var.region}a"

  tags = {
    Name    = "${var.project}-private-1a"
    Project = "kds-electronics"
    Tier    = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/28"
  availability_zone = "${var.region}b"

  tags = {
    Name    = "${var.project}-private-1b"
    Project = "kds-electronics"
    Tier    = "private"
  }
}

# --- Public route table: default route via IGW -----------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-public-rt"
    Project = "kds-electronics"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Private route table: local only, no internet route --------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-private-rt"
    Project = "kds-electronics"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
