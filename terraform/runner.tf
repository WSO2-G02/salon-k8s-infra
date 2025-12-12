resource "aws_instance" "github_runner" {
  ami                         = var.ami_id
  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  security_groups             = [aws_security_group.runner_sg.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/runner_user_data.sh.tpl", {
    github_repo  = var.github_repo
    runner_token = var.runner_token
  })

  tags = {
    Name = "github-actions-kubespray-runner"
  }
}
