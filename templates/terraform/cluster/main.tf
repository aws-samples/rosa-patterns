terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.20.0"
    }
    ocm = {
      version = ">= 0.1"
      source  = "openshift-online/ocm"
    }
  }
}

provider "ocm" {
  token = var.rosa_token
  url   = var.openshift_url
}

locals {
  sts_roles = {
    role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-Installer-Role",
    support_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-Support-Role",
    instance_iam_roles = {
      master_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-ControlPlane-Role",
      worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-Worker-Role"
    },
    operator_role_prefix = var.rosa_operator_role_prefix,
  }
}

data "aws_caller_identity" "current" {
}

resource "ocm_cluster_rosa_classic" "rosa_sts_cluster" {
  name               = var.rosa_cluster_name
  cloud_region       = var.aws_region
  aws_account_id     = data.aws_caller_identity.current.account_id
  availability_zones = var.aws_availability_zones
  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }
  sts = local.sts_roles
}
