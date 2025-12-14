#!/bin/bash
set -e

# -----------------------------
# Variables
# -----------------------------
DESIRED_CAPACITY=${1:-4}  # default to 4 if not passed

# -----------------------------
# Wait for ASG instances to be ready
# -----------------------------
COUNT=0
ASG_NAME=$(terraform output -raw asg_name)  
echo "⏳ Waiting for ASG instances to be running..."
while [ $COUNT -lt $DESIRED_CAPACITY ]; do
  sleep 10
  COUNT=$(aws ec2 describe-instances \
    --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output json | jq length)
done

echo "✅ All $COUNT instances are running."

# -----------------------------
# Fetch Terraform outputs
# -----------------------------
TF_OUTPUT=$(terraform output -json)
PUBLIC_IPS=$(echo "$TF_OUTPUT" | jq -r '.instance_public_ips // empty | .[]')
PRIVATE_IPS=$(echo "$TF_OUTPUT" | jq -r '.instance_private_ips // empty | .[]')
INSTANCE_IDS=$(echo "$TF_OUTPUT" | jq -r '.instance_ids // empty | .[]')

PUBLIC_IPS_ARRAY=($PUBLIC_IPS)
PRIVATE_IPS_ARRAY=($PRIVATE_IPS)
INSTANCE_IDS_ARRAY=($INSTANCE_IDS)

# -----------------------------
# Rename EC2 instances
# -----------------------------
echo "🏷️  Renaming EC2 instances..."
for i in "${!INSTANCE_IDS_ARRAY[@]}"; do
  if [ $i -eq 0 ]; then
    aws ec2 create-tags \
      --resources "${INSTANCE_IDS_ARRAY[$i]}" \
      --tags Key=Name,Value=salon-app-control-plane Key=K8sRole,Value=control-plane
  else
    aws ec2 create-tags \
      --resources "${INSTANCE_IDS_ARRAY[$i]}" \
      --tags Key=Name,Value=salon-app-worker${i} Key=K8sRole,Value=worker
  fi
done

# -----------------------------
# Generate Kubespray inventory
# -----------------------------
INVENTORY_DIR="../kubespray/inventory/mycluster"
mkdir -p "$INVENTORY_DIR/group_vars"

# Control plane
cat > "$INVENTORY_DIR/hosts.yaml" <<EOF
all:
  hosts:
    control-plane:
      ansible_host: ${PUBLIC_IPS_ARRAY[0]}
      ip: ${PRIVATE_IPS_ARRAY[0]}
      access_ip: ${PRIVATE_IPS_ARRAY[0]}
EOF

# Worker nodes
for i in "${!PUBLIC_IPS_ARRAY[@]}"; do
  if [ $i -gt 0 ]; then
    echo "    worker${i}:" >> "$INVENTORY_DIR/hosts.yaml"
    echo "      ansible_host: ${PUBLIC_IPS_ARRAY[$i]}" >> "$INVENTORY_DIR/hosts.yaml"
    echo "      ip: ${PRIVATE_IPS_ARRAY[$i]}" >> "$INVENTORY_DIR/hosts.yaml"
    echo "      access_ip: ${PRIVATE_IPS_ARRAY[$i]}" >> "$INVENTORY_DIR/hosts.yaml"
  fi
done

# Groups and vars
cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
  children:
    kube_control_plane:
      hosts:
        control-plane
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
