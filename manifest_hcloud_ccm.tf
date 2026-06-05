data "helm_template" "hcloud_ccm" {
  name         = "hcloud-cloud-controller-manager"
  namespace    = "kube-system"
  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-cloud-controller-manager"
  version      = var.hcloud_ccm_version
  kube_version = var.kubernetes_version

  values = [yamlencode({
    networking = {
      # KubeSpan handles node to node networking so we can disable the CCM's internal networking management
      enabled = false
    }
    env = {
      HCLOUD_LOAD_BALANCERS_ENABLED = { value = "false" }
      HCLOUD_NETWORK_ROUTES_ENABLED = { value = "false" }
    }
    tolerations = [
      {
        key      = "node-role.kubernetes.io/control-plane"
        effect   = "NoSchedule"
        operator = "Exists"
      },
      {
        key      = "node.cloudprovider.kubernetes.io/uninitialized"
        effect   = "NoSchedule"
        value    = "true"
        operator = "Equal"
      }
    ]
  })]
}

data "kubectl_file_documents" "hcloud_ccm" {
  content = data.helm_template.hcloud_ccm.manifest
}

resource "kubectl_manifest" "hcloud_ccm" {
  for_each   = data.kubectl_file_documents.hcloud_ccm.manifests
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health]
}
