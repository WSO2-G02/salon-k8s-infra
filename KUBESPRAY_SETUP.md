# Kubespray Setup Guide

This project now uses Kubespray for Kubernetes cluster deployment.

## Prerequisites

1. **Terraform 1.14.x** installed
2. **AWS credentials** configured (`aws configure`)
3. **Python 3** and **pip** installed
4. **Ansible** installed

## Setup Steps

### 1. Install Kubespray Dependencies

```bash
cd kubespray
pip3 install -r requirements.txt
```

### 2. Deploy Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply
```

This will:

- Create VPC, subnets, and networking
- Launch EC2 instances via Auto Scaling Group (default: 4 instances)
- Create ECR repositories for microservices
- **Automatically generate** Kubespray inventory at `kubespray/inventory/mycluster/hosts.yaml`

### 3. Verify Generated Inventory

```bash
cat ../kubespray/inventory/mycluster/hosts.yaml
```

You should see your nodes with their public IPs automatically populated.

### 4. Deploy Kubernetes Cluster with Kubespray

```bash
cd ../kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -v
```

This will:

- Install Kubernetes on all nodes
- Configure the control plane
- Join worker nodes to the cluster
- Install CNI plugin (Calico by default)
- Set up etcd

**Note:** This process takes 15-30 minutes.

### 5. Access Your Cluster

SSH into the master node:

```bash
ssh -i /home/ritzy/ansible-demo.pem ubuntu@<MASTER_IP>
```

Get cluster info:

```bash
kubectl get nodes
kubectl get pods -A
```

### 6. Copy kubeconfig to Local Machine (Optional)

From the master node, copy the kubeconfig:

```bash
sudo cat /etc/kubernetes/admin.conf
```

Save this to your local machine at `~/.kube/config` to manage the cluster remotely.

## Configuration

### Customize Kubespray Settings

Edit these files in `kubespray/inventory/mycluster/group_vars/`:

- `k8s_cluster/k8s-cluster.yml` - Kubernetes version, networking
- `k8s_cluster/addons.yml` - Enable/disable addons (dashboard, metrics-server, etc.)
- `all/all.yml` - General cluster settings

### Modify Instance Count

Edit `terraform/variables.tf`:

```hcl
variable "desired_capacity" {
  type    = number
  default = 4  # Change this value
}
```

Then run `terraform apply` again.

## Common Commands

### Scale the Cluster

```bash
cd kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml scale.yml -b
```

### Upgrade Kubernetes

```bash
cd kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml upgrade-cluster.yml -b
```

### Reset/Destroy Cluster

```bash
cd kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml reset.yml -b
```

Then destroy infrastructure:

```bash
cd ../terraform
terraform destroy
```

## Troubleshooting

### Inventory not generated?

Manually run:

```bash
cd terraform
bash generate_inventory.sh
```

### Ansible connection issues?

Verify SSH key path in `kubespray/inventory/mycluster/hosts.yaml`:

```yaml
ansible_ssh_private_key_file: /home/ritzy/ansible-demo.pem
```

Make sure the key has correct permissions:

```bash
chmod 600 /home/ritzy/ansible-demo.pem
```

### Instances not ready?

Wait 2-3 minutes after `terraform apply` for instances to boot, then regenerate inventory:

```bash
cd terraform
bash generate_inventory.sh
```

## Architecture

- **Node 1**: Kubernetes Control Plane + Worker
- **Node 2-4**: Kubernetes Workers
- **CNI**: Calico (default)
- **Container Runtime**: containerd
- **Ingress**: Can be enabled via Kubespray addons

## Next Steps

After cluster is running:

1. Deploy your microservices
2. Set up monitoring (Prometheus/Grafana)
3. Configure ingress controller
4. Set up CI/CD pipelines to push to ECR and deploy to K8s
