#!/bin/bash
set -e

# -----------------------------
# Install dependencies
# -----------------------------
apt-get update -y
apt-get install -y curl jq git sudo tar unzip

# -----------------------------
# Create runner directory
# -----------------------------
mkdir -p /actions-runner
cd /actions-runner

# -----------------------------
# Download & extract GitHub Runner
# -----------------------------
curl -o runner.tar.gz -L https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz
tar xzf runner.tar.gz

# -----------------------------
# Configure runner
# -----------------------------
./config.sh \
  --url https://github.com/${github_repo} \
  --token ${runner_token} \
  --labels "kubespray-runner" \
  --unattended \
  --replace

# -----------------------------
# Install and enable as systemd service
# -----------------------------
./svc.sh install
./svc.sh enable
./svc.sh start

# -----------------------------
# Logging
# -----------------------------
echo "GitHub runner setup complete at $(date)" >> /var/log/github-runner.log
