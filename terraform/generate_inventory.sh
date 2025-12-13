#!/bin/bash

# Get instance IPs and IDs from terraform output
PUBLIC_IPS=$(terraform output -json instance_public_ips | jq -r '.[]')
PRIVATE_IPS=$(terraform output -json instance_private_ips | jq -r '.[]')
INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]')

# Convert to arrays
PUBLIC_IPS_ARRAY=($PUBLIC_IPS)
PRIVATE_IPS_ARRAY=($PRIVATE_IPS)
INSTANCE_IDS_ARRAY=($INSTANCE_IDS)

# Check if we have at least 1 instance
if [ ${#PUBLIC_IPS_ARRAY[@]} -lt 1 ]; then
  echo "Error: Need at least 1 instance. Found ${#PUBLIC_IPS_ARRAY[@]}."
  exit 1
fi

echo "🏷️  Renaming EC2 instances..."

# Rename instances in AWS
for i in "${!INSTANCE_IDS_ARRAY[@]}"; do
  if [ $i -eq 0 ]; then
    # First instance is control plane
    aws ec2 create-tags --resources ${INSTANCE_IDS_ARRAY[$i]} --tags Key=Name,Value=salon-app-control-plane Key=K8sRole,Value=control-plane
    echo "  ✓ ${INSTANCE_IDS_ARRAY[$i]} → salon-app-control-plane"
  else
    # Rest are workers
    WORKER_NUM=$i
    aws ec2 create-tags --resources ${INSTANCE_IDS_ARRAY[$i]} --tags Key=Name,Value=salon-app-worker${WORKER_NUM} Key=K8sRole,Value=worker
    echo "  ✓ ${INSTANCE_IDS_ARRAY[$i]} → salon-app-worker${WORKER_NUM}"
  fi
done

echo ""
echo "📝 Generating Kubespray inventory..."

# Ensure inventory directory exists
mkdir -p ../inventory

# Generate Kubespray inventory in YAML format
cat > ../inventory/hosts.yaml <<EOF
all:
  hosts:
    control-plane:
      ansible_host: ${PUBLIC_IPS_ARRAY[0]}
      ip: ${PRIVATE_IPS_ARRAY[0]}
      access_ip: ${PRIVATE_IPS_ARRAY[0]}
EOF

# Add worker nodes (skip first instance which is control plane)
for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    WORKER_NUM=$i
    cat >> ../inventory/hosts.yaml <<EOF
    worker${WORKER_NUM}:
      ansible_host: ${PUBLIC_IPS_ARRAY[$i]}
      ip: ${PRIVATE_IPS_ARRAY[$i]}
      access_ip: ${PRIVATE_IPS_ARRAY[$i]}
EOF
  fi
done

# Add group definitions
cat >> ../inventory/hosts.yaml <<EOF
  children:
    kube_control_plane:
      hosts:
        control-plane:
    kube_node:
      hosts:
        control-plane:
EOF

# Add worker nodes to kube_node group
for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    WORKER_NUM=$i
    echo "        worker${WORKER_NUM}:" >> ../inventory/hosts.yaml
  fi
done

# Add etcd and other groups
cat >> ../inventory/hosts.yaml <<EOF
    etcd:
      hosts:
        control-plane:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/salon-key.pem
    ansible_become: true
    ansible_python_interpreter: /usr/bin/python3
EOF

echo "✓ Kubespray inventory generated at ../inventory/hosts.yaml"
echo ""
echo "Instance Summary:"
echo "  Control Plane: ${PUBLIC_IPS_ARRAY[0]} (${PRIVATE_IPS_ARRAY[0]})"
for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    WORKER_NUM=$i
    echo "  Worker${WORKER_NUM}: ${PUBLIC_IPS_ARRAY[$i]} (${PRIVATE_IPS_ARRAY[$i]})"
  fi
done
echo ""
echo "  Total nodes: ${#PUBLIC_IPS_ARRAY[@]}"
echo ""
echo "Next steps:"
echo "  1. Verify SSH key: ~/.ssh/salon-key.pem"
echo "  2. cd ../kubespray"
echo "  3. export ANSIBLE_CONFIG=$(cd .. && pwd)/ansible.cfg"
echo "  4. ansible-playbook -i ../inventory/hosts.yaml cluster.yml -b"
echo ""