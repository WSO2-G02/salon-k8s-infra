data "aws_instances" "asg_nodes" {
  filter {
    name   = "tag:Role"
    values = ["k8s-node"]
  }
}
