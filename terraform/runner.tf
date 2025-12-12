resource "aws_instance" "github_runner" {
  ami                         = var.ami_id
  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  security_groups             = [aws_security_group.runner_sg.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  user_data = filebase64("runner_user_data.sh")

  tags = {
    Name = "github-actions-kubespray-runner"
  }
}
