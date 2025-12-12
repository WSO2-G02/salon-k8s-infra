locals {
  runner_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Basic tools
    apt-get update -y
    apt-get install -y curl jq git

    # Install GitHub Runner
    mkdir -p /actions-runner
    cd /actions-runner
    curl -o runner.tar.gz -L https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz
    tar xzf runner.tar.gz

    # Create runner service
    ./config.sh \
      --url https://github.com/${github_repo} \
      --token ${runner_token} \
      --labels "kubespray-runner" \
      --unattended \
      --replace

    ./svc.sh install
    ./svc.sh start
  EOF
}
