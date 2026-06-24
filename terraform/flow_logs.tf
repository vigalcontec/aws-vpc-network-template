# =============================================================================
# VPC Flow Logs
# =============================================================================
# Flow Logs capture information about IP traffic going to and from network
# interfaces in your VPC. Essential for security monitoring and troubleshooting.

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Flow Logs
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = local.current_flow_logs.enabled ? 1 : 0

  name              = "/aws/vpc/${local.full_name}/flow-logs"
  retention_in_days = local.current_flow_logs.retention_in_days

  tags = {
    Name = "${local.full_name}-flow-logs"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Flow Logs
# -----------------------------------------------------------------------------
resource "aws_iam_role" "flow_logs" {
  count = local.current_flow_logs.enabled ? 1 : 0

  name = "${local.full_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.full_name}-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = local.current_flow_logs.enabled ? 1 : 0

  name = "${local.full_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Log
# -----------------------------------------------------------------------------
resource "aws_flow_log" "main" {
  count = local.current_flow_logs.enabled ? 1 : 0

  vpc_id                   = aws_vpc.main.id
  traffic_type             = local.current_flow_logs.traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = 60

  tags = {
    Name = "${local.full_name}-flow-log"
  }
}
