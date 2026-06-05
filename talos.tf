resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

locals {
  api_port_k8s        = 6443
  api_port_kube_prism = 7445

  # Tailscale hostname/IP if provided; talosconfig and kubeconfig will use it as the endpoint
  cluster_api_host_private_explicit = var.cluster_api_host_private != null ? trimspace(var.cluster_api_host_private) : null

  default_cluster_api_host_private  = "kube.cluster.local"
  cluster_api_host_private_internal = coalesce(local.cluster_api_host_private_explicit, local.default_cluster_api_host_private)

  # Bootstrap over public IP — Tailscale isn't up yet and private IPs aren't reachable externally
  bootstrap_endpoint            = local.control_plane_public_ipv4_list[0]
  cluster_endpoint_internal     = local.cluster_api_host_private_internal
  cluster_endpoint_url_internal = "https://${local.cluster_endpoint_internal}:${local.api_port_k8s}"

  # Server IPs are intentionally excluded — they're only known after server creation
  # (cycle) and access is exclusively via Tailscale or the alias IP VIP hostname.
  cert_SANs = distinct(compact([
    local.default_cluster_api_host_private,
    local.cluster_api_host_private_internal,
    local.control_plane_private_vip_ipv4,
  ]))

  extra_host_entries = [{
    ip = local.control_plane_private_vip_ipv4
    aliases = distinct(compact([
      local.default_cluster_api_host_private,
      local.cluster_api_host_private_internal,
    ]))
  }]

}

data "talos_machine_configuration" "control_plane" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [
      yamlencode(local.controlplane_yaml[each.value.name]),
      yamlencode({
        apiVersion  = "v1alpha1"
        kind        = "ExtensionServiceConfig"
        name        = "tailscale"
        environment = compact([
          "TS_HOSTNAME=${each.key}",
          "TS_AUTHKEY=${var.tailscale.auth_key}",
          "TS_ROUTES=${var.network_ipv4_cidr}",
          length(var.tailscale.tags) > 0 ? "TS_EXTRA_ARGS=--advertise-tags=${join(",", [for t in var.tailscale.tags : "tag:${t}"])}" : "",
        ])
      }),
    ],
    local.talos_firewall_patches_base,
  )
  docs               = false
  examples           = false
}

data "talos_machine_configuration" "worker" {
  for_each           = { for server in local.worker_servers : server.name => server }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [
      yamlencode(local.worker_yaml[each.value.name]),
      yamlencode({
        apiVersion  = "v1alpha1"
        kind        = "ExtensionServiceConfig"
        name        = "tailscale"
        environment = compact([
          "TS_HOSTNAME=${each.key}",
          "TS_AUTHKEY=${var.tailscale.auth_key}",
          "TS_ROUTES=${var.network_ipv4_cidr}",
          length(var.tailscale.tags) > 0 ? "TS_EXTRA_ARGS=--advertise-tags=${join(",", [for t in var.tailscale.tags : "tag:${t}"])}" : "",
        ])
      }),
    ],
    local.talos_firewall_patches_base,
    local.talos_firewall_patches_worker,
  )
  docs               = false
  examples           = false
}

data "talos_machine_configuration" "external_worker" {
  for_each           = { for server in local.external_workers : server.hostname => server }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [
      yamlencode(local.external_worker_yaml[each.value.hostname]),
      yamlencode({
        apiVersion  = "v1alpha1"
        kind        = "ExtensionServiceConfig"
        name        = "tailscale"
        environment = compact([
          "TS_HOSTNAME=${each.key}",
          "TS_AUTHKEY=${var.tailscale.auth_key}",
          "TS_ROUTES=${var.network_ipv4_cidr}",
          length(var.tailscale.tags) > 0 ? "TS_EXTRA_ARGS=--advertise-tags=${join(",", [for t in var.tailscale.tags : "tag:${t}"])}" : "",
        ])
      }),
    ],
    local.talos_firewall_patches_base,
    local.talos_firewall_patches_worker,
  )
  docs     = false
  examples = false
}

# Pushes machine configuration to external workers that already have Talos installed.
# On first add: install bare Talos (talosctl apply-config --insecure), then run terraform apply.
# Subsequent terraform applies push config changes (firewall, kubespan, etc.) automatically.
resource "talos_machine_configuration_apply" "external_worker" {
  for_each                    = { for server in local.external_workers : server.hostname => server }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.external_worker[each.key].machine_configuration
  endpoint                    = each.value.public_ipv4
  node                        = each.value.public_ipv4
  apply_mode                  = "staged_if_needing_reboot"

  depends_on = [talos_machine_bootstrap.this]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.bootstrap_endpoint
  node                 = local.bootstrap_endpoint
  depends_on = [
    hcloud_server.control_plane
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = local.control_plane_public_ipv4_list
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_endpoint
  depends_on = [
    talos_machine_bootstrap.this
  ]
}

locals {
  # Tailscale hostname when set, else private VIP — kubeapi is never public
  kubeconfig_host = coalesce(local.cluster_api_host_private_explicit, local.control_plane_private_vip_ipv4)
  kubeconfig = replace(
    talos_cluster_kubeconfig.this.kubeconfig_raw,
    "https://${local.default_cluster_api_host_private}:${local.api_port_k8s}",
    "https://${local.kubeconfig_host}:${local.api_port_k8s}"
  )

  kubeconfig_data = {
    host                   = "https://${local.kubeconfig_host}:${local.api_port_k8s}"
    cluster_name           = var.cluster_name
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }

  talosconfig = data.talos_client_configuration.this.talos_config
}
