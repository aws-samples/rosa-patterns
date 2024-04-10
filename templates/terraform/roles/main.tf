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
  url   = var.url
}

data "ocm_rosa_operator_roles" "operator_roles" {
  operator_role_prefix = var.operator_role_prefix
  account_role_prefix  = var.account_role_prefix
}

module "operator_roles" {
  source = "git::https://github.com/openshift-online/terraform-provider-ocm.git//modules/aws_roles?ref=f22aa6cb68ffcb598632cfbaabb1a8dff8140095"

  cluster_id                  = var.cluster_id
  rh_oidc_provider_thumbprint = var.oidc_thumbprint
  rh_oidc_provider_url        = var.oidc_endpoint_url
  operator_roles_properties   = data.ocm_rosa_operator_roles.operator_roles.operator_iam_roles
}
