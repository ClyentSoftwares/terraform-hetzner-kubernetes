
# Cluster

variable "cluster_name" {
  type        = string
  description = "Cluster name used to label all resources."

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must start/end with a lowercase letter or number, may contain hyphens, max 32 chars."
  }
}

variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token."
}

variable "cluster_delete_protection" {
  type        = bool
  default     = true
  description = "Enable delete protection on HCloud resources."
}

# Nodes


variable "control_planes" {
  type = list(object({
    name     = string
    type     = string
    location = string
    image    = string
  }))
  description = "Control plane nodes."

  validation {
    condition     = alltrue([for np in var.control_planes : contains(["talos-amd64", "talos-arm64"], np.image)])
    error_message = "Each control plane image must be \"talos-amd64\" or \"talos-arm64\"."
  }
}

variable "workers" {
  type = list(object({
    name     = string
    type     = string
    location = string
    count    = number
    image    = string
    labels   = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default     = []
  description = "Cloud worker node pools."

  validation {
    condition     = alltrue([for np in var.workers : contains(["talos-amd64", "talos-arm64"], np.image)])
    error_message = "Each worker image must be \"talos-amd64\" or \"talos-arm64\"."
  }
}

variable "external_workers" {
  type = list(object({
    hostname    = string
    public_ipv4 = string
    labels      = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default     = []
  description = "External servers not running on Hetzner cloud (such as Hetzner dedicated servers). Talos must already be installed on these servers before running terraform apply."
}

# Network 

variable "network_ipv4_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Main HCloud network IPv4 CIDR."
}

# Cillium

variable "cilium_version" {
  type        = string
  default     = "1.19.4"
  description = <<EOF
    The version of Cilium to deploy. If not set, the `1.19.4` version will be used.
    Needs to be compatible with the `kubernetes_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
  EOF
}

# Talos

variable "talos_backup_s3" {
  type = object({
    enabled    = optional(bool, false)
    url        = optional(string)
    bucket     = optional(string)
    region     = optional(string, "auto")
    access_key = optional(string, "")
    secret_key = optional(string, "")
  })
  default     = {}
  sensitive   = true
  description = "etcd backup to S3-compatible storage. Set enabled = true and supply all fields to activate."

  validation {
    condition = !var.talos_backup_s3.enabled || (
      var.talos_backup_s3.bucket != null &&
      var.talos_backup_s3.url != null &&
      var.talos_backup_s3.access_key != "" &&
      var.talos_backup_s3.secret_key != ""
    )
    error_message = "talos_backup_s3: bucket, url, access_key, and secret_key must all be set when enabled = true."
  }
}


# Imager
variable "imager_amd64_builder" {
  type = object({
    server_type     = optional(string, "cx23")
    server_location = optional(string, "nbg1")
  })
  default     = {}
  description = "Temporary server used by terraform-provider-imager to upload the Talos AMD64 snapshot."
}

variable "imager_arm64_builder" {
  type = object({
    server_type     = optional(string, "cax11")
    server_location = optional(string, "nbg1")
  })
  default     = {}
  description = "Temporary server used by terraform-provider-imager to upload the Talos ARM64 snapshot. Only used when any nodepool has image = \"talos-arm64\"."
}

# Versions
variable "talos_version" {
  type        = string
  default     = "v1.13.3"
  description = "Talos OS version."
}

variable "kubernetes_version" {
  type        = string
  default     = "v1.33.12"
  description = "Kubernetes version."
}


variable "hcloud_ccm_version" {
  type        = string
  default     = "1.31.1"
  description = "The version of the Hetzner Cloud Controller Manager to deploy. If not set, the latest version will be used."
}

variable "talos_ccm_version" {
  type        = string
  default     = "v1.6.0"
  description = "The version of the Talos Cloud Controller Manager to deploy."
}

# Tailscale

variable "tailscale" {
  type = object({
    auth_key = string
    tags     = optional(list(string), [])
  })
  description = "Tailscale credential for joining nodes to your tailnet on boot. Accepts either an auth key (tskey-auth-xxx, max 90-day expiry) or an OAuth client secret (tskey-client-xxx, no expiry). OAuth client secrets require tags to be set (passed as TS_TAGS to the extension) and the client to have the auth_keys:write scope. Set tags to enable subnet auto-approval via Tailscale ACL autoApprovers."
}

variable "cluster_api_host_private" {
  type        = string
  default     = null
  description = "Tailscale hostname or IP for the cluster API endpoint. Used in talosconfig/kubeconfig and added to cert SANs. If unset, falls back to the alias-IP internal hostname."
}
