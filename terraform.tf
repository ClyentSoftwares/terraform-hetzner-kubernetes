terraform {
  required_version = ">=1.8.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.62.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.4.0"
    }

    imager = {
      source  = "hcloud-talos/imager"
      version = "~> 1.0"
    }

  }
}
