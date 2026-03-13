resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  # Keep the repository from growing unbounded with old images.
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_keep_last_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
