resource "aws_ecr_repository" "repos" {
  for_each = toset(var.services)

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
  
  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Project = var.project_tag
    Service = each.key
  }
}
