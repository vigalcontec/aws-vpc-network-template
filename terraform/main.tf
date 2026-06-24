# =============================================================================
# AWS VPC Network - Production Ready Template
# =============================================================================
# This template creates a multi-AZ VPC with:
# - Public subnets (NAT Gateway, ALB, Bastion)
# - Private subnets (Lambda, ECS, App servers)
# - Database subnets (Aurora, RDS - isolated)
# - VPC Flow Logs for security monitoring
# - VPC Endpoints for AWS services (cost optimization)

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = local.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# VPC
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = local.current_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.full_name
  }
}

# =============================================================================
# Internet Gateway
# =============================================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.full_name}-igw"
  }
}

# =============================================================================
# Public Subnets
# =============================================================================
resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.current_subnets.public[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.full_name}-public-${local.azs[count.index]}"
    Type = "public"
  }
}

# =============================================================================
# Private Subnets (Application Layer)
# =============================================================================
resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.current_subnets.private[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.full_name}-private-${local.azs[count.index]}"
    Type = "private"
  }
}

# =============================================================================
# Database Subnets (Isolated)
# =============================================================================
resource "aws_subnet" "database" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.current_subnets.database[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.full_name}-database-${local.azs[count.index]}"
    Type = "database"
  }
}

# =============================================================================
# Database Subnet Group (for RDS/Aurora)
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name        = "${local.full_name}-db"
  description = "Database subnet group for ${local.full_name}"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    Name = "${local.full_name}-db-subnet-group"
  }
}

# =============================================================================
# Elastic IPs for NAT Gateway
# =============================================================================
resource "aws_eip" "nat" {
  count  = local.current_nat_config.enable_nat_gateway ? (local.current_nat_config.single_nat_gateway ? 1 : length(local.azs)) : 0
  domain = "vpc"

  tags = {
    Name = "${local.full_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT Gateway
# =============================================================================
resource "aws_nat_gateway" "main" {
  count = local.current_nat_config.enable_nat_gateway ? (local.current_nat_config.single_nat_gateway ? 1 : length(local.azs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.full_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Route Tables
# =============================================================================

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.full_name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(local.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ for HA NAT, or single for cost saving)
resource "aws_route_table" "private" {
  count  = local.current_nat_config.single_nat_gateway ? 1 : length(local.azs)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.current_nat_config.single_nat_gateway ? "${local.full_name}-private-rt" : "${local.full_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route" "private_nat" {
  count = local.current_nat_config.enable_nat_gateway ? (local.current_nat_config.single_nat_gateway ? 1 : length(local.azs)) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(local.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = local.current_nat_config.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Database Route Table (isolated - no internet access)
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.full_name}-database-rt"
  }
}

resource "aws_route_table_association" "database" {
  count = length(local.azs)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
