output "talosconfig" {
  value     = local.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data to supply to other providers"
  value       = local.kubeconfig_data
  sensitive   = true
}

output "kube_api_url" {
  description = "Kubernetes API URL."
  value       = local.kubeconfig_data.host
}

output "control_plane_public_ipv4_list" {
  description = "Control plane public IPv4 addresses."
  value       = local.control_plane_public_ipv4_list
}

output "control_plane_private_ipv4_list" {
  description = "Control plane private IPv4 addresses."
  value       = local.control_plane_private_ipv4_list
}

output "external_worker_machine_configs" {
  description = "Machine configs for external workers. Use during initial node setup: talosctl apply-config --insecure --nodes <ip> --file <(terraform output -raw external_worker_machine_configs | jq -r '.\"<hostname>\"')"
  value       = { for k, v in data.talos_machine_configuration.external_worker : k => v.machine_configuration }
  sensitive   = true
}

output "control_plane_vip_ipv4" {
  description = "Private VIP for the control plane (alias IP). Set as cluster_api_host_private once Tailscale subnet routes are approved."
  value       = local.control_plane_private_vip_ipv4
}
