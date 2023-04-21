output "cluster_data" {
  value = ocm_cluster_rosa_classic.rosa_sts_cluster
}

output "rosa_account_role_prefix" {
  value = var.rosa_account_role_prefix
}
