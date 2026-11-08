# Faixas IPv4 da borda da Cloudflare: únicas origens aceitas no LB (o acesso passa pelo proxy)
data "http" "cloudflare_ips" {
  url = "https://api.cloudflare.com/client/v4/ips"
}

# Argo CD exposto por LoadBalancer atrás do proxy da Cloudflare (HTTPS na borda).
# O external-dns (instalado pelo próprio Argo) cria argocd.<domínio> a partir da annotation.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.15.0"
  namespace        = "argocd"
  create_namespace = true

  values = [yamlencode({
    server = {
      service = {
        type                     = "LoadBalancer"
        loadBalancerSourceRanges = jsondecode(data.http.cloudflare_ips.response_body).result.ipv4_cidrs
        annotations = {
          "external-dns.kubernetes.io/hostname"               = "argocd.${local.domain}"
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb" # NLB em vez do Classic LB padrão
        }
      }
    }
  })]

  depends_on = [module.eks]
}

# App of apps: o Argo CD passa a gerenciar tudo que estiver em k8s/apps/
resource "helm_release" "argocd_root" {
  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      root = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = local.repo
          targetRevision = "main"
          path           = "k8s/apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}

output "argocd_url" {
  value = "https://argocd.${local.domain}"
}

output "argocd_admin_password" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
