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

output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}

output "k8s_node_private_ips" {
  value = data.aws_instances.k8s_nodes.private_ips
}

output "k8s_node_instance_ids" {
  value = data.aws_instances.k8s_nodes.ids
}
