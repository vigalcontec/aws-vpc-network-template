# AWS VPC Network Template

Production-ready AWS VPC infrastructure with multi-AZ support, security groups, VPC endpoints, and flow logs.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              VPC: 10.X.0.0/16                                    │
│                              Region: eu-west-1                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                        AVAILABILITY ZONE A (eu-west-1a)                     ││
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  ││
│  │  │  PUBLIC SUBNET      │  │  PRIVATE SUBNET     │  │  DATABASE SUBNET    │  ││
│  │  │  10.X.1.0/24        │  │  10.X.11.0/24       │  │  10.X.21.0/24       │  ││
│  │  │  • NAT Gateway      │  │  • Lambda (VPC)     │  │  • Aurora Primary   │  ││
│  │  │  • ALB              │  │  • ECS Tasks        │  │  • RDS              │  ││
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                        AVAILABILITY ZONE B (eu-west-1b)                     ││
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  ││
│  │  │  PUBLIC SUBNET      │  │  PRIVATE SUBNET     │  │  DATABASE SUBNET    │  ││
│  │  │  10.X.2.0/24        │  │  10.X.12.0/24       │  │  10.X.22.0/24       │  ││
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                        AVAILABILITY ZONE C (eu-west-1c)                     ││
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  ││
│  │  │  PUBLIC SUBNET      │  │  PRIVATE SUBNET     │  │  DATABASE SUBNET    │  ││
│  │  │  10.X.3.0/24        │  │  10.X.13.0/24       │  │  10.X.23.0/24       │  ││
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Multi-AZ Deployment**: 3 availability zones for high availability
- **Subnet Tiers**: Public, Private, and Database (isolated) subnets
- **NAT Gateway**: Configurable single (dev) or multi-AZ (prod) NAT
- **Security Groups**: Pre-configured for Lambda, Aurora, ALB, ECS, Bastion, Redis
- **VPC Endpoints**: S3 and DynamoDB gateway endpoints (free)
- **Flow Logs**: CloudWatch-based VPC flow logs for security monitoring
- **SSM Exports**: All outputs exported to Parameter Store for cross-stack references

## CIDR Allocation

| Environment | VPC CIDR | Public | Private | Database |
|-------------|----------|--------|---------|----------|
| dev | 10.0.0.0/16 | 10.0.1-3.0/24 | 10.0.11-13.0/24 | 10.0.21-23.0/24 |
| qa | 10.1.0.0/16 | 10.1.1-3.0/24 | 10.1.11-13.0/24 | 10.1.21-23.0/24 |
| prod | 10.2.0.0/16 | 10.2.1-3.0/24 | 10.2.11-13.0/24 | 10.2.21-23.0/24 |

## Security Groups

| Security Group | Purpose | Inbound | Outbound |
|----------------|---------|---------|----------|
| `lambda` | Lambda functions in VPC | None | All |
| `database` | Aurora/RDS | 5432/3306 from lambda, private subnets | None |
| `alb` | Application Load Balancer | 80, 443 from anywhere | All |
| `application` | ECS/EC2 applications | From ALB | All |
| `bastion` | Bastion host | 22 (restrict in prod!) | All |
| `redis` | ElastiCache Redis | 6379 from lambda, application | None |

## NAT Gateway vs VPC Endpoints

### Why Avoid NAT Gateway in Dev?

Lambda functions in a VPC need **outbound internet access** to reach AWS services (S3, DynamoDB, Bedrock, etc.). There are two ways to achieve this:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OPTION 1: NAT Gateway (Traditional)                                        │
│  ─────────────────────────────────────                                      │
│  Lambda (Private Subnet) → NAT Gateway → Internet Gateway → AWS Services    │
│                                                                              │
│  Cost: ~$32/month + $0.045/GB data transfer                                 │
│  Pros: Access to ANY internet resource                                       │
│  Cons: Expensive, single point of failure (unless multi-AZ)                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  OPTION 2: VPC Endpoints (Recommended for Dev)                              │
│  ─────────────────────────────────────────────                              │
│  Lambda (Private Subnet) → VPC Endpoint → AWS Services (private network)   │
│                                                                              │
│  Cost: FREE for Gateway Endpoints (S3, DynamoDB)                            │
│        ~$7.20/month for Interface Endpoints (Bedrock, Secrets Manager)      │
│  Pros: No NAT costs, faster (private AWS network), more secure              │
│  Cons: Only works for AWS services, not external APIs                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### ENI (Elastic Network Interface)

