#!/bin/bash
# ================================
# Bootstrap EC2 Node for Kubernetes via Kubespray
# ================================

# Exit on any error
set -e

# -------------------------------
# 1. Update OS and install dependencies
# -------------------------------
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y python3 python3-pip python3-venv \
                       docker.io curl wget git vim unzip sudo
elif [ -f /etc/redhat-release ]; then
    # Amazon Linux / RHEL / CentOS
    yum update -y
    yum install -y python3 python3-pip python3-virtualenv \
                   docker curl wget git vim unzip sudo
fi

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add default user to docker group (adjust username if needed)
usermod -aG docker ubuntu || usermod -aG docker ec2-user

# -------------------------------
# 2. Configure hostname for identification
# -------------------------------
HOSTNAME_PREFIX="k8s-node"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
hostnamectl set-hostname ${HOSTNAME_PREFIX}-${INSTANCE_ID}

# -------------------------------
# 3. Ensure passwordless sudo for Kubespray
# -------------------------------
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>/dev/null || true
echo "ec2-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>/dev/null || true

# -------------------------------
# 4. Optional: Set up Python virtualenv for Ansible (Kubespray)
# -------------------------------
python3 -m venv /opt/ansible-venv
source /opt/ansible-venv/bin/activate
pip install --upgrade pip
pip install ansible

# -------------------------------
# 5. Cleanup
# -------------------------------
apt-get clean || yum clean all
