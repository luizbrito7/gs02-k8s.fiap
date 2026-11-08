terraform {
  required_version = ">= 1.16"
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 6.0" }
    http = { source = "hashicorp/http", version = "~> 3.6" }
  }
}

locals {
  project = "gs"
  env     = "lab"
  region  = "us-east-1"
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
