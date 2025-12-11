# Salon App Kubernetes Infrastructure

This repository contains Terraform configurations and Kubespray automation to deploy a production-ready Kubernetes cluster on AWS for the Salon Booking System.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Step-by-Step Deployment Guide](#step-by-step-deployment-guide)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before starting, ensure you have the following installed and configured:

### Required Tools

1. **Terraform** (v1.14.x or higher)

   ```bash
   terraform --version
   ```

2. **AWS CLI** configured with credentials

   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and default region
   ```

3. **Python 3** (3.8 or higher)

   ```bash
   python3 --version
   ```

4. **Ansible** (2.14 or higher)

   ```bash
   ansible --version
   ```

5. **jq** (for JSON parsing)

   ```bash
   # Ubuntu/Debian
   sudo apt install jq

   # macOS
   brew install jq
   ```

6. **SSH Key**
   - The Terraform configuration will use the key at `terraform/salon-key.pem`
   - Ensure proper permissions:
     ```bash
     chmod 400 terraform/salon-key.pem
     ```

### AWS Permissions

Your AWS user/role needs permissions for:

- VPC, Subnets, Internet Gateway, Route Tables
- EC2 instances, Security Groups
- Auto Scaling Groups
- ECR (Elastic Container Registry)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                  │   │
│  │                                                        │   │
│  │  ┌─────────────────┐    ┌──────────────────────┐     │   │
│  │  │  Public Subnet  │    │   Public Subnet      │     │   │
│  │  │  10.0.1.0/24    │    │   10.0.2.0/24        │     │   │
│  │  │                 │    │                      │     │   │
│  │  │  ┌───────────┐  │    │  ┌────────────┐     │     │   │
│  │  │  │ Control   │  │    │  │  Worker 2  │     │     │   │
│  │  │  │  Plane    │  │    │  └────────────┘     │     │   │
│  │  │  └───────────┘  │    │                      │     │   │
│  │  │                 │    │  ┌────────────┐     │     │   │
│  │  │  ┌───────────┐  │    │  │  Worker 3  │     │     │   │
│  │  │  │ Worker 1  │  │    │  └────────────┘     │     │   │
│  │  │  └───────────┘  │    │                      │     │   │
│  │  └─────────────────┘    └──────────────────────┘     │   │
│  │                                                        │   │
│  │  ┌─────────────────┐    ┌──────────────────────┐     │   │
│  │  │ Private Subnet  │    │  Private Subnet      │     │   │
│  │  │  10.0.10.0/24   │    │   10.0.11.0/24       │     │   │
│  │  └─────────────────┘    └──────────────────────┘     │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Infrastructure Components:**

- 1 Control Plane node (manages Kubernetes cluster)
- 3 Worker nodes (run application workloads)
- VPC with public and private subnets across 2 AZs
- ECR repositories for microservices
- Security groups for controlled access

## Step-by-Step Deployment Guide

### Step 1: Clone the Repository

```bash
git clone https://github.com/WSO2-G02/salon-k8s-infra.git
cd salon-k8s-infra
```

### Step 2: Configure Terraform Variables

Edit `terraform/variables.tf` to customize your deployment:

```hcl
variable "region" {
  default = "ap-south-1"  # Change to your preferred region
}

variable "desired_capacity" {
  default = 4  # Total nodes: 1 control plane + 3 workers
}

variable "instance_type" {
  default = "t3.large"  # Adjust based on workload requirements
}
```

**Instance Type Recommendations:**

- Development: `t3.medium` (2 vCPU, 4 GB RAM)
- Production: `t3.large` or higher (2 vCPU, 8 GB RAM)
- High-performance: `t3.xlarge` or `m5.xlarge`

### Step 3: Initialize Terraform

```bash
cd terraform
terraform init
```

This will:

- Download AWS provider plugins
- Initialize the backend
- Prepare the working directory

### Step 4: Review the Terraform Plan

```bash
terraform plan
```

Review the output to see what resources will be created:

- VPC and networking components
- 4 EC2 instances (1 control plane + 3 workers)
- Security groups
- ECR repositories
- Auto Scaling Group

### Step 5: Deploy AWS Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Expected Duration:** 3-5 minutes

**What happens:**

1. Creates VPC, subnets, internet gateway, route tables
2. Launches EC2 instances via Auto Scaling Group
3. Automatically renames instances:
   - `salon-app-control-plane`
   - `salon-app-worker1`
   - `salon-app-worker2`
   - `salon-app-worker3`
4. Creates ECR repositories for microservices
5. Generates Kubespray inventory at `../kubespray/inventory/mycluster/hosts.yaml`

**Verify deployment:**

```bash
# Check outputs
terraform output

# View generated inventory
cat ../kubespray/inventory/mycluster/hosts.yaml
```

### Step 6: Install Kubespray Dependencies

```bash
cd ../kubespray

# Install Python dependencies
pip3 install -r requirements.txt

# Install Ansible collections (IMPORTANT!)
ansible-galaxy collection install -r requirements.yml
```

This installs:

- Ansible collections (kubernetes.core, etc.)
- Python dependencies (netaddr, Jinja2, etc.)
- Kubespray requirements

**Note:** If you cloned Kubespray as a Git submodule or shallow clone, ensure all files are present:

```bash
# If using git submodule
git submodule update --init --recursive

# Or verify roles directory exists
ls -la roles/kubespray-defaults
```

### Step 7: Verify Connectivity to Nodes

```bash
# Test SSH connectivity to all nodes
ansible all -i inventory/mycluster/hosts.yaml -m ping
```

**Expected output:**

```
control-plane | SUCCESS => { "ping": "pong" }
worker1 | SUCCESS => { "ping": "pong" }
worker2 | SUCCESS => { "ping": "pong" }
worker3 | SUCCESS => { "ping": "pong" }
```

**If connection fails:**

- Check SSH key path in inventory
- Verify security group allows SSH (port 22) from your IP
- Wait 1-2 minutes for instances to fully boot

### Step 8: Deploy Kubernetes with Kubespray

```bash
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -v
```

**Flags explained:**

- `-i inventory/mycluster/hosts.yaml` - Use our generated inventory
- `-b` - Become root (use sudo)
- `-v` - Verbose output (use `-vv` or `-vvv` for more detail)

**Expected Duration:** 15-30 minutes

**What Kubespray does:**

1. Prepares all nodes (installs dependencies)
2. Sets up container runtime (containerd)
3. Deploys etcd cluster
4. Installs Kubernetes control plane components
5. Joins worker nodes to the cluster
6. Deploys CNI plugin (Calico)
7. Configures DNS (CoreDNS)
8. Sets up kubectl access

### Step 9: Setup Kubeconfig on Control Plane

After Kubespray completes, configure kubectl access on the control plane node:

```bash
# From your local machine, run:
cd ..
ansible-playbook -i kubespray/inventory/mycluster/hosts.yaml setup-kubeconfig.yml
```

This automatically configures the kubeconfig for the ubuntu user on the control plane.

### Step 10: Access Your Kubernetes Cluster

#### Option A: From the Control Plane Node (Recommended)

```bash
# Get control plane IP
cd terraform
terraform output control_plane_public_ip

# SSH into control plane
ssh -i terraform/salon-key.pem ubuntu@<CONTROL_PLANE_IP>

# Verify cluster (kubeconfig already configured via setup-kubeconfig.yml)
kubectl get nodes
kubectl get pods -A
```

**Expected output:**

```
NAME            STATUS   ROLES           AGE   VERSION
control-plane   Ready    control-plane   5m    v1.30.0
worker1         Ready    <none>          4m    v1.30.0
worker2         Ready    <none>          4m    v1.30.0
worker3         Ready    <none>          4m    v1.30.0
```

#### Option B: From Your Local Machine

```bash
# SSH into control plane
ssh -i terraform/salon-key.pem ubuntu@<CONTROL_PLANE_IP>

# Copy kubeconfig
sudo cat /etc/kubernetes/admin.conf

# Exit SSH and save to local machine
# On your local machine:
mkdir -p ~/.kube
nano ~/.kube/config  # Paste the content

# Update the server IP in ~/.kube/config
# Change: server: https://10.0.x.x:6443
# To:     server: https://<CONTROL_PLANE_PUBLIC_IP>:6443

# Verify from local machine
kubectl get nodes
```

### Step 11: Deploy Your Applications

```bash
# Example: Deploy a test application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the NodePort
kubectl get svc nginx
```

## Configuration

### Kubernetes Cluster Settings

Edit `kubespray/inventory/mycluster/group_vars/all.yml`:

```yaml
# Kubernetes version
kube_version: v1.30.0

# Network plugin
kube_network_plugin: calico

# Pod network CIDR
kube_pods_subnet: 192.168.0.0/16

# Service CIDR
kube_service_addresses: 10.233.0.0/18
```

### Terraform Configuration

Key files in `terraform/`:

- `variables.tf` - Customizable variables
- `vpc.tf` - VPC and networking
- `ec2.tf` - EC2 instances and Auto Scaling Group
- `sg.tf` - Security groups
- `ecr.tf` - Container registry

### Scaling the Cluster

**To add more workers:**

1. Edit `terraform/variables.tf`:

   ```hcl
   variable "desired_capacity" {
     default = 6  # Increase from 4 to 6 for 5 workers
   }
   ```

2. Apply changes:

   ```bash
   cd terraform
   terraform apply
   ```

3. Add new nodes to cluster:
   ```bash
   cd ../kubespray
   ansible-playbook -i inventory/mycluster/hosts.yaml scale.yml -b
   ```

## Troubleshooting

### Issue: Inventory not generated

**Solution:**

```bash
cd terraform
bash generate_inventory.sh
```

### Issue: Ansible can't find kubespray-defaults role

**Cause:** Kubespray roles are missing from the `roles/` directory. This can happen if:

- Kubespray was cloned without full Git history
- Files were copied instead of cloned
- Submodules weren't initialized

**Solution:**

```bash
cd kubespray

# Method 1: If Kubespray is a Git repository
git submodule update --init --recursive

# Method 2: Install collections
ansible-galaxy collection install -r requirements.yml

# Method 3: If still failing, verify roles exist
ls -la roles/kubespray-defaults

# If roles directory is empty, you may need to re-clone Kubespray
cd ..
rm -rf kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout release-2.24
pip3 install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

### Issue: SSH connection timeout

**Causes:**

- Security group doesn't allow SSH from your IP
- Wrong SSH key
- Instance not fully booted

**Solutions:**

```bash
# Check security group allows your IP
curl ifconfig.me  # Get your public IP

# Update security group in AWS Console or:
cd terraform
# Edit sg.tf to add your IP
terraform apply

# Verify SSH key
ls -la terraform/salon-key.pem
chmod 400 terraform/salon-key.pem
```

### Issue: Kubespray playbook fails

**Common causes:**

- Insufficient instance resources (use t3.large or higher)
- Network connectivity issues
- Python dependencies missing

**Solutions:**

```bash
# Re-run with more verbosity
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -vvv

# Check Python on nodes
ansible all -i inventory/mycluster/hosts.yaml -m shell -a "python3 --version"

# Reset and retry
ansible-playbook -i inventory/mycluster/hosts.yaml reset.yml -b
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b
```

### Issue: Nodes not ready

**Check:**

```bash
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet logs
ssh -i terraform/salon-key.pem ubuntu@<NODE_IP>
sudo journalctl -u kubelet -f
```

## Automation Scripts

### Full Deployment (One Command)

```bash
./deploy-k8s.sh
```

This script:

1. Runs Terraform to create infrastructure
2. Waits for instances to be ready
3. Generates inventory
4. Tests connectivity
5. Deploys Kubernetes with Kubespray

### Refresh Inventory Only

```bash
./refresh-inventory.sh
```

Use when instance IPs change but infrastructure exists.

## Cleanup

### Destroy Kubernetes Cluster (Keep Infrastructure)

```bash
cd kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml reset.yml -b
```

### Destroy Everything

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted.

This will delete:

- All EC2 instances
- Auto Scaling Group
- VPC and networking
- Security groups
- ECR repositories

**Warning:** This is irreversible. Ensure you have backups of any important data.

## Project Structure

```
salon-k8s-infra/
├── terraform/
│   ├── backend.tf              # Terraform backend config
│   ├── providers.tf            # AWS provider
│   ├── variables.tf            # Customizable variables
│   ├── vpc.tf                  # VPC and networking
│   ├── subnets.tf              # Subnet configurations
│   ├── internet_gateway.tf     # Internet gateway
│   ├── route_table.tf          # Route tables
│   ├── sg.tf                   # Security groups
│   ├── ec2.tf                  # EC2 instances & ASG
│   ├── ecr.tf                  # Container registry
│   ├── outputs.tf              # Terraform outputs
│   ├── generate_inventory.sh   # Auto-generate Kubespray inventory
│   ├── key_pair.tf             # SSH key pair resource
│   ├── salon-key.pub           # Public SSH key (committed)
│   ├── salon-key.pem           # Private SSH key (gitignored)
│   └── user_data.sh            # EC2 initialization script
│
├── kubespray/
│   ├── inventory/mycluster/
│   │   ├── hosts.yaml          # Auto-generated inventory
│   │   └── group_vars/
│   │       └── all.yml         # Cluster configuration
│   ├── cluster.yml             # Main deployment playbook
│   ├── scale.yml               # Scale cluster playbook
│   ├── upgrade-cluster.yml     # Upgrade playbook
│   └── reset.yml               # Cluster reset playbook
│
├── deploy-k8s.sh               # Full automation script
├── refresh-inventory.sh        # Inventory refresh script
├── setup-kubeconfig.yml        # Kubeconfig setup playbook
├── .gitignore                  # Git ignore rules (includes *.pem)
├── README.md                   # This file
├── DEPLOYMENT_GUIDE.md         # Detailed deployment guide
└── KUBESPRAY_SETUP.md          # Kubespray-specific guide
```

## Next Steps After Deployment

1. **Set up Ingress Controller**

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
   ```

2. **Install Monitoring (Prometheus & Grafana)**

   - Edit `kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml`
   - Enable metrics-server and prometheus

3. **Deploy Your Microservices**

   - Build and push images to ECR
   - Create Kubernetes manifests
   - Deploy using `kubectl apply -f`

4. **Set up CI/CD**
   - Configure GitHub Actions to build and push to ECR
   - Auto-deploy to Kubernetes on merge

## Additional Resources

- [Kubespray Documentation](https://kubespray.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review `DEPLOYMENT_GUIDE.md` for detailed explanations
3. Check Kubespray logs: `ansible-playbook` output
4. Review Terraform state: `terraform show`

## License

MIT
