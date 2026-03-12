terraform {
    required_version = ">= 1.5.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = var.aws_region
}

variable "aws_region" {
    type    = string
    default = "ap-south-1"
}

variable "cluster_name" {
    type    = string
    default = "ci-eks-cluster"
}

variable "vpc_cidr" {
    type    = string
    default = "10.0.0.0/16"
}

data "aws_availability_zones" "available" {
    state = "available"
}

locals {
    azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "~> 5.0"

    name = "${var.cluster_name}-vpc"
    cidr = var.vpc_cidr

    azs             = local.azs
    private_subnets = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]
    public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 48)]

    enable_nat_gateway = false

    public_subnet_tags = {
        "kubernetes.io/role/elb" = "1"
    }

    private_subnet_tags = {
        "kubernetes.io/role/internal-elb" = "1"
    }

    tags = {
        Environment = "dev"
        Terraform   = "true"
    }
}

module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "~> 20.0"

    cluster_name    = var.cluster_name
    cluster_version = "1.29"

    cluster_endpoint_public_access           = true
    enable_cluster_creator_admin_permissions = true

    vpc_id     = module.vpc.vpc_id
    # Use public subnets to avoid NAT gateway requirements for node egress.
    subnet_ids = module.vpc.public_subnets

    eks_managed_node_groups = {
        default = {
            instance_types = ["t3.small"]
            min_size       = 1
            max_size       = 1
            desired_size   = 1
            capacity_type  = "ON_DEMAND"
        }
    }

    tags = {
        Environment = "dev"
        Terraform   = "true"
    }
}

output "cluster_name" {
    value = module.eks.cluster_name
}

output "cluster_endpoint" {
    value = module.eks.cluster_endpoint
}