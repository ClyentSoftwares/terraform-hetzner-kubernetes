locals {
  # Subnets granted unrestricted inbound access — covers all cluster-internal traffic
  # including kubelet, kube API (via private VIP), etcd, CNI, and Tailscale-tunnelled traffic.
  talos_fw_trusted_cidrs = [
    local.network_ipv4_cidr, # HCloud VPC — encompasses node, pod, and service ranges
    "100.64.0.0/10",         # Tailscale CGNAT — kube API access via Tailscale
  ]

  talos_firewall_patches_base = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkDefaultActionConfig"
      ingress    = "block"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "talos-api"
      portSelector = {
        ports    = [50000]
        protocol = "tcp"
      }
      ingress = [{ subnet = "0.0.0.0/0" }]
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "kubespan-wireguard"
      portSelector = {
        ports    = [51820]
        protocol = "udp"
      }
      ingress = [{ subnet = "0.0.0.0/0" }]
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "tailscale-wireguard"
      portSelector = {
        ports    = [41641]
        protocol = "udp"
      }
      ingress = [{ subnet = "0.0.0.0/0" }]
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "cluster-internal-tcp"
      portSelector = {
        ports    = ["1-65535"]
        protocol = "tcp"
      }
      ingress = [for cidr in local.talos_fw_trusted_cidrs : { subnet = cidr }]
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "cluster-internal-udp"
      portSelector = {
        ports    = ["1-65535"]
        protocol = "udp"
      }
      ingress = [for cidr in local.talos_fw_trusted_cidrs : { subnet = cidr }]
    }),
  ]

  talos_firewall_patches_worker = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "http"
      portSelector = {
        ports    = [80]
        protocol = "tcp"
      }
      ingress = [{ subnet = "0.0.0.0/0" }]
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "https"
      portSelector = {
        ports    = [443]
        protocol = "tcp"
      }
      ingress = [{ subnet = "0.0.0.0/0" }]
    }),
  ]
}
