<<<<<<< HEAD
variable "project_tag" {
  type    = string
  default = "salon-booking-system"
}

locals {
  services = [
    "user_service",
    "appointment_service",
    "service_managemnet",
    "staff_management",
    "notification_service",
    "reports_analytics",
    "frontend"
  ]
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(local.services)

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project = var.project_tag
    Service = each.key
  }
}

output "ecr_urls" {
  value = {
    for k, r in aws_ecr_repository.repos :
    k => r.repository_url
  }
}

=======
# ECR repository
resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "AES256"
  }
}
>>>>>>> 6fd1020d163047f3cd4852ece8531b3b2b1a62c8
