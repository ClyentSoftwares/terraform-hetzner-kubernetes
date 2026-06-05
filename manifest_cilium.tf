data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  values = [yamlencode({
    operator = {
      replicas = local.control_plane_count > 1 ? 2 : 1
    }
    ipam = {
      mode = "kubernetes"
    }
    routingMode           = "native"
    ipv4NativeRoutingCIDR = local.network_pod_ipv4_cidr
    kubeProxyReplacement  = true
    bpf = {
      masquerade = false
      # eBPF host routing bypasses the kernel routing table and conflicts with KubeSpan
      # see more: https://docs.siderolabs.com/talos/v1.13/networking/kubespan#cilium-compatibility-limitations
      hostLegacyRouting = true
    }
    loadBalancer = {
      # Wireguard (Tailscale and Kubespan) does not support XDP and therefore native fails.
      # see more: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#loadbalancer-nodeport-xdp-acceleration
      acceleration = "disabled"
    }
    encryption = {
      enabled = false
    }
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }
    k8sServiceHost = "127.0.0.1"
    k8sServicePort = local.api_port_kube_prism
    hubble = {
      enabled = false
    }
  })]
}

data "kubectl_file_documents" "cilium" {
  content = data.helm_template.cilium.manifest
}

resource "kubectl_manifest" "cilium" {
  for_each   = data.kubectl_file_documents.cilium.manifests
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health]
}
