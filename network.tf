locals {
  network_public_ipv4_enabled = true
  network_public_ipv6_enabled = false

  hcloud_network_id   = hcloud_network.this.id
  hcloud_network_zone = data.hcloud_location.this.network_zone

  # Network ranges
  network_ipv4_cidr             = var.network_ipv4_cidr
  network_ipv4_cidr_prefix_size = tonumber(split("/", local.network_ipv4_cidr)[1])

  network_node_ipv4_cidr = cidrsubnet(local.network_ipv4_cidr, 3, 2)

  # Limit service IPs to a /12 or more specific CIDR to satisfy Kubernetes 1.33+ validation.
  network_service_ipv4_cidr_newbits = max(3, 12 - local.network_ipv4_cidr_prefix_size)
  network_service_ipv4_cidr_netnum  = 3 * pow(2, local.network_service_ipv4_cidr_newbits - 3)

  network_service_ipv4_cidr = cidrsubnet(
    local.network_ipv4_cidr,
    local.network_service_ipv4_cidr_newbits,
    local.network_service_ipv4_cidr_netnum
  )

  network_pod_ipv4_cidr            = cidrsubnet(local.network_ipv4_cidr, 1, 1)
  network_native_routing_ipv4_cidr = local.network_ipv4_cidr

  network_node_ipv4_cidr_skip_first_subnet = cidrhost(local.network_ipv4_cidr, 0) == cidrhost(local.network_node_ipv4_cidr, 0)
  network_ipv4_gateway                     = cidrhost(local.network_ipv4_cidr, 1)

  # Subnet mask sizes
  network_pod_ipv4_subnet_mask_size = 24
  network_node_ipv4_subnet_mask_size = (
    32 - (local.network_pod_ipv4_subnet_mask_size - split("/", local.network_pod_ipv4_cidr)[1])
  )

  # Lists for control plane nodes
  control_plane_public_ipv4_list  = compact(distinct([for server in hcloud_server.control_plane : server.ipv4_address]))
  control_plane_public_ipv6_list  = compact(distinct([for server in hcloud_server.control_plane : server.ipv6_address]))
  control_plane_private_ipv4_list = compact(distinct([for server in hcloud_server.control_plane : tolist(server.network)[0].ip]))

  # Lists for worker nodes
  worker_public_ipv4_list  = compact(distinct([for server in hcloud_server.worker : server.ipv4_address]))
  worker_public_ipv6_list  = compact(distinct([for server in hcloud_server.worker : server.ipv6_address]))
  worker_private_ipv4_list = compact(distinct([for server in hcloud_server.worker : tolist(server.network)[0].ip]))

  # Lists for cluster autoscaler nodes
  cluster_autoscaler_public_ipv4_list  = compact(distinct([for server in local.talos_discovery_cluster_autoscaler : server.public_ipv4_address]))
  cluster_autoscaler_public_ipv6_list  = compact(distinct([for server in local.talos_discovery_cluster_autoscaler : server.public_ipv6_address]))
  cluster_autoscaler_private_ipv4_list = compact(distinct([for server in local.talos_discovery_cluster_autoscaler : server.private_ipv4_address]))
}

data "hcloud_location" "this" {
  name = local.control_plane_nodepools[0].location
}

resource "hcloud_network" "this" {
  name              = var.cluster_name
  ip_range          = local.network_ipv4_cidr
  delete_protection = var.cluster_delete_protection

  labels = {
    cluster = var.cluster_name
  }
}

resource "hcloud_network_subnet" "control_plane" {
  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.hcloud_network_zone

  ip_range = cidrsubnet(
    local.network_node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1],
    0 + (local.network_node_ipv4_cidr_skip_first_subnet ? 1 : 0)
  )
}

resource "hcloud_network_subnet" "load_balancer" {
  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.hcloud_network_zone

  ip_range = cidrsubnet(
    local.network_node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1],
    1 + (local.network_node_ipv4_cidr_skip_first_subnet ? 1 : 0)
  )
}

resource "hcloud_network_subnet" "worker" {
  for_each = { for np in local.worker_nodepools : np.name => np }

  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.hcloud_network_zone

  ip_range = cidrsubnet(
    local.network_node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1],
    2 + (local.network_node_ipv4_cidr_skip_first_subnet ? 1 : 0) + index(local.worker_nodepools, each.value)
  )
}

resource "hcloud_network_subnet" "autoscaler" {
  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.hcloud_network_zone

  ip_range = cidrsubnet(
    local.network_node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1],
    pow(2, local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1]) - 1
  )

  depends_on = [
    hcloud_network_subnet.control_plane,
    hcloud_network_subnet.load_balancer,
    hcloud_network_subnet.worker
  ]
}
