# Automatically run Kubespray after infrastructure is created
# This eliminates the need for manual ansible-playbook command

resource "null_resource" "deploy_kubernetes" {
  depends_on = [
    null_resource.generate_inventory,
    aws_autoscaling_group.cp_asg,
    aws_autoscaling_group.worker_asg
  ]

  triggers = {
    cluster_instances = join(",", concat(data.aws_instances.cp_instances.ids, data.aws_instances.worker_instances.ids))
  }

  # Run Kubespray automatically
  provisioner "local-exec" {
    command     = "bash deploy_kubespray.sh"
    working_dir = path.module
  }
}

# Bootstrap ArgoCD after Kubernetes is deployed
resource "null_resource" "bootstrap_argocd_auto" {
  depends_on = [null_resource.deploy_kubernetes]

  triggers = {
    kubernetes_deployed = null_resource.deploy_kubernetes.id
  }

  provisioner "local-exec" {
    command     = "bash bootstrap_argocd.sh"
    working_dir = path.module
  }
}
