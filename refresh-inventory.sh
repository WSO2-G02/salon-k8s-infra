#!/bin/bash

set -e

echo "🔄 Refreshing Kubespray inventory from Terraform state..."

cd terraform

# Regenerate inventory
bash generate_inventory.sh

cd ../kubespray

echo ""
echo "📋 Generated inventory:"
cat inventory/mycluster/hosts.yaml

echo ""
echo "🔌 Testing connectivity..."
ansible all -i inventory/mycluster/hosts.yaml -m ping

echo ""
echo "✓ Inventory refreshed and nodes are reachable!"
echo ""
echo "To deploy Kubernetes, run:"
echo "  cd kubespray"
echo "  ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b"
