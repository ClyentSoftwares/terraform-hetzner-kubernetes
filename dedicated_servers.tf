# Dedicated Servers (Hetzner Robot)
# This file manages dedicated bare-metal servers joining the cluster as workers via vSwitch.
#
# Talos must be pre-installed on the server before running terraform apply.
# To install Talos manually: put the server in Hetzner Robot rescue mode, then:
#   dd if=talos-hcloud-amd64.raw of=/dev/sda bs=4M status=progress
#   reboot
# Once Talos is booted (in maintenance mode), terraform apply will push the machine config.

locals {
  # Normalize dedicated servers with computed fields
  dedicated_servers_normalized = [
    for s in var.dedicated_servers : {
      hostname          = s.hostname
      vswitch_id        = s.vswitch_id
      private_ipv4      = s.private_ipv4
      network_interface = s.network_interface
      labels = merge(
        s.labels,
        { "node.kubernetes.io/dedicated-server" = "true" }
      )
      annotations = s.annotations
      taints = [for taint in s.taints : regex(
        "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
        taint
      )]
    }
  ]

  # Map for lookups
  dedicated_servers_map = {
    for s in local.dedicated_servers_normalized : s.hostname => s
  }

  # IP lists for health checks and access data
  dedicated_servers_private_ipv4_list      = [for s in local.dedicated_servers_normalized : s.private_ipv4]
  dedicated_servers_talos_private_ipv4_list = [for s in local.dedicated_servers_normalized : s.private_ipv4]

  # Group by vSwitch ID for subnet creation (keys must be strings)
  dedicated_servers_by_vswitch = {
    for s in local.dedicated_servers_normalized :
    tostring(s.vswitch_id) => s...
  }

  # Alias for talos.tf (all dedicated servers use Talos)
  dedicated_servers_talos = local.dedicated_servers_normalized

  # System disk encryption — not used; Robot nodes use volume-level encryption if needed
  talos_system_disk_encryption = null

  # Extra host entries — none by default
  talos_extra_host_entries = []
}


# ─── vSwitch Subnets ──────────────────────────────────────────────────────────
# Create one vSwitch-type subnet per unique vSwitch ID

resource "hcloud_network_subnet" "dedicated_vswitch" {
  for_each = local.dedicated_servers_by_vswitch

  network_id   = local.hcloud_network_id
  type         = "vswitch"
  network_zone = local.hcloud_network_zone
  vswitch_id   = tonumber(each.key)

  # Allocate from the end of the node CIDR range (before autoscaler subnet)
  ip_range = cidrsubnet(
    local.network_node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1],
    pow(2, local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1]) - 2 - index(keys(local.dedicated_servers_by_vswitch), each.key)
  )

  depends_on = [
    hcloud_network_subnet.control_plane,
    hcloud_network_subnet.load_balancer,
    hcloud_network_subnet.worker
  ]
}


# ─── Talos Configuration ──────────────────────────────────────────────────────

locals {
  dedicated_server_talos_config_patch = {
    for s in local.dedicated_servers_normalized : s.hostname => {
      machine = {
        install = {
          disk  = "/dev/sda"
          image = local.talos_installer_image_url
        }
        nodeLabels      = s.labels
        nodeAnnotations = s.annotations
        certSANs        = local.talos_certificate_san
        network = {
          hostname = s.hostname
          interfaces = [{
            interface = s.network_interface
            addresses = ["${s.private_ipv4}/${local.network_node_ipv4_subnet_mask_size}"]
            mtu       = 1350
            routes = [{
              network = local.network_ipv4_cidr
              gateway = local.network_ipv4_gateway
            }]
          }]
          nameservers      = ["1.1.1.1", "1.0.0.1", "8.8.8.8"]
          extraHostEntries = local.talos_extra_host_entries
        }
        kubelet = {
          extraArgs = {
            "cloud-provider"             = "external"
            "rotate-server-certificates" = true
          }
          extraConfig = {
            shutdownGracePeriod             = "90s"
            shutdownGracePeriodCriticalPods = "15s"
            registerWithTaints              = s.taints
            systemReserved = {
              cpu               = "100m"
              memory            = "300Mi"
              ephemeral-storage = "1Gi"
            }
            kubeReserved = {
              cpu               = "100m"
              memory            = "350Mi"
              ephemeral-storage = "1Gi"
            }
          }
          extraMounts = local.talos_kubelet_extra_mounts
          nodeIP = {
            validSubnets = [local.network_node_ipv4_cidr]
          }
        }
        kernel = {
          modules = []
        }
        sysctls = {
          "net.core.somaxconn"                 = "65535"
          "net.core.netdev_max_backlog"        = "4096"
          "net.ipv6.conf.default.disable_ipv6" = "1"
          "net.ipv6.conf.all.disable_ipv6"     = "1"
        }
        registries = {}
        features = {
          hostDNS = local.talos_host_dns
        }
        time = {
          servers = ["time.cloudflare.com"]
        }
        logging = {
          destinations = []
        }
      }
      cluster = {
        network = {
          dnsDomain      = "cluster.local"
          podSubnets     = [local.network_pod_ipv4_cidr]
          serviceSubnets = [local.network_service_ipv4_cidr]
          cni            = { name = "none" }
        }
        proxy = {
          disabled = true
        }
        discovery = local.talos_discovery
      }
    }
  }
}

# Generate Talos machine configurations for dedicated servers
data "talos_machine_configuration" "dedicated_server" {
  for_each = { for s in local.dedicated_servers_normalized : s.hostname => s }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = [yamlencode(local.dedicated_server_talos_config_patch[each.key])]
}

# Apply Talos configuration to dedicated servers
# Talos must already be running (maintenance mode) on the server before this runs.
resource "talos_machine_configuration_apply" "dedicated_server" {
  for_each = { for s in local.dedicated_servers_normalized : s.hostname => s }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.dedicated_server[each.key].machine_configuration
  endpoint                    = each.value.private_ipv4
  node                        = each.value.private_ipv4
  apply_mode                  = "auto"

  # Never reset dedicated servers on destroy — they are external physical machines.
  # No on_destroy block: provider default is graceful=false, reset=false, reboot=false.

  depends_on = [
    hcloud_network_subnet.dedicated_vswitch,
    terraform_data.upgrade_kubernetes,
    talos_machine_configuration_apply.worker
  ]
}
