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

resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  for_each = toset(var.services)

  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire temporary scan images after 1 day"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["scan"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only last 10 production images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
