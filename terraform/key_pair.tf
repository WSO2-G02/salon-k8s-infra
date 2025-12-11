resource "aws_key_pair" "salon_key" {
  key_name   = "salon-key"
  public_key = file("${path.module}/salon-key.pub")

  tags = {
    Name    = "${var.project_name}-ssh-key"
    Project = var.project_tag
  }
}
