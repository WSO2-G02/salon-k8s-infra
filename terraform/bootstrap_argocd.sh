#!/bin/bash
set -e

# ArgoCD Bootstrap Script
# Automatically deploys ECR credential helper and all ArgoCD applications
# This runs after Terraform creates infrastructure

echo "=========================================="
echo "ArgoCD Bootstrap Automation"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CONTROL_PLANE_USER="ubuntu"
GITOPS_REPO="https://github.com/WSO2-G02/salon-gitops.git"
GITOPS_DIR="/tmp/salon-gitops"
KUBECONFIG_PATH="../kubespray/inventory/mycluster/artifacts/admin.conf"

echo -e "${YELLOW}Step 1: Getting control-plane IP...${NC}"
INVENTORY_FILE="../kubespray/inventory/mycluster/hosts.yaml"

if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}ERROR: Inventory file not found!${NC}"
    echo "Run Kubespray first: ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b"
    exit 1
fi

# Extract control-plane IP from inventory
CONTROL_PLANE_IP=$(grep -A 3 "control-plane:" "$INVENTORY_FILE" | grep "ansible_host:" | awk '{print $2}')

if [ -z "$CONTROL_PLANE_IP" ]; then
    echo -e "${RED}ERROR: Could not find control-plane IP in inventory${NC}"
    exit 1
fi

echo -e "${GREEN}Control-plane IP: $CONTROL_PLANE_IP${NC}"

echo -e "${YELLOW}Step 2: Testing SSH connection...${NC}"
SSH_KEY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/salon-key.pem"

if [ ! -f "$SSH_KEY_PATH" ]; then
    # Try alternative paths
    SSH_KEY_PATH=$(find ../.. -name "salon-key.pem" -o -name "salon-key" 2>/dev/null | head -1)
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}ERROR: SSH key not found!${NC}"
    echo "Expected: ./salon-key.pem"
    exit 1
fi

chmod 600 "$SSH_KEY_PATH"

if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "echo 'Connection successful'" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot SSH to control-plane!${NC}"
    echo "Make sure your SSH key is configured and the node is accessible."
    exit 1
fi
echo -e "${GREEN}SSH connection successful${NC}"

echo -e "${YELLOW}Getting kubeconfig from control-plane...${NC}"
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:~/.kube/config" "/tmp/kubeconfig_$$" 2>/dev/null || {
    echo -e "${YELLOW}Could not get kubeconfig, will use SSH for kubectl commands${NC}"
}
export KUBECONFIG="/tmp/kubeconfig_$$"

echo -e "${YELLOW}Step 3: Checking if cluster is ready...${NC}"
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl cluster-info" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Kubernetes cluster not accessible!${NC}"
    echo "Run Kubespray first to create the cluster."
    exit 1
fi
echo -e "${GREEN}Cluster is ready${NC}"

echo -e "${YELLOW}Step 4: Checking if ArgoCD is installed...${NC}"
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl get namespace argocd" > /dev/null 2>&1; then
    echo -e "${YELLOW}ArgoCD not found. Installing...${NC}"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl create namespace argocd"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    echo -e "${GREEN}ArgoCD installed. Waiting for it to be ready...${NC}"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd"
else
    echo -e "${GREEN}ArgoCD already installed${NC}"
fi

echo -e "${YELLOW}Step 5: Creating staging namespace...${NC}"
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -"
echo -e "${GREEN}Staging namespace ready${NC}"

echo -e "${YELLOW}Step 6: Deploying ECR credential helper...${NC}"
# Find GitOps repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_GITOPS_DIR="${SCRIPT_DIR}/../../salon-gitops"

# Resolve to absolute path
if [[ "$PARENT_GITOPS_DIR" != /* ]]; then
    PARENT_GITOPS_DIR="$(cd "$PARENT_GITOPS_DIR" 2>/dev/null && pwd)"
fi

if [ ! -f "${PARENT_GITOPS_DIR}/staging/ecr-credential-helper.yaml" ]; then
    echo -e "${RED}ERROR: GitOps repo not found at ${PARENT_GITOPS_DIR}${NC}"
    exit 1
fi

# Copy file to control-plane and deploy
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "mkdir -p /tmp/k8s-deploy"
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${PARENT_GITOPS_DIR}/staging/ecr-credential-helper.yaml" "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:/tmp/k8s-deploy/"
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl apply -f /tmp/k8s-deploy/ecr-credential-helper.yaml"
echo -e "${GREEN}ECR credential helper deployed${NC}"

# Wait a moment for CronJob to be created
sleep 5

# Run the job immediately
echo -e "${YELLOW}Step 7: Running ECR credential helper job...${NC}"
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl create job --from=cronjob/ecr-cred-helper ecr-cred-initial -n kube-system --dry-run=client -o yaml | kubectl apply -f -"

# Wait for job to complete
echo -e "${YELLOW}Step 8: Waiting for ECR credentials to be created...${NC}"
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl wait --for=condition=complete --timeout=60s job/ecr-cred-initial -n kube-system" || {
    echo -e "${RED}WARNING: ECR credential job may have failed. Check logs:${NC}"
    echo "kubectl logs job/ecr-cred-initial -n kube-system"
}

# Verify secrets were created
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl get secret ecr-registry-secret -n staging" > /dev/null 2>&1; then
    echo -e "${GREEN}ECR secret created in staging namespace${NC}"
else
    echo -e "${RED}WARNING: ECR secret not found in staging namespace${NC}"
fi

if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl get secret ecr-registry-secret -n argocd" > /dev/null 2>&1; then
    echo -e "${GREEN}ECR secret created in argocd namespace${NC}"
else
    echo -e "${RED}WARNING: ECR secret not found in argocd namespace${NC}"
fi

echo -e "${YELLOW}Step 9: Deploying ArgoCD applications...${NC}"
# Copy all YAML files to control-plane
for yaml_file in "${PARENT_GITOPS_DIR}"/argocd/*.yaml; do
    echo "Deploying $(basename "$yaml_file")..."
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$yaml_file" "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:/tmp/k8s-deploy/"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl apply -f /tmp/k8s-deploy/$(basename "$yaml_file")"
done
echo -e "${GREEN}ArgoCD applications deployed${NC}"

echo -e "${YELLOW}Step 10: Waiting for applications to sync...${NC}"
sleep 10

# Check application status
echo -e "${YELLOW}Current ArgoCD application status:${NC}"
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "kubectl get applications -n argocd"

echo ""
echo "=========================================="
echo -e "${GREEN}Bootstrap Complete!${NC}"
echo "=========================================="
echo ""
echo "To check status:"
echo "  ssh ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}"
echo "  kubectl get applications -n argocd"
echo "  kubectl get pods -n staging"
echo ""
echo "To access ArgoCD UI:"
echo "  ssh -L 8080:localhost:8080 ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then visit: https://localhost:8080"
echo ""
