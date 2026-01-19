provider "aws" {
  region = "TEMPLATE_REGION_NAME"
  profile = "TEMPLATE_PROFILE"
  assume_role {
        role_arn     = "TEMPLATE_ADMIN_ROLE"
    }
}

terraform {
  required_version = ">= 0.12.0"
}


provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "TEMPLATE_CLUSTER_NAME"
}

resource "random_string" "suffix" {
  length  = 3
  special = false
}

