terraform {
  required_version = ">= 1.16"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    http       = { source = "hashicorp/http", version = "~> 3.6" }
    helm       = { source = "hashicorp/helm", version = "~> 3.3" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.5" }
    random     = { source = "hashicorp/random", version = "~> 3.9" }
  }
}

locals {
  project = "gs"
  env     = "lab"
  region  = "us-east-1"
  domain  = "luizbrito6.com.br"
  repo    = "https://github.com/luizbrito7/gs02-k8s.fiap.git"

  # autenticação no cluster recém-criado via token do EKS
  k8s_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region, "--profile", "delta"]
  }
}

provider "aws" {
  profile = "delta"
  region  = local.region

  default_tags {
    tags = {
      Project   = local.project
      Env       = local.env
      ManagedBy = "terraform"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = local.k8s_exec.api_version
    command     = local.k8s_exec.command
    args        = local.k8s_exec.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec                   = local.k8s_exec
  }
}
