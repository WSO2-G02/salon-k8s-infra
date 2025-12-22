#!/bin/bash
set -e

# -----------------------------
# Install dependencies
# -----------------------------
apt-get update -y
apt-get install -y curl jq git sudo tar unzip

# -----------------------------
# Create runner directory and switch to ubuntu user
# -----------------------------
sudo -u ubuntu mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# -----------------------------
# Download & extract GitHub Runner
# -----------------------------
sudo -u ubuntu curl -o runner.tar.gz -L https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz
sudo -u ubuntu tar xzf runner.tar.gz

# -----------------------------
# Configure runner
# -----------------------------
sudo -u ubuntu ./config.sh \
  --url https://github.com/${github_repo} \
  --token ${runner_token} \
  --labels "kubespray-runner" \
  --unattended \
  --replace

# -----------------------------
# Install and enable as systemd service
# -----------------------------
sudo ./svc.sh install
sudo ./svc.sh enable
sudo ./svc.sh start

# -----------------------------
# Logging
# -----------------------------
echo "GitHub runner setup complete at $(date)" >> /var/log/github-runner.log
