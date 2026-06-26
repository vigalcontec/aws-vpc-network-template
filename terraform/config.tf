# =============================================================================
# Configuration - Update these values for your project
# =============================================================================

locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Project Configuration (UPDATE THESE)
  # ─────────────────────────────────────────────────────────────────────────────
  vpc_name     = "main"        # VPC name (without env suffix)
  project_name = "my-project"  # Project name for tagging
  company_name = "vigalcontec" # Company name for resource naming

  # ─────────────────────────────────────────────────────────────────────────────
  # AWS Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  aws_region = "eu-west-1"

  # ─────────────────────────────────────────────────────────────────────────────
  # VPC CIDR Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Use different CIDR blocks per environment to allow VPC peering if needed
  vpc_cidr = {
    dev  = "10.0.0.0/16"
    qa   = "10.1.0.0/16"
    prod = "10.2.0.0/16"
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Availability Zones
  # ─────────────────────────────────────────────────────────────────────────────
  azs = ["${local.aws_region}a", "${local.aws_region}b", "${local.aws_region}c"]

  # ─────────────────────────────────────────────────────────────────────────────
  # Subnet CIDR Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # Public subnets: NAT Gateway, ALB, Bastion
  # Private subnets: Lambda, ECS, App servers
  # Database subnets: Aurora, RDS, ElastiCache (isolated)
  #
  # CIDR calculation for /16 VPC:
  # - Public:   /24 subnets (256 IPs each) - 10.X.1-3.0/24
  # - Private:  /24 subnets (256 IPs each) - 10.X.11-13.0/24
  # - Database: /24 subnets (256 IPs each) - 10.X.21-23.0/24

  subnet_cidrs = {
    dev = {
      public   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      private  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
      database = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
    }
    qa = {
      public   = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
      private  = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
      database = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]
    }
    prod = {
      public   = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
      private  = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]
      database = ["10.2.21.0/24", "10.2.22.0/24", "10.2.23.0/24"]
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # NAT Gateway Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  # single_nat_gateway = true  → Cost saving (~$32/month), single point of failure
  # single_nat_gateway = false → HA (~$96/month for 3 AZs), recommended for prod
  nat_gateway_config = {
    dev = {
      enable_nat_gateway     = false # Use VPC Endpoints instead to save costs
      single_nat_gateway     = false
      one_nat_gateway_per_az = false
    }
    qa = {
      enable_nat_gateway     = true
      single_nat_gateway     = true # Cost saving for QA
      one_nat_gateway_per_az = false
    }
    prod = {
      enable_nat_gateway     = true
      single_nat_gateway     = false # HA for production
      one_nat_gateway_per_az = true  # One NAT per AZ
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # VPC Flow Logs Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  flow_logs_config = {
    dev = {
      enabled           = true
      retention_in_days = 7
      traffic_type      = "REJECT" # Only rejected traffic for dev
    }
    qa = {
      enabled           = true
      retention_in_days = 14
      traffic_type      = "ALL"
    }
    prod = {
      enabled           = true
      retention_in_days = 90
      traffic_type      = "ALL"
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Computed Values (DO NOT MODIFY)
  # ─────────────────────────────────────────────────────────────────────────────
  account_id   = data.aws_caller_identity.current.account_id
  full_name    = "${local.vpc_name}-${var.environment}"
  state_bucket = "tfstate-${local.company_name}-${var.environment}-${local.account_id}"

  # Environment-specific configurations
  current_vpc_cidr   = local.vpc_cidr[var.environment]
  current_subnets    = local.subnet_cidrs[var.environment]
  current_nat_config = local.nat_gateway_config[var.environment]
  current_flow_logs  = local.flow_logs_config[var.environment]

  # Common tags
  common_tags = {
    Project     = local.project_name
    VPC         = local.vpc_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
