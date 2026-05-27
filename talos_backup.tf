locals {
  # Parse bucket/region from HCloud Object Storage URL
  # e.g. https://mybucket.fsn1.your-objectstorage.com → bucket=mybucket, region=fsn1
  talos_backup_s3_hcloud   = var.talos_backup_s3_hcloud_url != null ? regex("^(?:https?://)?(?P<bucket>[^.]+)\\.(?P<region>[^.]+)\\.your-objectstorage\\.com\\.?$", var.talos_backup_s3_hcloud_url) : {}
  talos_backup_s3_bucket   = var.talos_backup_s3_hcloud_url != null ? local.talos_backup_s3_hcloud.bucket : null
  talos_backup_s3_region   = var.talos_backup_s3_hcloud_url != null ? local.talos_backup_s3_hcloud.region : null
  talos_backup_s3_endpoint = var.talos_backup_s3_hcloud_url != null ? "https://${local.talos_backup_s3_region}.your-objectstorage.com" : null

  talos_backup_service_account = {
    apiVersion = "talos.dev/v1alpha1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "talos-backup-secrets"
      namespace = "kube-system"
    }
    spec = {
      roles = [
        "os:etcd:backup"
      ]
    }
  }

  talos_backup_s3_secrets = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "talos-backup-s3-secrets"
      namespace = "kube-system"
    }
    type = "Opaque"
    data = {
      access_key = base64encode(var.talos_backup_s3_access_key)
      secret_key = base64encode(var.talos_backup_s3_secret_key)
    }
  }

  talos_backup_cronjob = {
    apiVersion = "batch/v1"
    kind       = "CronJob"
    metadata = {
      name      = "talos-backup"
      namespace = "kube-system"
    }
    spec = {
      schedule          = "0 */6 * * *"
      suspend           = local.talos_backup_s3_bucket == null
      concurrencyPolicy = "Forbid"
      jobTemplate = {
        spec = {
          template = {
            spec = {
              containers = [{
                name            = "talos-backup"
                image           = "ghcr.io/siderolabs/talos-backup:latest"
                workingDir      = "/tmp"
                imagePullPolicy = "IfNotPresent"
                env = [
                  { name = "AWS_ACCESS_KEY_ID", valueFrom = { secretKeyRef = { name = "talos-backup-s3-secrets", key = "access_key" } } },
                  { name = "AWS_SECRET_ACCESS_KEY", valueFrom = { secretKeyRef = { name = "talos-backup-s3-secrets", key = "secret_key" } } },
                  { name = "AGE_X25519_PUBLIC_KEY", value = null },
                  { name = "DISABLE_ENCRYPTION", value = "true" },
                  { name = "AWS_REGION", value = local.talos_backup_s3_region },
                  { name = "CUSTOM_S3_ENDPOINT", value = local.talos_backup_s3_endpoint },
                  { name = "BUCKET", value = local.talos_backup_s3_bucket },
                  { name = "CLUSTER_NAME", value = var.cluster_name },
                  { name = "S3_PREFIX", value = "" },
                  { name = "USE_PATH_STYLE", value = "true" },
                  { name = "ENABLE_COMPRESSION", value = "true" }
                ]
                volumeMounts = [
                  { name = "tmp", mountPath = "/tmp" },
                  { name = "talos-secrets", mountPath = "/var/run/secrets/talos.dev" }
                ]
                resources = {
                  requests = { memory = "128Mi", cpu = "250m" }
                  limits   = { memory = "256Mi", cpu = "500m" }
                }
                securityContext = {
                  runAsUser                = 1000
                  runAsGroup               = 1000
                  allowPrivilegeEscalation = false
                  runAsNonRoot             = true
                  capabilities             = { drop = ["ALL"] }
                  seccompProfile           = { type = "RuntimeDefault" }
                }
              }]
              restartPolicy = "OnFailure"
              volumes = [
                { emptyDir = {}, name = "tmp" },
                { name = "talos-secrets", secret = { secretName = "talos-backup-secrets" } }
              ]
              tolerations = [
                { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
              ]
            }
          }
        }
      }
    }
  }

  talos_backup_manifest = var.talos_backup_s3_enabled ? {
    name = "talos-backup"
    contents = <<-EOF
      ${yamlencode(local.talos_backup_service_account)}
      ---
      ${yamlencode(local.talos_backup_s3_secrets)}
      ---
      ${yamlencode(local.talos_backup_cronjob)}
    EOF
  } : null
}
