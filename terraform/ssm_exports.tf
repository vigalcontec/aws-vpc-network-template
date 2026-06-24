# =============================================================================
# SSM Parameter Store Exports
# =============================================================================
# Export VPC configuration to SSM Parameter Store for use by other modules
# Path convention: /{project}/{environment}/vpc/{parameter}

locals {
  ssm_prefix = "/${local.project_name}/${var.environment}/vpc"
}

# -----------------------------------------------------------------------------
# VPC Parameters
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "vpc_id" {
  name        = "${local.ssm_prefix}/vpc_id"
  description = "VPC ID for ${local.full_name}"
  type        = "String"
  value       = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "vpc_cidr" {
  name        = "${local.ssm_prefix}/vpc_cidr"
  description = "VPC CIDR block for ${local.full_name}"
  type        = "String"
  value       = aws_vpc.main.cidr_block

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Subnet Parameters
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "${local.ssm_prefix}/public_subnet_ids"
  description = "Comma-separated list of public subnet IDs"
  type        = "StringList"
  value       = join(",", aws_subnet.public[*].id)

  tags = local.common_tags
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name        = "${local.ssm_prefix}/private_subnet_ids"
  description = "Comma-separated list of private subnet IDs"
  type        = "StringList"
  value       = join(",", aws_subnet.private[*].id)

  tags = local.common_tags
}

resource "aws_ssm_parameter" "database_subnet_ids" {
  name        = "${local.ssm_prefix}/database_subnet_ids"
  description = "Comma-separated list of database subnet IDs"
  type        = "StringList"
  value       = join(",", aws_subnet.database[*].id)

  tags = local.common_tags
}

resource "aws_ssm_parameter" "database_subnet_group_name" {
  name        = "${local.ssm_prefix}/database_subnet_group_name"
  description = "Database subnet group name"
  type        = "String"
  value       = aws_db_subnet_group.main.name

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Security Group Parameters
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "sg_lambda_id" {
  name        = "${local.ssm_prefix}/security_group/lambda_id"
  description = "Lambda security group ID"
  type        = "String"
  value       = aws_security_group.lambda.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sg_database_id" {
  name        = "${local.ssm_prefix}/security_group/database_id"
  description = "Database security group ID"
  type        = "String"
  value       = aws_security_group.database.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sg_alb_id" {
  name        = "${local.ssm_prefix}/security_group/alb_id"
  description = "ALB security group ID"
  type        = "String"
  value       = aws_security_group.alb.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sg_application_id" {
  name        = "${local.ssm_prefix}/security_group/application_id"
  description = "Application security group ID"
  type        = "String"
  value       = aws_security_group.application.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sg_bastion_id" {
  name        = "${local.ssm_prefix}/security_group/bastion_id"
  description = "Bastion security group ID"
  type        = "String"
  value       = aws_security_group.bastion.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sg_redis_id" {
  name        = "${local.ssm_prefix}/security_group/redis_id"
  description = "Redis security group ID"
  type        = "String"
  value       = aws_security_group.redis.id

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Availability Zones
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "availability_zones" {
  name        = "${local.ssm_prefix}/availability_zones"
  description = "Comma-separated list of availability zones"
  type        = "StringList"
  value       = join(",", local.azs)

  tags = local.common_tags
}
