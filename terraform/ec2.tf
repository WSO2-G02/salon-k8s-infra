resource "aws_instance" "services" {
  for_each = toset(var.services)

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = element(aws_subnet.public[*].id, 0) # round-robin or choose AZ

  tags = {
    Name    = "${each.key}-instance"
    Project = var.project_tag
  }
}
