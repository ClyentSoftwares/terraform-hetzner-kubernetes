# Hcloud Secret — includes Robot credentials for dedicated server support
locals {
  hcloud_secret_manifest = {
    name = "hcloud-secret"
    contents = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      type       = "Opaque"
      metadata = {
        name      = "hcloud"
        namespace = "kube-system"
      }
      data = {
        network        = base64encode(local.hcloud_network_id)
        token          = base64encode(var.hcloud_token)
        robot-user     = base64encode(var.robot_user)
        robot-password = base64encode(var.robot_password)
      }
    })
  }
}

# Hcloud CCM
data "helm_template" "hcloud_ccm" {
  name      = "hcloud-cloud-controller-manager"
  namespace = "kube-system"

  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-cloud-controller-manager"
  version      = "1.22.0"
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      kind         = "DaemonSet"
      nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
      networking = {
        enabled     = true
        clusterCIDR = local.network_pod_ipv4_cidr
      }
      robot = {
        enabled  = length(var.dedicated_servers) > 0
        user     = var.robot_user
        password = var.robot_password
      }
      env = {
        HCLOUD_LOAD_BALANCERS_ALGORITHM_TYPE          = { value = "round_robin" }
        HCLOUD_LOAD_BALANCERS_DISABLE_IPV6            = { value = "false" }
        HCLOUD_LOAD_BALANCERS_DISABLE_PRIVATE_INGRESS = { value = "false" }
        HCLOUD_LOAD_BALANCERS_DISABLE_PUBLIC_NETWORK  = { value = "true" }
        HCLOUD_LOAD_BALANCERS_ENABLED                 = { value = "false" }
        HCLOUD_LOAD_BALANCERS_HEALTH_CHECK_INTERVAL   = { value = "15s" }
        HCLOUD_LOAD_BALANCERS_HEALTH_CHECK_RETRIES    = { value = "3" }
        HCLOUD_LOAD_BALANCERS_HEALTH_CHECK_TIMEOUT    = { value = "10s" }
        HCLOUD_LOAD_BALANCERS_LOCATION                = { value = local.hcloud_load_balancer_location }
        HCLOUD_LOAD_BALANCERS_PRIVATE_SUBNET_IP_RANGE = { value = hcloud_network_subnet.load_balancer.ip_range }
        HCLOUD_LOAD_BALANCERS_TYPE                    = { value = "lb11" }
        HCLOUD_LOAD_BALANCERS_USE_PRIVATE_IP          = { value = "true" }
        HCLOUD_LOAD_BALANCERS_USES_PROXYPROTOCOL      = { value = "false" }
        HCLOUD_NETWORK_ROUTES_ENABLED                 = { value = "false" }
        KUBERNETES_SERVICE_HOST                       = { value = local.kube_prism_host }
        KUBERNETES_SERVICE_PORT                       = { value = tostring(local.kube_prism_port) }
      }
    })
  ]
}

locals {
  hcloud_ccm_manifest = {
    name     = "hcloud-ccm"
    contents = data.helm_template.hcloud_ccm.manifest
  }
}

# Hcloud CSI
resource "random_bytes" "hcloud_csi_encryption_key" {
  length = 32
}

locals {
  hcloud_csi_secret_manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "hcloud-csi-secret"
      namespace = "kube-system"
    }
    data = {
      encryption-passphrase = base64encode(random_bytes.hcloud_csi_encryption_key.hex)
    }
  }

  hcloud_csi_storage_classes = [
    {
      name                = "hcloud-volumes"
      reclaimPolicy       = "Delete"
      defaultStorageClass = true
      extraParameters     = {}
    }
  ]
}

data "helm_template" "hcloud_csi" {
  name      = "hcloud-csi"
  namespace = "kube-system"

  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-csi"
  version      = "2.12.0"
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      controller = {
        replicaCount = local.control_plane_sum > 1 ? 2 : 1
        podDisruptionBudget = {
          create         = true
          minAvailable   = null
          maxUnavailable = "1"
        }
        topologySpreadConstraints = [
          {
            topologyKey       = "kubernetes.io/hostname"
            maxSkew           = 1
            whenUnsatisfiable = "DoNotSchedule"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name"      = "hcloud-csi"
                "app.kubernetes.io/instance"  = "hcloud-csi"
                "app.kubernetes.io/component" = "controller"
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
                "app.kubernetes.io/name"      = "hcloud-csi"
                "app.kubernetes.io/instance"  = "hcloud-csi"
                "app.kubernetes.io/component" = "controller"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          }
        ]
        nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            effect   = "NoSchedule"
            operator = "Exists"
          }
        ]
        volumeExtraLabels = {}
      }
      storageClasses = local.hcloud_csi_storage_classes
    })
  ]
}

locals {
  hcloud_csi_manifest = {
    name = "hcloud-csi"
    contents = <<-EOF
      ${yamlencode(local.hcloud_csi_secret_manifest)}
      ---
      ${data.helm_template.hcloud_csi.manifest}
    EOF
  }
}
