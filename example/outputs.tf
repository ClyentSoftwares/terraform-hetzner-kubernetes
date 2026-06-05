output "talosconfig" {
  description = "Talos client configuration file."
  value       = module.cluster.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes kubeconfig file."
  value       = module.cluster.kubeconfig
  sensitive   = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data."
  value       = module.cluster.kubeconfig_data
  sensitive   = true
}

output "kube_api_url" {
  description = "Kubernetes API URL."
  value       = module.cluster.kube_api_url
}

output "control_plane_public_ipv4_list" {
  description = "Control plane public IPv4 addresses."
  value       = module.cluster.control_plane_public_ipv4_list
}

output "control_plane_private_ipv4_list" {
  description = "Control plane private IPv4 addresses."
  value       = module.cluster.control_plane_private_ipv4_list
}

output "control_plane_vip_ipv4" {
  description = "Private VIP for the control plane. Use as cluster_api_host_private once Tailscale subnet routes are approved."
  value       = module.cluster.control_plane_vip_ipv4
}
