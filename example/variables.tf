variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "tailscale_auth_key" {
  type      = string
  sensitive = true
}

variable "talos_backup_s3" {
  type = object({
    enabled    = optional(bool, false)
    url        = optional(string)
    bucket     = optional(string)
    region     = optional(string, "auto")
    access_key = optional(string, "")
    secret_key = optional(string, "")
  })
  default   = {}
  sensitive = true
}
