data "http" "talos_ccm" {
  url = "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/v0.6.2/docs/deploy/cloud-controller-manager-daemonset.yml"
}

locals {
  talos_ccm_manifest = {
    name     = "talos-cloud-controller-manager"
    contents = data.http.talos_ccm.response_body
  }
}
