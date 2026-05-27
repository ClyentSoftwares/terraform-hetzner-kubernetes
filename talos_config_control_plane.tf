locals {
  # Unused manifest locals — features not implemented in this module
  kube_api_oidc_configuration = {}
  longhorn_manifest            = null
  metrics_server_manifest      = null
  ingress_nginx_manifest       = null
  rbac_manifest                = null
  oidc_manifest                = null

  # Kubernetes Manifests for Talos
  talos_inline_manifests = concat(
    [local.hcloud_secret_manifest],
    [local.cilium_manifest],
    [local.hcloud_ccm_manifest],
    [local.hcloud_csi_manifest],
    [local.talos_ccm_manifest],
    local.talos_backup_manifest != null ? [local.talos_backup_manifest] : [],
    local.cluster_autoscaler_manifest != null ? [local.cluster_autoscaler_manifest] : [],
  )


  # Control Plane Config
  control_plane_talos_config_patches = {
    for node in hcloud_server.control_plane : node.name => concat(
      [
        {
          machine = {
            nodeLabels = merge(
              local.talos_allow_scheduling_on_control_planes ? { "node.kubernetes.io/exclude-from-external-load-balancers" = { "$patch" = "delete" } } : {},
              local.control_plane_nodepools_map[node.labels.nodepool].labels,
              { "nodeid" = tostring(node.id) }
            )
            nodeAnnotations = local.control_plane_nodepools_map[node.labels.nodepool].annotations
            nodeTaints = {
              for taint in local.control_plane_nodepools_map[node.labels.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
            }
            kubelet = {
              extraConfig = {
                registerWithTaints = local.control_plane_nodepools_map[node.labels.nodepool].taints
                systemReserved = {
                  cpu               = "250m"
                  memory            = "300Mi"
                  ephemeral-storage = "1Gi"
                }
                kubeReserved = {
                  cpu               = "250m"
                  memory            = "350Mi"
                  ephemeral-storage = "1Gi"
                }
              }
            }
            features = {
              kubernetesTalosAPIAccess = {
                enabled = true
                allowedRoles = [
                  "os:reader",
                  "os:etcd:backup"
                ]
                allowedKubernetesNamespaces = ["kube-system"]
              }
            }
          }
          cluster = {
            allowSchedulingOnControlPlanes = local.talos_allow_scheduling_on_control_planes
            coreDNS = {
              disabled = false
            }
            apiServer = {
              admissionControl = []
              certSANs         = local.talos_certificate_san
              extraArgs = merge(
                { "enable-aggregator-routing" = true },
                local.kube_api_oidc_configuration,
              )
            }
            controllerManager = {
              extraArgs = {
                "cloud-provider" = "external"
                "bind-address"   = "0.0.0.0"
              }
            }
            etcd = {
              advertisedSubnets = [hcloud_network_subnet.control_plane.ip_range]
              extraArgs = {
                "listen-metrics-urls" = "http://0.0.0.0:2381"
              }
            }
            scheduler = {
              extraArgs = {
                "bind-address" = "0.0.0.0"
              }
            }
            adminKubeconfig = {
              certLifetime = "87600h"
            }
            inlineManifests = local.talos_inline_manifests
            externalCloudProvider = {
              enabled   = true
              manifests = []
            }
          }
        },
        {
          apiVersion = "v1alpha1"
          kind       = "HostnameConfig"
          hostname   = node.name
          auto       = "off"
        }
      ],
    )
  }
}

data "talos_machine_configuration" "control_plane" {
  for_each = { for node in hcloud_server.control_plane : node.name => node }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_base_config_patches : yamlencode(patch)],
    [for patch in local.control_plane_talos_config_patches[each.key] : yamlencode(patch)],
  )
}
