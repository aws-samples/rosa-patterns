variable "openshift_url" {
  type    = string
  default = "https://api.openshift.com"
}

variable "rosa_token" {
  type      = string
  sensitive = true
}

variable "rosa_operator_role_prefix" {
  type = string
}


variable "rosa_cluster_name" {
  type = string
}

variable "rosa_account_role_prefix" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "aws_availability_zones" {
  type    = list(string)
  default = ["ap-southeast-2a"]
}

