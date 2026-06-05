module "cluster" {
  source  = "ClyentSoftwares/kubernetes/hetzner"
  version = "0.2.0"

  cluster_name              = "rundown-staging"
  cluster_delete_protection = false

  hcloud_token = var.hcloud_token

  control_planes = [
    { name = "control-plane-1", type = "cx23", location = "ngb1", image = "talos-amd64" },
    { name = "control-plane-2", type = "cx23", location = "fsn1", image = "talos-amd64" },
    { name = "control-plane-3", type = "cx23", location = "fsn1", image = "talos-amd64" },
  ]

  workers = [
    { name = "worker", type = "cx23", location = "fsn1", image = "talos-amd64", count = 2 },
  ]

  tailscale = {
    auth_key = var.tailscale_auth_key
    tags     = ["k8s"]
  }

  imager_amd64_builder = {
    server_location = "fsn1"
  }

  # Optional: etcd backups to S3-compatible storage
  # talos_backup_s3 = {
  #   enabled    = true
  #   url        = "https://fsn1.your-objectstorage.com"
  #   bucket     = "my-talos-backups"
  #   region     = "auto"
  #   access_key = "your-access-key"
  #   secret_key = "your-secret-key"
  # }
}
