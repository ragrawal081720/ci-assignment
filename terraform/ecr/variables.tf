variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region for ECR"
}

variable "ecr_repository_name" {
  type        = string
  default     = "ci-assignment"
  description = "Name of the ECR repository to create"
}

variable "ecr_image_tag_mutability" {
  type        = string
  default     = "MUTABLE"
  description = "Image tag mutability for the repository (MUTABLE or IMMUTABLE)"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "ecr_scan_on_push" {
  type        = bool
  default     = true
  description = "Enable vulnerability scanning when images are pushed"
}

variable "ecr_keep_last_images" {
  type        = number
  default     = 20
  description = "How many images to retain in ECR"

  validation {
    condition     = var.ecr_keep_last_images > 0
    error_message = "ecr_keep_last_images must be greater than 0."
  }
}
