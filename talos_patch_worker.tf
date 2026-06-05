locals {
  # Generate YAML per cloud worker instance
  worker_yaml = {
    for server in local.worker_servers : server.name => {
      machine = {
        install = {
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
          extraKernelArgs = [
            "talos.hostname=${server.name}"
          ]
        }
        certSANs = local.cert_SANs
        kubelet = merge(
          {
            extraArgs = {
              "cloud-provider"             = "external"
              "rotate-server-certificates" = true
            }
            nodeIP = {
              validSubnets = [
                local.network_node_ipv4_cidr
              ]
            }
          },
          length(server.taints) > 0 ? {
            extraConfig = {
              registerWithTaints = [
                for taint in server.taints : {
                  key    = taint.key
                  value  = taint.value
                  effect = taint.effect
                }
              ]
            }
          } : {}
        )
        network = {
          extraHostEntries = local.extra_host_entries
          kubespan = {
            enabled                     = true
            advertiseKubernetesNetworks = true
            mtu                         = 1370 # Hcloud MTU 1450 - 80 WireGuard overhead
          }
        }
        kernel = {
          modules = []
        }
        sysctls = {
          "net.core.somaxconn"          = "65535"
          "net.core.netdev_max_backlog" = "4096"
        }
        features = {
          hostDNS = {
            enabled              = true
            forwardKubeDNSToHost = true
            resolveMemberNames   = true
          }
        }
        time = {
          servers = [
            "ntp1.hetzner.de",
            "ntp2.hetzner.com",
            "ntp3.hetzner.net",
            "time.cloudflare.com"
          ]
        }
        nodeLabels = server.labels
        registries = {}
      }
      cluster = {
        network = {
          dnsDomain      = "cluster.local"
          podSubnets     = [local.network_pod_ipv4_cidr]
          serviceSubnets = [local.network_service_ipv4_cidr]
          cni            = { name = "none" }
        }
      }
    }
  }
}
