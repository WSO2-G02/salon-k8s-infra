#!/bin/bash
set -e

# Automatically deploy Kubernetes using Kubespray
# This runs as part of Terraform automation

echo "=========================================="
echo "Automated Kubespray Deployment"
echo "=========================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

KUBESPRAY_DIR="../kubespray"
INVENTORY_FILE="../inventory/hosts.yaml"

echo -e "${YELLOW}Step 1: Checking if inventory exists...${NC}"
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}ERROR: Inventory file not found!${NC}"
    echo "Expected: $INVENTORY_FILE"
    exit 1
fi
echo -e "${GREEN}Inventory found${NC}"

echo -e "${YELLOW}Step 2: Checking if cluster already exists...${NC}"
# Extract control-plane IP from inventory
CONTROL_PLANE_IP=$(grep -A 3 "control-plane:" "$INVENTORY_FILE" | grep "ansible_host:" | awk '{print $2}')

SSH_KEY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/salon-key.pem"
if [ ! -f "$SSH_KEY_PATH" ]; then
    SSH_KEY_PATH=$(find ../.. -name "salon-key.pem" -o -name "salon-key" 2>/dev/null | head -1)
fi

if [ -n "$CONTROL_PLANE_IP" ]; then
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@${CONTROL_PLANE_IP} "kubectl cluster-info" > /dev/null 2>&1; then
        echo -e "${GREEN}Cluster already exists and is running!${NC}"
        echo -e "${YELLOW}Skipping Kubespray deployment${NC}"
        exit 0
    fi
fi

echo -e "${YELLOW}Step 3: Running Kubespray deployment...${NC}"
echo -e "${RED}WARNING: This will take 15-20 minutes!${NC}"
echo ""

# Set Ansible Config to our custom one in root
export ANSIBLE_CONFIG=$(cd .. && pwd)/ansible.cfg

cd "$KUBESPRAY_DIR"

# Export ANSIBLE_ROLES_PATH to ensure roles are found
export ANSIBLE_ROLES_PATH="$PWD/roles:$ANSIBLE_ROLES_PATH"

# Run Kubespray
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ../inventory/hosts.yaml cluster.yml -b

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Kubespray deployment successful!${NC}"
else
    echo -e "${RED}Kubespray deployment failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 4: Verifying cluster...${NC}"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_IP} "kubectl cluster-info" > /dev/null 2>&1; then
    echo -e "${GREEN}Cluster is ready!${NC}"
else
    echo -e "${RED}Cluster verification failed!${NC}"
    exit 1
fi

echo "=========================================="
echo -e "${GREEN}Kubernetes Deployment Complete!${NC}"
echo "=========================================="
