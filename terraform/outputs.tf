output "instance_public_ips" {
  description = "Public IPs of all instances in ASG"
  value       = concat(data.aws_instances.cp_instances.public_ips, data.aws_instances.worker_instances.public_ips)
}

output "instance_private_ips" {
  description = "Private IPs of all instances in ASG"
  value       = concat(data.aws_instances.cp_instances.private_ips, data.aws_instances.worker_instances.private_ips)
}

output "instance_ids" {
  description = "Instance IDs of all instances in ASG"
  value       = concat(data.aws_instances.cp_instances.ids, data.aws_instances.worker_instances.ids)
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

output "ecr_repository_urls" {
  description = "Map of service names to ECR repository URLs"
  value = {
    for service, repo in aws_ecr_repository.repos :
    service => repo.repository_url
  }
}

output "ecr_registry_url" {
  description = "Base ECR registry URL"
  value       = split("/", values(aws_ecr_repository.repos)[0].repository_url)[0]
}

output "cp_asg_name" {
  value = aws_autoscaling_group.cp_asg.name
}
