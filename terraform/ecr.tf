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

# ECR Lifecycle Policy for Frontend (has staging-* and production images)
resource "aws_ecr_lifecycle_policy" "frontend_cleanup_policy" {
  repository = aws_ecr_repository.repos["frontend"].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 production images (excludes staging-*)"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*-*"] # Matches {sha}-{timestamp} pattern
          countType      = "imageCountMoreThan"
          countNumber    = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Lifecycle Policy for Backend services (simpler - no staging prefix)
resource "aws_ecr_lifecycle_policy" "backend_cleanup_policy" {
  for_each = toset([for s in var.services : s if s != "frontend"])

  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
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
