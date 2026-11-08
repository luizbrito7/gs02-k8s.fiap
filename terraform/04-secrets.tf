# Segredos que não podem ir para o Git: criados aqui, valores só no state local.
variable "cloudflare_api_token" {
  description = "Token da Cloudflare com Zone:Read e DNS:Edit na zona do domínio"
  type        = string
  sensitive   = true
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "kubernetes_namespace_v1" "this" {
  for_each = {
    store-prod   = { "pod-security.kubernetes.io/enforce" = "restricted" }
    store-data   = { "pod-security.kubernetes.io/enforce" = "baseline" }
    external-dns = {}
    cert-manager = {}
  }

  metadata {
    name   = each.key
    labels = each.value
  }

  depends_on = [module.eks]
}

resource "kubernetes_secret_v1" "db" {
  for_each = toset(["store-prod", "store-data"])

  metadata {
    name      = "store-db-credentials"
    namespace = kubernetes_namespace_v1.this[each.key].metadata[0].name
  }
  data = { password = random_password.db.result }
}

resource "kubernetes_secret_v1" "cloudflare" {
  for_each = toset(["external-dns", "cert-manager"])

  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace_v1.this[each.key].metadata[0].name
  }
  data = { api-token = var.cloudflare_api_token }
}
