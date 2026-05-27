locals {
  # Talos and Kubernetes Certificates
  talos_certificate_san = sort(
    distinct(
      compact(
        concat(
          # Load Balancer IPs
          [
            local.kube_api_load_balancer_private_ipv4,
            local.kube_api_load_balancer_public_ipv4,
            local.kube_api_load_balancer_public_ipv6
          ],
          # Control Plane Node IPs
          local.control_plane_private_ipv4_list,
          local.control_plane_public_ipv4_list,
          local.control_plane_public_ipv6_list,
          # Loopback
          ["127.0.0.1", "::1", "localhost"],
        )
      )
    )
  )

  # Interface Configuration
  # Nodes always have a public interface (eth0) and a private interface (eth1)
  talos_public_link_name  = "eth0"
  talos_private_link_name = "eth1"

  # Talos Discovery — Kubernetes-based, service disabled
  talos_discovery = {
    enabled = true
    registries = {
      kubernetes = { disabled = false }
      service    = { disabled = true }
    }
  }

  # Host DNS
  talos_host_dns = {
    enabled              = true
    forwardKubeDNSToHost = false
    resolveMemberNames   = true
  }

  # Kubelet extra mounts — none by default
  talos_kubelet_extra_mounts = []

  # Public Network Link Config
  talos_public_link_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "LinkConfig"
      name       = local.talos_public_link_name
      up         = true
    }
  ]

  talos_public_dhcp_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "DHCPv4Config"
      name       = local.talos_public_link_name
    }
  ]

  # Private Network Link Config
  talos_private_link_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "LinkConfig"
      name       = local.talos_private_link_name
      up         = true
      routes     = []
    }
  ]

  talos_private_dhcp_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "DHCPv4Config"
      name       = local.talos_private_link_name
    }
  ]

  # Resolver (DNS)
  talos_resolver_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "ResolverConfig"
    nameservers = [
      { address = "1.1.1.1" },
      { address = "1.0.0.1" },
      { address = "8.8.8.8" },
    ]
  }

  # NTP
  talos_time_sync_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "TimeSyncConfig"
    ntp = {
      servers = ["time.cloudflare.com"]
    }
  }

  # Talos Base Config — applied to all nodes
  talos_base_config_patches = concat(
    [{
      machine = {
        install = {
          image           = local.talos_installer_image_url
          extraKernelArgs = []
        }
        certSANs = local.talos_certificate_san
        kubelet = {
          extraArgs = {
            "cloud-provider"             = "external"
            "rotate-server-certificates" = true
          }
          extraConfig = {
            shutdownGracePeriod             = "90s"
            shutdownGracePeriodCriticalPods = "15s"
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
    }],
    local.talos_public_link_config_patches,
    local.talos_public_dhcp_config_patches,
    local.talos_private_link_config_patches,
    local.talos_private_dhcp_config_patches,
    [local.talos_resolver_config_patch],
    [local.talos_time_sync_config_patch],
  )

  # Boot-time user_data (not needed for public cluster — private link config only applies in private mode)
  talos_user_data = null
}
