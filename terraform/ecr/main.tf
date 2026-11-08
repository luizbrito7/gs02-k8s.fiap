# State separado: o ECR sobrevive ao destroy do cluster (terraform/), e as imagens não se perdem.
terraform {
  required_version = ">= 1.16"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  profile = "delta"
  region  = "us-east-1"

  default_tags {
    tags = {
      Project   = "gs"
      Env       = "lab"
      ManagedBy = "terraform"
    }
  }
}

locals {
  repos = toset(["store-api", "store-worker", "store-front"])
}

# repositórios já existentes, criados antes no state principal
import {
  for_each = local.repos
  to       = aws_ecr_repository.this[each.key]
  id       = each.key
}

resource "aws_ecr_repository" "this" {
  for_each = local.repos

  name                 = each.key
  image_tag_mutability = "IMMUTABLE" # tag publicada não é sobrescrita
  force_delete         = true        # destroy apaga mesmo com imagens

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_registry" {
  value = split("/", aws_ecr_repository.this["store-api"].repository_url)[0]
}
