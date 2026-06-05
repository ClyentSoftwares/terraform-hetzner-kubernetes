locals {
  # Expand each nodepool into individual server instances
  control_plane_servers = [
    for np in local.control_planes : {
      name        = np.name
      nodepool    = np.name
      server_type = np.server_type
      location    = np.location
      image       = np.image
    }
  ]

  worker_servers = flatten([
    for np in local.workers : [
      for i in range(np.count) : {
        name                = "${np.name}-${i + 1}"
        nodepool            = np.name
        index               = i
        server_type         = np.server_type
        location            = np.location
        image               = np.image
        placement_group_key = np.placement_group ? "${var.cluster_name}-${np.name}-pg-${floor(i / 10) + 1}" : null
        labels              = np.labels
        taints              = np.taints
      }
    ]
  ])
}

resource "hcloud_server" "control_plane" {
  for_each           = { for s in local.control_plane_servers : s.name => s }
  name               = each.value.name
  server_type        = each.value.server_type
  location           = each.value.location
  image              = each.value.image == "talos-arm64" ? imager_image.arm64[0].id : imager_image.amd64[0].id
  user_data          = data.talos_machine_configuration.control_plane[each.value.nodepool].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.control_plane.id
  delete_protection  = var.cluster_delete_protection

  labels = {
    cluster  = var.cluster_name
    role     = "control-plane"
    nodepool = each.value.nodepool
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.this.id
    alias_ips  = [] # fix for https://github.com/hetznercloud/terraform-provider-hcloud/issues/650
  }

  depends_on = [
    hcloud_network_subnet.control_plane,
    data.talos_machine_configuration.control_plane,
  ]

  lifecycle {
    ignore_changes = [user_data, image, network]
  }
}

resource "hcloud_server" "worker" {
  for_each           = { for s in local.worker_servers : s.name => s }
  name               = each.value.name
  server_type        = each.value.server_type
  location           = each.value.location
  image              = each.value.image == "talos-arm64" ? imager_image.arm64[0].id : imager_image.amd64[0].id
  user_data          = data.talos_machine_configuration.worker[each.value.name].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = each.value.placement_group_key != null ? hcloud_placement_group.worker[each.value.placement_group_key].id : null
  delete_protection  = var.cluster_delete_protection

  labels = {
    cluster  = var.cluster_name
    role     = "worker"
    nodepool = each.value.nodepool
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.this.id
    alias_ips  = [] # fix for https://github.com/hetznercloud/terraform-provider-hcloud/issues/650
  }

  depends_on = [
    hcloud_network_subnet.worker,
    data.talos_machine_configuration.worker,
  ]

  lifecycle {
    ignore_changes = [user_data, image, network]
  }
}
