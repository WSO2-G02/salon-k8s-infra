output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "ecr_repository_arns" {
  value = [for r in aws_ecr_repository.repos : r.arn]
}

# Public IPs of the EC2 instances
output "ec2_public_ips" {
  value = [for i in aws_autoscaling_group.app_asg.instances : i.public_ip]
}

# Private IPs (for internal Kubernetes cluster communication)
output "ec2_private_ips" {
  value = [for i in aws_autoscaling_group.app_asg.instances : i.private_ip]
}
