output "instance_public_ips" {
  description = "Public IPs of all instances in ASG"
  value       = data.aws_instances.asg_instances.public_ips
}

output "instance_private_ips" {
  description = "Private IPs of all instances in ASG"
  value       = data.aws_instances.asg_instances.private_ips
}

output "instance_ids" {
  description = "Instance IDs of all instances in ASG"
  value       = data.aws_instances.asg_instances.ids
}

output "kubespray_inventory_path" {
  description = "Path to generated Kubespray inventory"
  value       = "${path.module}/../kubespray/inventory/mycluster/hosts.yaml"
}

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