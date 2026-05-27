# Hetzner Kubernetes Terraform

A highly opinionated Terraform module to deploy Kubernetes on both Hetzner Cloud and Dedicated using [Talos OS](https://www.talos.dev/) and Cilium CNI.

## Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/install) or [tofu](https://opentofu.org/docs/intro/install/) to deploy the Cluster
- [packer](https://developer.hashicorp.com/packer/install) to upload Talos Images
- [curl](https://curl.se) and [jq](https://jqlang.org/download/) for API Communication
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl) to control the Talos Cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) to control Kubernetes (optional)

## Getting Started

```hcl
module "kubernetes" {
  source  = "ClyentSoftwares/kubernetes/hetzner"
  version = "0.1.0"

  cluster_name = "k8s"
  hcloud_token = "<hcloud-token>"

  control_plane_nodepools = [
    { name = "control-plane", type = "cpx22", location = "nbg1", count = 3 }
  ]
  worker_nodepools = [
    { name = "worker", type = "cpx31", location = "nbg1", count = 3 }
  ]

  # Cluster autoscaler burst nodes (optional)
  cluster_autoscaler_nodepools = [
    { name = "autoscaler", type = "cpx31", location = "nbg1", min = 0, max = 6 }
  ]

  # Hetzner Robot dedicated servers as workers (optional)
  # Talos must be pre-installed: dd if=talos-hcloud-amd64.raw of=/dev/sda bs=4M
  dedicated_servers = [
    { hostname = "robot-1", vswitch_id = 12345, private_ipv4 = "10.0.64.200", network_interface = "eth0" }
  ]
  robot_user     = "<robot-user>"
  robot_password = "<robot-password>"

  # etcd backup to HCloud Object Storage (optional)
  talos_backup_s3_enabled    = true
  talos_backup_s3_hcloud_url = "https://my-bucket.fsn1.your-objectstorage.com"
  talos_backup_s3_access_key = "<access-key>"
  talos_backup_s3_secret_key = "<secret-key>"
}
```

### Deploy

```shell
terraform init
terraform apply
```

### Access the cluster

```shell
terraform output -raw kubeconfig  > kubeconfig.yaml
terraform output -raw talosconfig > talosconfig.yaml

export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```

### Destroy

First disable delete protection:

```hcl
cluster_delete_protection = false
```

Then run:

```shell
terraform destroy
```

## Credits

- Based on [terraform-hcloud-kubernetes](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes)
