output "talosconfig" {
  description = "Raw Talos OS configuration file used for cluster access and management."
  value       = local.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Raw kubeconfig file for authenticating with the Kubernetes cluster."
  value       = local.kubeconfig
  sensitive   = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data, suitable for use with other Terraform providers or tools."
  value       = local.kubeconfig_data
  sensitive   = true
}

output "talosconfig_data" {
  description = "Structured Talos configuration data, suitable for use with other Terraform providers or tools."
  value       = local.talosconfig_data
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Detailed configuration data for the Talos client."
  value       = data.talos_client_configuration.this
  sensitive   = true
}

output "talos_machine_secrets" {
  description = "Talos machine secrets, suitable for use with other Terraform providers or tools."
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

output "talos_machine_configurations_control_plane" {
  description = "Talos machine configurations for all control plane nodes."
  value       = data.talos_machine_configuration.control_plane
  sensitive   = true
}

output "talos_machine_configurations_worker" {
  description = "Talos machine configurations for all worker nodes."
  value       = data.talos_machine_configuration.worker
  sensitive   = true
}

output "control_plane_private_ipv4_list" {
  description = "List of private IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_private_ipv4_list
}

output "control_plane_public_ipv4_list" {
  description = "List of public IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_public_ipv4_list
}

output "worker_private_ipv4_list" {
  description = "List of private IPv4 addresses assigned to cloud worker nodes."
  value       = local.worker_private_ipv4_list
}

output "worker_public_ipv4_list" {
  description = "List of public IPv4 addresses assigned to cloud worker nodes."
  value       = local.worker_public_ipv4_list
}

output "dedicated_server_private_ipv4_list" {
  description = "List of private IPv4 addresses for dedicated (Robot) servers joined as workers."
  value       = local.dedicated_servers_private_ipv4_list
}

output "kube_api_url" {
  description = "External URL of the Kubernetes API server."
  value       = local.kube_api_url_external
}

output "kube_api_load_balancer" {
  description = "Details about the Kubernetes API load balancer."
  value = {
    id           = hcloud_load_balancer.kube_api.id
    name         = local.kube_api_load_balancer_name
    public_ipv4  = local.kube_api_load_balancer_public_ipv4
    private_ipv4 = local.kube_api_load_balancer_private_ipv4
  }
}
