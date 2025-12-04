# Public subnets
resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-${each.key}"
    Project = var.project_tag
    Tier    = "public"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  for_each   = toset(var.private_subnets)
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value

  tags = {
    Name    = "${var.project_name}-private-${each.key}"
    Project = var.project_tag
    Tier    = "private"
  }
}
