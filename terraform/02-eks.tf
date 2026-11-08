# IP público de quem roda o apply: único liberado no endpoint do EKS
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = "eks-${local.project}-${local.env}"
  kubernetes_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = ["${chomp(data.http.my_ip.response_body)}/32"]
  enable_cluster_creator_admin_permissions = true

  enable_irsa       = false # sem OIDC: permissões de Pod via Pod Identity
  encryption_config = null  # sem KMS para os Secrets

  enabled_log_types           = [] # sem logs do control plane no CloudWatch
  create_cloudwatch_log_group = false

  addons = {
    vpc-cni = {
      before_compute       = true
      configuration_values = jsonencode({ enableNetworkPolicy = "true" }) # sem isto, NetworkPolicy é ignorada
    }
    eks-pod-identity-agent = { before_compute = true }
    coredns                = {}
    kube-proxy             = {}
    metrics-server         = {}
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"] # máx. 17 Pods por nó: 5 nós dão folga para drenar um deles
      min_size       = 5
      desired_size   = 5
      max_size       = 6
    }
  }
}

# role IAM só do service account do EBS CSI
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.10"

  name                      = "ebs-csi-${local.project}-${local.env}"
  attach_aws_ebs_csi_policy = true
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --profile delta --region ${local.region} --name ${module.eks.cluster_name}"
}
