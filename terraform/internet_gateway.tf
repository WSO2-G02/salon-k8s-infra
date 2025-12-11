resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_tag
  }
}
