data "helm_template" "cilium" {
  name      = "cilium"
  namespace = "kube-system"

  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = "1.17.0"
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }
      routingMode           = "native"
      ipv4NativeRoutingCIDR = local.network_native_routing_ipv4_cidr

      # MTU 1350: conservative for Cilium + WireGuard overhead over Hetzner vSwitch (max 1400)
      MTU = 1350

      bpf = {
        masquerade        = true
        datapathMode      = "veth"
        hostLegacyRouting = false
      }
      encryption = {
        enabled = true
        type    = "wireguard"
      }
      k8s = {
        requireIPv4PodCIDR = true
      }
      k8sServiceHost                      = local.kube_prism_host
      k8sServicePort                      = local.kube_prism_port
      kubeProxyReplacement                = true
      kubeProxyReplacementHealthzBindAddr = "0.0.0.0:10256"
      installNoConntrackIptablesRules     = true
      socketLB = {
        hostNamespaceOnly = true
      }
      cgroup = {
        autoMount = { enabled = false }
        hostRoot  = "/sys/fs/cgroup"
      }
      securityContext = {
        capabilities = {
          ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }
      dnsProxy = {
        enableTransparentMode = true
      }
      egressGateway = {
        enabled = false
      }
      loadBalancer = {
        acceleration = "disabled"
      }
      gatewayAPI = {
        enabled = false
      }
      hubble = {
        enabled = false
        relay   = { enabled = false }
        ui      = { enabled = false }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled        = false
          trustCRDsExist = false
          interval       = "15s"
        }
      }
      operator = {
        nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
        replicas     = local.control_plane_sum > 1 ? 2 : 1
        podDisruptionBudget = {
          enabled        = true
          minAvailable   = null
          maxUnavailable = 1
        }
        topologySpreadConstraints = [
          {
            topologyKey       = "kubernetes.io/hostname"
            maxSkew           = 1
            whenUnsatisfiable = "DoNotSchedule"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name" = "cilium-operator"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          },
          {
            topologyKey       = "topology.kubernetes.io/zone"
            maxSkew           = 1
            whenUnsatisfiable = "ScheduleAnyway"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name" = "cilium-operator"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          }
        ]
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled  = false
            interval = "15s"
          }
        }
      }
    })
  ]
}

locals {
  cilium_manifest = {
    name     = "cilium"
    contents = data.helm_template.cilium.manifest
  }
}
