#!/bin/bash
set -e

# ================================
# Bootstrap EC2 Node for Kubernetes (Kubespray-compatible)
# ================================

# Detect OS
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
else
    OS="other"
fi

# -------------------------------
# 1. Base package setup
# -------------------------------
if [ "$OS" = "debian" ]; then
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y python3 python3-pip python3-venv \
                       docker.io curl wget git vim unzip sudo jq socat conntrack ipset
elif [ "$OS" = "rhel" ]; then
    yum update -y
    yum install -y python3 python3-pip python3-virtualenv \
                   docker curl wget git vim unzip sudo jq socat conntrack ipset
fi

systemctl enable docker
systemctl start docker

# Allow docker use
usermod -aG docker ubuntu 2>/dev/null || true
usermod -aG docker ec2-user 2>/dev/null || true


# -------------------------------
# 2. Ensure SSM Agent is installed & running
# -------------------------------
if [ "$OS" = "debian" ]; then
    # Ubuntu < 22 sometimes lacks SSM agent
    if ! systemctl status amazon-ssm-agent >/dev/null 2>&1; then
        snap install amazon-ssm-agent --classic
        systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
        systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    fi
else
    systemctl enable amazon-ssm-agent || true
    systemctl start amazon-ssm-agent || true
fi


# -------------------------------
# 3. Kubernetes prerequisites
# -------------------------------

# Disable swap — REQUIRED for Kubernetes
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Required kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl params required by Kubernetes networking
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system


# -------------------------------
# 4. Hostname with instance id
# -------------------------------
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
hostnamectl set-hostname k8s-node-${INSTANCE_ID}


# -------------------------------
# 5. Optional: passwordless sudo
# -------------------------------
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>/dev/null || true
echo "ec2-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>/dev/null || true


# -------------------------------
# 6. Minimal venv (Kubespray will install its own ansible version later)
# -------------------------------
python3 -m venv /opt/ansible-venv
source /opt/ansible-venv/bin/activate
pip install --upgrade pip
pip install ansible


# -------------------------------
# 7. Marker file for SSM provisioning detection
# -------------------------------
echo "READY_FOR_PROVISION" > /var/lib/k8s-node-status


# -------------------------------
# 8. Cleanup
# -------------------------------
apt-get clean 2>/dev/null || yum clean all
