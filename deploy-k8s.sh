#!/bin/bash

set -e  # Exit on error

echo "=========================================="
echo "Kubernetes Cluster Deployment Automation"
echo "=========================================="
echo ""

# Step 1: Deploy Infrastructure
echo "📦 Step 1: Deploying AWS Infrastructure with Terraform..."
cd terraform

# Cleanup old plan if exists
rm -f tfplan
rm -f ../kubespray/inventory/mycluster/hosts.yaml

if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfstate" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

echo "Planning infrastructure..."
terraform plan -out=tfplan

read -p "Apply Terraform plan? (yes/no): " APPLY
if [ "$APPLY" == "yes" ]; then
    terraform apply tfplan
    rm tfplan
else
    echo "Skipping Terraform apply."
    exit 0
fi

# Step 2: Wait for instances to be ready
echo ""
echo "⏳ Step 2: Waiting for instances to be ready..."
sleep 30

# Step 3: Generate inventory (already triggered by Terraform null_resource)
echo ""
echo "📝 Step 3: Verifying inventory generation..."
# Inventory is now at ../inventory/hosts.yaml relative to terraform dir, or ./inventory/hosts.yaml relative to root
if [ -f "inventory/hosts.yaml" ]; then
    echo "✓ Inventory file found"
    cat inventory/hosts.yaml
else
    echo "✗ Inventory not found (looked at inventory/hosts.yaml)." 
fi

# Step 4: Test connectivity
echo ""
echo "🔌 Step 4: Testing SSH connectivity to nodes..."
# We run ansible from root context or setup ANSIBLE_CONFIG
export ANSIBLE_CONFIG=$(pwd)/ansible.cfg
# cd to kubespray to run ansible, but ref inventory in ../inventory/
cd kubespray
ansible all -i ../inventory/hosts.yaml -m ping

if [ $? -ne 0 ]; then
    echo "⚠️  Warning: Some nodes are not reachable. Check SSH keys and security groups."
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        exit 1
    fi
fi

# Step 5: Deploy Kubernetes with Kubespray
echo ""
echo "🚀 Step 5: Deploying Kubernetes cluster with Kubespray..."
read -p "Deploy Kubernetes cluster now? (yes/no): " DEPLOY
if [ "$DEPLOY" == "yes" ]; then
    export ANSIBLE_HOST_KEY_CHECKING=False
    # ANSIBLE_CONFIG is already exported
    ansible-playbook -i ../inventory/hosts.yaml cluster.yml -b
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "🔧 Step 6: Setting up kubeconfig on control plane..."
        cd ..
        # Now back in root
        ansible-playbook -i inventory/hosts.yaml setup-kubeconfig.yml
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "=========================================="
            echo "✅ Kubernetes Cluster Deployed Successfully!"
            echo "=========================================="
            echo ""
            echo "To access your cluster:"
            echo "  1. SSH into the control plane node"
            echo "  2. Run: kubectl get nodes"
            echo ""
        else
            echo ""
            echo "⚠️  Cluster deployed but kubeconfig setup failed."
            echo "You can set it up manually on the control plane:"
            echo "  mkdir -p ~/.kube"
            echo "  sudo cp /etc/kubernetes/admin.conf ~/.kube/config"
            echo "  sudo chown \$(id -u):\$(id -g) ~/.kube/config"
        fi
    else
        echo ""
        echo "❌ Kubernetes deployment failed. Check the logs above."
        exit 1
    fi
    
    # Step 7: Local Kubeconfig Setup
    echo ""
    echo "💻 Step 7: Configuring local kubectl..."
    CONTROL_IP=$(cd terraform && terraform output -json instance_public_ips | jq -r '.[0]')
    mkdir -p ~/.kube
    
    # Backup existing config
    if [ -f ~/.kube/config ]; then
        mv ~/.kube/config ~/.kube/config.bak.$(date +%s)
    fi

    scp -i terraform/salon-key.pem -o StrictHostKeyChecking=no ubuntu@${CONTROL_IP}:~/.kube/config ~/.kube/config
    
    if [ $? -eq 0 ]; then
        # Update server IP to public IP
        sed -i "s/127.0.0.1/${CONTROL_IP}/g" ~/.kube/config
        
        echo "✓ Local kubeconfig updated successfully!"
        echo "You can now run 'kubectl get nodes' from this terminal."
    else
        echo "⚠️  Failed to download kubeconfig. You may need to do it manually."
    fi

else
    echo "Skipping Kubernetes deployment."
    echo "To deploy manually, run:"
    echo "  export ANSIBLE_CONFIG=$(pwd)/ansible.cfg"
    echo "  cd kubespray"
    echo "  ansible-playbook -i ../inventory/hosts.yaml cluster.yml -b"
fi

