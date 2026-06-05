locals {
  talos_schematic_id        = talos_image_factory_schematic.this.id
  talos_installer_image_url = data.talos_image_factory_urls.amd64.urls.installer

  all_nodepools        = concat(local.control_planes, local.workers)
  amd64_image_required = anytrue([for np in local.all_nodepools : np.image == "talos-amd64"])
  arm64_image_required = anytrue([for np in local.all_nodepools : np.image == "talos-arm64"])

  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/lvm2",
    "siderolabs/tailscale",
  ]
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = local.talos_image_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info.*.name
        }
      }
    }
  )
}

data "talos_image_factory_urls" "amd64" {
  talos_version = var.talos_version
  schematic_id  = local.talos_schematic_id
  platform      = "hcloud"
  architecture  = "amd64"
}

data "talos_image_factory_urls" "arm64" {
  talos_version = var.talos_version
  schematic_id  = local.talos_schematic_id
  platform      = "hcloud"
  architecture  = "arm64"
}

resource "imager_image" "amd64" {
  count        = local.amd64_image_required ? 1 : 0
  image_url    = data.talos_image_factory_urls.amd64.urls.disk_image
  architecture = "x86"
  location     = var.imager_amd64_builder.server_location
  server_type  = var.imager_amd64_builder.server_type
  labels = {
    os                 = "talos"
    cluster            = var.cluster_name
    talos_version      = var.talos_version
    talos_schematic_id = substr(local.talos_schematic_id, 0, 32)
  }
}

resource "imager_image" "arm64" {
  count        = local.arm64_image_required ? 1 : 0
  image_url    = data.talos_image_factory_urls.arm64.urls.disk_image
  architecture = "arm"
  location     = var.imager_arm64_builder.server_location
  server_type  = var.imager_arm64_builder.server_type
  labels = {
    os                 = "talos"
    cluster            = var.cluster_name
    talos_version      = var.talos_version
    talos_schematic_id = substr(local.talos_schematic_id, 0, 32)
  }
}
