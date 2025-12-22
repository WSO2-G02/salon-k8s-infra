#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-salon-app}"
ASG_NAME="${2}"
EXPECTED_NODES="${3:-4}"

echo "⏳ Waiting for $EXPECTED_NODES EC2 instances in ASG: $ASG_NAME"

while true; do
  COUNT=$(aws ec2 describe-instances \
    --filters \
      "Name=tag:KubernetesCluster,Values=$CLUSTER_NAME" \
      "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output json | jq length)

  [ "$COUNT" -ge "$EXPECTED_NODES" ] && break
  sleep 10
done

echo "✅ Found $COUNT running instances"

# Fetch instance data
INSTANCES=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:KubernetesCluster,Values=$CLUSTER_NAME" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{id:InstanceId,ip:PrivateIpAddress}' \
  --output json)

CONTROL_PLANE=$(echo "$INSTANCES" | jq -r '.[0].ip')
WORKERS=$(echo "$INSTANCES" | jq -r '.[1:].[]?.ip')

INVENTORY_DIR="kubespray/inventory/mycluster"
mkdir -p "$INVENTORY_DIR"

cat > "$INVENTORY_DIR/hosts.yaml" <<EOF
all:
  hosts:
    control-plane:
      ansible_host: $CONTROL_PLANE
      ip: $CONTROL_PLANE
      access_ip: $CONTROL_PLANE
EOF

i=1
for ip in $WORKERS; do
cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
    worker$i:
      ansible_host: $ip
      ip: $ip
      access_ip: $ip
EOF
i=$((i+1))
done

cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
  children:
    kube_control_plane:
      hosts:
        control-plane:
    kube_node:
      hosts:
        control-plane:
EOF

for ((j=1;j<i;j++)); do
  echo "        worker$j:" >> "$INVENTORY_DIR/hosts.yaml"
done

cat >> "$INVENTORY_DIR/hosts.yaml" <<EOF
    etcd:
      hosts:
        control-plane:
    k8s_cluster:
      children:
        kube_control_plane
        kube_node
  vars:
    ansible_user: ubuntu
    ansible_become: true
    ansible_python_interpreter: /usr/bin/python3
EOF

echo "✓ Inventory generated at $INVENTORY_DIR/hosts.yaml"
