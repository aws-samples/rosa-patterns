output "cluster_id" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.id
}

output "api_url" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.api_url
}

output "console_url" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.console_url
}

output "current_version" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.current_version
}

output "domain" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.domain
}

output "state" {
  value = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.state
}
