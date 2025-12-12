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

# Automatically update GitOps deployment files with ECR URLs
# This runs AFTER ECR repos are created and outputs are available
resource "null_resource" "update_ecr_urls" {
  depends_on = [aws_ecr_repository.repos]

  # Trigger on any ECR repository change
  triggers = {
    ecr_repos = jsonencode([for r in aws_ecr_repository.repos : r.repository_url])
  }

  provisioner "local-exec" {
    command     = "bash update_ecr_urls.sh || true"
    working_dir = path.module
    when        = create
  }
}
