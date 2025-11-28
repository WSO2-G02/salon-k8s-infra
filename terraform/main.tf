# The main infrastructure is defined here

# ECR repository
resource "aws_ecr_repository" "app" {
  name = var.project_name
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "AES256"
  }
}
