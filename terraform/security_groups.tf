# =============================================================================
# Security Groups
# =============================================================================
# Pre-configured security groups for common use cases

# -----------------------------------------------------------------------------
# Default Security Group - Restrict all traffic
# -----------------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules - effectively blocks all traffic
  # This ensures no resources accidentally use the default SG

  tags = {
    Name = "${local.full_name}-default-restricted"
  }
}

# -----------------------------------------------------------------------------
# Lambda VPC Security Group
# -----------------------------------------------------------------------------
# For Lambda functions that need VPC access (e.g., to reach Aurora)
resource "aws_security_group" "lambda" {
  name        = "${local.full_name}-lambda"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = aws_vpc.main.id

  # Outbound: Allow all (Lambda needs to reach AWS services, databases, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.full_name}-lambda-sg"
  }
}

# -----------------------------------------------------------------------------
# Database Security Group (Aurora/RDS)
# -----------------------------------------------------------------------------
resource "aws_security_group" "database" {
  name        = "${local.full_name}-database"
  description = "Security group for Aurora/RDS databases"
  vpc_id      = aws_vpc.main.id

  # Inbound: PostgreSQL from Lambda
  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Inbound: PostgreSQL from private subnets (for ECS, EC2, etc.)
  ingress {
    description = "PostgreSQL from private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = local.current_subnets.private
  }

  # Inbound: MySQL from Lambda (if using MySQL Aurora)
  ingress {
    description     = "MySQL from Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Inbound: MySQL from private subnets
  ingress {
    description = "MySQL from private subnets"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = local.current_subnets.private
  }

  tags = {
    Name = "${local.full_name}-database-sg"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.full_name}-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Inbound: HTTPS from anywhere
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: HTTP from anywhere (redirect to HTTPS)
  ingress {
    description = "HTTP from anywhere (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: Allow all
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.full_name}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# ECS/Application Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "application" {
  name        = "${local.full_name}-application"
  description = "Security group for ECS tasks and application servers"
  vpc_id      = aws_vpc.main.id

  # Inbound: From ALB
  ingress {
    description     = "Traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound: Allow all
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.full_name}-application-sg"
  }
}

# -----------------------------------------------------------------------------
# Bastion Host Security Group (Optional)
# -----------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${local.full_name}-bastion"
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.main.id

  # Inbound: SSH from specific IPs (update with your IP)
  # NOTE: Update cidr_blocks with your office/home IP for security
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Restrict to your IP in production
  }

  # Outbound: Allow all
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.full_name}-bastion-sg"
  }
}

# -----------------------------------------------------------------------------
# Redis/ElastiCache Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "redis" {
  name        = "${local.full_name}-redis"
  description = "Security group for Redis/ElastiCache"
  vpc_id      = aws_vpc.main.id

  # Inbound: Redis from Lambda
  ingress {
    description     = "Redis from Lambda"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Inbound: Redis from application
  ingress {
    description     = "Redis from application"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  tags = {
    Name = "${local.full_name}-redis-sg"
  }
}
