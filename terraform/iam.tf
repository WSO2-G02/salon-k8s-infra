
# EC2 Role for K8s Nodes / Runner

resource "aws_iam_role" "ssm_ec2_role" {
  name = var.ssm_instance_profile_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Managed Policy: AmazonSSMManagedInstanceCore

resource "aws_iam_role_policy_attachment" "ssm_ec2_managed" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# Custom Policy: ECR Pull

resource "aws_iam_policy" "ecr_pull_policy" {
  name        = "salon-app-ecr-pull-policy"
  description = "Allow EC2 nodes to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Custom ECR Policy to Role

resource "aws_iam_role_policy_attachment" "ecr_pull_attachment" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = aws_iam_policy.ecr_pull_policy.arn
}


# Instance Profile for EC2

resource "aws_iam_instance_profile" "ssm_ec2_instance_profile" {
  name = "salon-app-ssm-ec2-instance-profile"
  role = aws_iam_role.ssm_ec2_role.name
}
