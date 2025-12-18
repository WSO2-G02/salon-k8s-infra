# Get ASGs details
data "aws_autoscaling_group" "k8s" {
  name = aws_autoscaling_group.app_asg.name
}

# Get EC2 instances belonging to the ASG
data "aws_instances" "k8s_nodes" {
  instance_tags = {
    Role    = "k8s-node"
    Project = var.project_tag
  }
  instance_state_names = ["running"]
}
