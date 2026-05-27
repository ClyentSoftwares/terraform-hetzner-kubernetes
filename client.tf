locals {
  talosconfig = data.talos_client_configuration.this.talos_config

  kubeconfig_data = {
    name   = var.cluster_name
    server = local.kube_api_url_external
    ca     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    cert   = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    key    = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }

  talosconfig_data = {
    name      = data.talos_client_configuration.this.cluster_name
    endpoints = data.talos_client_configuration.this.endpoints
    ca        = base64decode(data.talos_client_configuration.this.client_configuration.ca_certificate)
    cert      = base64decode(data.talos_client_configuration.this.client_configuration.client_certificate)
    key       = base64decode(data.talos_client_configuration.this.client_configuration.client_key)
  }

  kubeconfig = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [
      {
        name = local.kubeconfig_data.name
        cluster = {
          server                     = local.kubeconfig_data.server
          certificate-authority-data = base64encode(local.kubeconfig_data.ca)
        }
      }
    ]
    contexts = [
      {
        name = "admin@${local.kubeconfig_data.name}"
        context = {
          cluster   = local.kubeconfig_data.name
          namespace = "default"
          user      = "admin@${local.kubeconfig_data.name}"
        }
      }
    ]
    current-context = "admin@${local.kubeconfig_data.name}"
    users = [
      {
        name = "admin@${local.kubeconfig_data.name}"
        user = {
          client-certificate-data = base64encode(local.kubeconfig_data.cert)
          client-key-data         = base64encode(local.kubeconfig_data.key)
        }
      }
    ]
  })
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.talos_endpoints
  nodes                = [local.talos_primary_node_private_ipv4]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.talos_primary_endpoint

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# Prerequisites: packer, curl, jq, talosctl must be available in PATH.
data "external" "client_prerequisites_check" {
  program = [
    "sh", "-c", <<-EOT
      set -eu

      missing=0

      if ! command -v packer >/dev/null 2>&1; then
          printf '\n%s' ' - packer is not installed or not in PATH. Install it at https://developer.hashicorp.com/packer/install' >&2
          missing=1
      fi

      if ! command -v curl >/dev/null 2>&1; then
          printf '\n%s' ' - curl is not installed or not in PATH. Install it at https://curl.se/download.html' >&2
          missing=1
      fi

      if ! command -v jq >/dev/null 2>&1; then
          printf '\n%s' ' - jq is not installed or not in PATH. Install it at https://jqlang.org/download/' >&2
          missing=1
      fi

      if ! command -v talosctl >/dev/null 2>&1; then
          printf '\n%s' ' - talosctl is not installed or not in PATH. Install it at https://www.talos.dev/latest/talos-guides/install/talosctl' >&2
          missing=1
      fi

      printf '%s' '{}'
      exit "$missing"
    EOT
  ]
}

# Verify installed talosctl version is >= the target Talos version.
data "external" "talosctl_version_check" {
  program = [
    "sh", "-c", <<-EOT
      set -eu

      parse() {
        case $1 in
          *[vV][0-9]*.[0-9]*.[0-9]*)
            v=$${1##*[vV]}
            maj=$${v%%.*}
            r=$${v#*.}
            min=$${r%%.*}
            patch=$${r#*.}
            patch=$${patch%%[!0-9]*}
            printf '%s %s %s\n' "$maj" "$min" "$patch"
            return 0
            ;;
        esac
        return 1
      }

      parsed_version=$(
        talosctl version --client --short |
        while IFS= read -r line; do
          if out=$(parse "$line"); then
            printf '%s\n' "$out"
            break
          fi
        done
      )

      if [ -z "$parsed_version" ]; then
        printf '%s\n' "Could not parse talosctl client version" >&2
        exit 1
      fi

      set -- $parsed_version; major=$1; minor=$2; patch=$3
      if [ "$major" -lt "${local.talos_version_major}" ] ||
       { [ "$major" -eq "${local.talos_version_major}" ] && [ "$minor" -lt "${local.talos_version_minor}" ]; } ||
       { [ "$major" -eq "${local.talos_version_major}" ] && [ "$minor" -eq "${local.talos_version_minor}" ] && [ "$patch" -lt "${local.talos_version_patch}" ]; }
      then
        printf '%s\n' "talosctl version ($major.$minor.$patch) is lower than Talos target version: ${local.talos_version_major}.${local.talos_version_minor}.${local.talos_version_patch}" >&2
        exit 1
      fi

      printf '%s' "{\"talosctl_version\": \"$major.$minor.$patch\"}"
    EOT
  ]

  depends_on = [data.external.client_prerequisites_check]
}
