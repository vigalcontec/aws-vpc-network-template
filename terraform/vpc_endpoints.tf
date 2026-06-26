# =============================================================================
# VPC Endpoints
# =============================================================================
# VPC Endpoints allow private connectivity to AWS services without using
# NAT Gateway, reducing costs and improving security.
#
# Types:
# - Gateway Endpoints (S3, DynamoDB): Free, route table based
# - Interface Endpoints: ~$7.20/month each + data transfer

# -----------------------------------------------------------------------------
# Gateway Endpoints (Free)
# -----------------------------------------------------------------------------

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${local.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.database.id]
  )

  tags = {
    Name = "${local.full_name}-s3-endpoint"
  }
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${local.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = {
    Name = "${local.full_name}-dynamodb-endpoint"
  }
}

# -----------------------------------------------------------------------------
# Interface Endpoints Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.full_name}-vpc-endpoints"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.current_vpc_cidr]
  }

  tags = {
    Name = "${local.full_name}-vpc-endpoints-sg"
  }
}

# -----------------------------------------------------------------------------
# Interface Endpoints (Optional - uncomment as needed)
# -----------------------------------------------------------------------------
# Each interface endpoint costs ~$7.20/month + data transfer
# Only enable the ones you need to reduce costs

# Secrets Manager Endpoint (for RDS credentials)
# resource "aws_vpc_endpoint" "secretsmanager" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${local.aws_region}.secretsmanager"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = {
#     Name = "${local.full_name}-secretsmanager-endpoint"
#   }
# }

# SSM Endpoints (for Parameter Store and Session Manager)
# resource "aws_vpc_endpoint" "ssm" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${local.aws_region}.ssm"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = {
#     Name = "${local.full_name}-ssm-endpoint"
#   }
# }

# ECR Endpoints (for pulling container images)
# resource "aws_vpc_endpoint" "ecr_api" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${local.aws_region}.ecr.api"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = {
#     Name = "${local.full_name}-ecr-api-endpoint"
#   }
# }

# resource "aws_vpc_endpoint" "ecr_dkr" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${local.aws_region}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = {
#     Name = "${local.full_name}-ecr-dkr-endpoint"
#   }
# }

# CloudWatch Logs Endpoint
# resource "aws_vpc_endpoint" "logs" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${local.aws_region}.logs"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = {
#     Name = "${local.full_name}-logs-endpoint"
#   }
# }

# Bedrock Endpoint (for AI/ML workloads)
# resource "aws_vpc_endpoint" "bedrock" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${local.aws_region}.bedrock-runtime"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = {
#     Name = "${local.full_name}-bedrock-endpoint"
#   }
# }
