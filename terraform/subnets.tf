data "aws_availability_zones" "available" {
  state = "available"
  exclude_names = ["us-east-1e"]
}

# Public subnets
resource "aws_subnet" "public" {
  for_each                = { for idx, cidr in var.public_subnets : idx => cidr }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[each.key]
  map_public_ip_on_launch = true


  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Name    = "${var.project_name}-public-${each.key + 1}"
    Project = var.project_tag
    Tier    = "public"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  for_each   = { for idx, cidr in var.private_subnets : idx => cidr }
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value
  availability_zone = data.aws_availability_zones.available.names[each.key]

  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Name    = "${var.project_name}-private-${each.key + 1}"
    Project = var.project_tag
    Tier    = "private"
  }
}
