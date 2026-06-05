locals {
  # Generate YAML for all control planes
  controlplane_yaml = {
    for control_plane in local.control_planes : control_plane.name => {
      machine = {
        install = {
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
          extraKernelArgs = [
            "talos.hostname=${control_plane.name}"
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
          # Add registerWithTaints if taints are defined
          length(control_plane.taints) > 0 ? {
            extraConfig = {
              registerWithTaints = [
                for taint in control_plane.taints : {
                  key    = taint.key
                  value  = taint.value
                  effect = taint.effect
                }
              ]
            }
          } : {}
        )
        nodeLabels = merge(
          control_plane.labels,
          local.worker_count == 0 ? {
            "node.kubernetes.io/exclude-from-external-load-balancers" = {
              "$patch" = "delete"
            }
          } : {}
        )
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
            },
            {
              interface = "eth1"
              dhcp      = true
              vip = {
                ip = local.control_plane_private_vip_ipv4
                hcloud = {
                  apiToken = var.hcloud_token
                }
              }
            }
          ]
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
          kubernetesTalosAPIAccess = {
            enabled = true
            allowedRoles = [
              "os:reader",
              "os:etcd:backup"
            ]
            allowedKubernetesNamespaces = [
              "kube-system"
            ]
          }
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
        registries = {}
      }
      cluster = {
        allowSchedulingOnControlPlanes = local.talos_allow_scheduling_on_control_planes
        network = {
          dnsDomain = "cluster.local"
          podSubnets = [
            local.network_pod_ipv4_cidr
          ]
          serviceSubnets = [
            local.network_service_ipv4_cidr
          ]
          cni = {
            name = "none"
          }
        }
        coreDNS = {
          disabled = false
        }
        proxy = {
          disabled = true
        }
        apiServer = {
          certSANs = local.cert_SANs
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        controllerManager = {
          extraArgs = {
            "cloud-provider"           = "external"
            "node-cidr-mask-size-ipv4" = local.network_node_ipv4_subnet_mask_size
            "bind-address" : "0.0.0.0"
          }
        }
        etcd = {
          advertisedSubnets = [
            local.network_node_ipv4_cidr
          ]
          extraArgs = {
            "listen-metrics-urls" = "http://0.0.0.0:2381"
          }
        }
        scheduler = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        extraManifests = [
          "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/${var.talos_ccm_version}/docs/deploy/cloud-controller-manager-daemonset.yml"
        ]
        inlineManifests = concat(
          [
            {
              name     = "hcloud-secret"
              contents = <<-EOT
                apiVersion: v1
                kind: Secret
                type: Opaque
                metadata:
                  name: hcloud
                  namespace: kube-system
                data:
                  network: ${base64encode(tostring(hcloud_network.this.id))}
                  token: ${base64encode(var.hcloud_token)}
              EOT
            },
          ],
          local.talos_backup_manifest != null ? [local.talos_backup_manifest] : [],
        )
      }
    }
  }
}
