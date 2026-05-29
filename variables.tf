# ─── Required ─────────────────────────────────────────────────────────────────

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

# ─── Node Topology ─────────────────────────────────────────────────────────────

variable "control_plane_nodepools" {
  type = list(object({
    name     = string
    type     = string
    location = string
    count    = number
  }))
  description = "Control plane node pools."
}

variable "worker_nodepools" {
  type = list(object({
    name     = string
    type     = string
    location = string
    count    = number
  }))
  default     = []
  description = "Cloud worker node pools."
}

variable "dedicated_servers" {
  type = list(object({
    hostname          = string
    vswitch_id        = number
    private_ipv4      = string
    network_interface = string
    labels            = optional(map(string), {})
    annotations       = optional(map(string), {})
    taints            = optional(list(string), [])
  }))
  default     = []
  description = "Hetzner Robot dedicated servers to join as workers via vSwitch. Talos must already be installed on these servers before running terraform apply."
}

variable "cluster_autoscaler_nodepools" {
  type = list(object({
    name     = string
    type     = string
    location = string
    min      = number
    max      = number
  }))
  default     = []
  description = "Cluster autoscaler node pools."
}

variable "allow_scheduling_on_control_planes" {
  type        = bool
  default     = null
  description = "Explicitly allow scheduling on control plane nodes. Defaults to true when no workers exist, false otherwise."
}

# ─── Cluster Behaviour ────────────────────────────────────────────────────────

variable "cluster_delete_protection" {
  type        = bool
  default     = true
  description = "Enable delete protection on HCloud resources."
}

# ─── Packer ───────────────────────────────────────────────────────────────────

variable "packer_amd64_builder" {
  type = object({
    server_type     = optional(string, "cx23")
    server_location = optional(string, "nbg1")
  })
  default     = {}
  description = "Configuration for the temporary server used when building the Talos AMD64 image with Packer."

  validation {
    condition = contains([
      "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
    ], var.packer_amd64_builder.server_location)
    error_message = "packer_amd64_builder.server_location must be one of: fsn1, nbg1, hel1, ash, hil, sin."
  }
}

variable "packer_arm64_builder" {
  type = object({
    server_type     = optional(string, "cax11")
    server_location = optional(string, "nbg1")
  })
  default     = {}
  description = "Configuration for the temporary server used when building the Talos ARM64 image with Packer. Only used when cax* (Ampere ARM64) server types are present in any nodepool."

  validation {
    condition = contains([
      "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
    ], var.packer_arm64_builder.server_location)
    error_message = "packer_arm64_builder.server_location must be one of: fsn1, nbg1, hel1, ash, hil, sin."
  }
}

# ─── Versioning ───────────────────────────────────────────────────────────────

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

# ─── Network ──────────────────────────────────────────────────────────────────

variable "network_ipv4_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Main HCloud network IPv4 CIDR."
}

# ─── Firewall ─────────────────────────────────────────────────────────────────

variable "firewall_kube_api_source" {
  type        = list(string)
  default     = null
  description = "Source CIDRs allowed to reach the Kubernetes API. Null auto-detects the current public IP."
}

variable "firewall_talos_api_source" {
  type        = list(string)
  default     = null
  description = "Source CIDRs allowed to reach the Talos API. Null auto-detects the current public IP."
}

# ─── Robot Credentials ────────────────────────────────────────────────────────

variable "robot_user" {
  type      = string
  default   = ""
  sensitive = true
  description = "Hetzner Robot username for dedicated server management via HCCM."
}

variable "robot_password" {
  type      = string
  default   = ""
  sensitive = true
  description = "Hetzner Robot password for dedicated server management via HCCM."
}

# ─── Talos Backup ─────────────────────────────────────────────────────────────

variable "talos_backup_s3_enabled" {
  type        = bool
  default     = false
  description = "Enable etcd backup CronJob to HCloud Object Storage."
}

variable "talos_backup_s3_hcloud_url" {
  type        = string
  default     = null
  description = "HCloud Object Storage URL (e.g. https://bucket.region.your-objectstorage.com). Bucket and region are parsed automatically."
}

variable "talos_backup_s3_access_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "S3 access key for etcd backup storage."
}

variable "talos_backup_s3_secret_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "S3 secret key for etcd backup storage."
}
