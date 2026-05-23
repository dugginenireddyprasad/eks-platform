# terraform/environments/dev/main.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "s3" {
    bucket         = "eks-platform-tfstate-dev"   # replace with your bucket name
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "eks-platform-tfstate-lock"  # replace with your DynamoDB table
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "eks-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devops"
    }
  }
}

# ── VPC ──────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  name             = "${var.project}-${var.environment}"
  cidr             = var.vpc_cidr
  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  environment      = var.environment
  cluster_name     = local.cluster_name
}

# ── EKS ──────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  environment        = var.environment

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      disk_size      = 20
    }
  }

  depends_on = [module.vpc]
}

# ── ECR ──────────────────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  repositories = ["eks-platform-app"]
  environment  = var.environment
}

# ── IAM (IRSA roles) ─────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  cluster_name            = local.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  oidc_provider_url       = module.eks.oidc_provider_url
  environment             = var.environment

  depends_on = [module.eks]
}

locals {
  cluster_name = "${var.project}-${var.environment}"
}
