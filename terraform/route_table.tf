resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  depends_on = [
    aws_subnet.public,
    aws_subnet.private
  ]

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

#comment