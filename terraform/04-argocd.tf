# Argo CD exposto por LoadBalancer liberado só para o IP de quem aplica.

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
        loadBalancerSourceRanges = ["${chomp(data.http.my_ip.response_body)}/32"]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "argocd.${local.domain}"
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
