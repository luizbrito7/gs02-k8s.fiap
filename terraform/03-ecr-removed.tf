# ECR movido para terraform/ecr/ (state próprio): aqui só sai do state, sem apagar.
removed {
  from = aws_ecr_repository.this
  lifecycle {
    destroy = false
  }
}
