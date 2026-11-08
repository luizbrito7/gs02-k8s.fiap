data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "vpc-${local.project}-${local.env}"
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = cidrsubnets("10.0.0.0/16", 4, 4, 4)
  public_subnets  = cidrsubnets("10.0.48.0/20", 4, 4, 4)

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
