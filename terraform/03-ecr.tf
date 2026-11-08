resource "aws_ecr_repository" "this" {
  for_each = toset(["store-api", "store-worker", "store-front"])

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
