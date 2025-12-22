
# EC2 Role for K8s Nodes

resource "aws_iam_role" "ssm_ec2_role" {
  name = "salon-app-ssm-ec2-role"

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

# Managed Policy - AmazonSSMManagedInstanceCore

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

# Custom Policy: Cluster Autoscaler

resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name        = "salon-app-cluster-autoscaler-policy"
  description = "Allow EC2 nodes to scale the ASG"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Cluster Autoscaler Policy to Role

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attachment" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
}


# Instance Profile for EC2

resource "aws_iam_instance_profile" "ssm_ec2_instance_profile" {
  name = "salon-app-ssm-ec2-instance-profile"
  role = aws_iam_role.ssm_ec2_role.name
}
