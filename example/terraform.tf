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

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.4.0"
    }

    imager = {
      source  = "hcloud-talos/imager"
      version = "~> 1.0"
    }
  }

  # backend "s3" {
  #   bucket                      = "TODO_STATE_BUCKET"
  #   key                         = "rundown-staging/terraform.tfstate"
  #   region                      = "TODO_REGION"
  #   endpoint                    = "TODO_ENDPOINT"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
}
