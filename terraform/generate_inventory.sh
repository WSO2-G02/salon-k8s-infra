#!/bin/bash
set -e

# -----------------------------
# Fetch Terraform outputs
# -----------------------------
TF_OUTPUT=$(terraform output -json)

PUBLIC_IPS=$(echo "$TF_OUTPUT" | jq -r '.instance_public_ips // empty | .[]')
PRIVATE_IPS=$(echo "$TF_OUTPUT" | jq -r '.instance_private_ips // empty | .[]')
INSTANCE_IDS=$(echo "$TF_OUTPUT" | jq -r '.instance_ids // empty | .[]')

# Convert to arrays
PUBLIC_IPS_ARRAY=($PUBLIC_IPS)
PRIVATE_IPS_ARRAY=($PRIVATE_IPS)
INSTANCE_IDS_ARRAY=($INSTANCE_IDS)

# Check for at least one instance
if [ ${#PUBLIC_IPS_ARRAY[@]} -lt 1 ]; then
  echo "Error: No running EC2 instances found. Are ASG nodes ready?"
  exit 1
fi

echo "🏷️  Renaming EC2 instances..."

for i in "${!INSTANCE_IDS_ARRAY[@]}"; do
  if [ $i -eq 0 ]; then
    aws ec2 create-tags \
      --resources "${INSTANCE_IDS_ARRAY[$i]}" \
      --tags Key=Name,Value=salon-app-control-plane Key=K8sRole,Value=control-plane
    echo "  ✓ ${INSTANCE_IDS_ARRAY[$i]} → salon-app-control-plane"
  else
    WORKER_NUM=$i
    aws ec2 create-tags \
      --resources "${INSTANCE_IDS_ARRAY[$i]}" \
      --tags Key=Name,Value=salon-app-worker${WORKER_NUM} Key=K8sRole,Value=worker
    echo "  ✓ ${INSTANCE_IDS_ARRAY[$i]} → salon-app-worker${WORKER_NUM}"
  fi
done

echo ""
echo "📝 Generating Kubespray inventory..."

INVENTORY_DIR="../kubespray/inventory/mycluster"
mkdir -p "$INVENTORY_DIR/group_vars"

# Start YAML
cat > "$INVENTORY_DIR/hosts.yaml" <<EOF
all:
  hosts:
    control-plane:
      ansible_host: ${PUBLIC_IPS_ARRAY[0]}
      ip: ${PRIVATE_IPS_ARRAY[0]}
      access_ip: ${PRIVATE_IPS_ARRAY[0]}
EOF

# Add worker nodes
for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    WORKER_NUM=$i
    cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
    worker${WORKER_NUM}:
      ansible_host: ${PUBLIC_IPS_ARRAY[$i]}
      ip: ${PRIVATE_IPS_ARRAY[$i]}
      access_ip: ${PRIVATE_IPS_ARRAY[$i]}
EOF
  fi
done

# Groups
cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
  children:
    kube_control_plane:
      hosts:
        control-plane:
    kube_node:
      hosts:
        control-plane
EOF

for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    echo "        worker${i}:" >> "$INVENTORY_DIR/hosts.yaml"
  fi
done

cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
    etcd:
      hosts:
        control-plane
    k8s_cluster:
      children:
        kube_control_plane
        kube_node
    calico_rr:
      hosts: {}
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/salon-key.pem
    ansible_become: true
    ansible_python_interpreter: /usr/bin/python3
EOF

echo "✓ Kubespray inventory generated at $INVENTORY_DIR/hosts.yaml"
echo ""
echo "Instance Summary:"
echo "  Control Plane: ${PUBLIC_IPS_ARRAY[0]} (${PRIVATE_IPS_ARRAY[0]})"
for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    echo "  Worker${i}: ${PUBLIC_IPS_ARRAY[$i]} (${PRIVATE_IPS_ARRAY[$i]})"
  fi
done
echo ""
echo "  Total nodes: ${#PUBLIC_IPS_ARRAY[@]}"
echo ""
echo "Next steps:"
echo "  1. Verify SSH key: ~/.ssh/salon-key.pem"
echo "  2. cd ../kubespray"
echo "  3. ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b"
echo ""