When Lambda runs in a VPC, AWS creates an **ENI** (Elastic Network Interface) in your subnet. This ENI:
- Has a private IP from your subnet
- Can access resources in the VPC (Aurora, ElastiCache)
- **Cannot** access internet without NAT Gateway or VPC Endpoints

### Recommendation by Environment

| Environment | NAT Gateway | VPC Endpoints | Use Case |
|-------------|-------------|---------------|----------|
| **dev** | ❌ Disabled | ✅ S3, DynamoDB, Bedrock | Cost saving, AWS-only access |
| **qa** | ✅ Single | ✅ S3, DynamoDB | Testing with external APIs |
| **prod** | ✅ Multi-AZ | ✅ S3, DynamoDB | HA, external API access |

## Cost Estimates

| Component | Dev (No NAT) | QA (Single NAT) | Prod (Multi-AZ NAT) |
|-----------|--------------|-----------------|---------------------|
| NAT Gateway | $0 | ~$32/month | ~$96/month |
| VPC Flow Logs | ~$5/month | ~$10/month | ~$20/month |
| VPC Endpoints (Gateway) | Free | Free | Free |
| Interface Endpoints (optional) | ~$15/month | ~$15/month | ~$15/month |
| **Total** | **~$5-20/month** | **~$42-57/month** | **~$116-131/month** |

## Usage

### 1. Clone and Configure

```bash
git clone git@github.com:vigalcontec/aws-vpc-network-template.git my-vpc
cd my-vpc
```

Update `terraform/config.tf`:
```hcl
locals {
  vpc_name     = "main"           # Your VPC name
  project_name = "my-project"     # Your project name
  company_name = "mycompany"      # Your company name
}
```

### 2. Local Development

Create `terraform/backend_override.tf`:
```hcl
terraform {
  backend "s3" {
    bucket  = "tfstate-mycompany-dev-123456789012"
    key     = "vpc/main/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}
```

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### 3. CI/CD Deployment

Configure GitHub Secrets:
- `AWS_ROLE_ARN`: IAM role ARN for OIDC authentication
- `TF_STATE_BUCKET`: Terraform state bucket name

Push to `develop` branch for dev deployment, `main` for prod.

## Outputs

All outputs are exported to SSM Parameter Store under `/{project}/{environment}/vpc/`:

| Parameter | Description |
|-----------|-------------|
| `/vpc_id` | VPC ID |
| `/vpc_cidr` | VPC CIDR block |
| `/public_subnet_ids` | Comma-separated public subnet IDs |
| `/private_subnet_ids` | Comma-separated private subnet IDs |
| `/database_subnet_ids` | Comma-separated database subnet IDs |
| `/database_subnet_group_name` | RDS/Aurora subnet group name |
| `/security_group/lambda_id` | Lambda security group ID |
| `/security_group/database_id` | Database security group ID |
| `/security_group/alb_id` | ALB security group ID |

## Using in Other Modules

Reference VPC resources via SSM:

```hcl
data "aws_ssm_parameter" "vpc_id" {
  name = "/${local.project_name}/${var.environment}/vpc/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${local.project_name}/${var.environment}/vpc/private_subnet_ids"
}

data "aws_ssm_parameter" "sg_database_id" {
  name = "/${local.project_name}/${var.environment}/vpc/security_group/database_id"
}

# Use in Aurora
resource "aws_rds_cluster" "main" {
  vpc_security_group_ids = [data.aws_ssm_parameter.sg_database_id.value]
  db_subnet_group_name   = data.aws_ssm_parameter.database_subnet_group_name.value
  # ...
}
```

## Optional: Interface Endpoints

Uncomment in `vpc_endpoints.tf` to enable (each ~$7.20/month):
- Secrets Manager
- SSM Parameter Store
- ECR (API + DKR)
- CloudWatch Logs
- Bedrock Runtime

## License

MIT
