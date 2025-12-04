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

output "ec2_public_ips" {
  value = data.aws_instances.asg_nodes.public_ips
}

output "ec2_private_ips" {
  value = data.aws_instances.asg_nodes.private_ips
}
