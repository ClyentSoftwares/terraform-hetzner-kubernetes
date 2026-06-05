locals {
  # Generate YAML per external (dedicated) worker.
  # Omits HCloud-specific settings (VIP, private network interface, nodeIP subnet restriction).
  # MTU 1420 = dedicated server MTU 1500 minus KubeSpan WireGuard overhead 80.
  external_worker_yaml = {
    for server in local.external_workers : server.hostname => {
      machine = {
        install = {
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
          extraKernelArgs = [
            "talos.hostname=${server.hostname}"
          ]
        }
        certSANs = local.cert_SANs
        kubelet = merge(
          {
            extraArgs = {
              "cloud-provider"             = "external"
              "rotate-server-certificates" = true
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
            mtu                         = 1420 # Dedicated server MTU 1500 - 80 WireGuard overhead
          }
        }
        features = {
          hostDNS = {
            enabled              = true
            forwardKubeDNSToHost = true
            resolveMemberNames   = true
          }
        }
        nodeLabels = server.labels
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
