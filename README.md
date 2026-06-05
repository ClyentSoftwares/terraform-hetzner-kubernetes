# Hetzner Kubernetes Terraform

A highly opinionated Terraform module to deploy Kubernetes on Hetzner Cloud (and Hetzner dedicated servers) using [Talos OS](https://www.talos.dev/) and Cilium CNI.

## Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/install) or [tofu](https://opentofu.org/docs/intro/install/)
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) (optional)
- A [Tailscale](https://tailscale.com/) account and OAuth client secret

## Getting Started

```hcl
module "cluster" {
  source  = "ClyentSoftwares/kubernetes/hetzner"
  version = "0.2.0"

  cluster_name              = "my-cluster"
  cluster_delete_protection = true
  hcloud_token              = "<hcloud-token>"

  control_planes = [
    { name = "control-plane-1", type = "cx23", location = "fsn1", image = "talos-amd64" },
  ]

  workers = [
    { name = "worker", type = "cx23", location = "fsn1", image = "talos-amd64", count = 2 },
  ]

  tailscale = {
    auth_key = "<tailscale-oauth-client-secret>"
    tags     = ["k8s"]
  }

  imager_amd64_builder = {
    server_location = "fsn1"
  }

  # Optional: Hetzner dedicated servers as additional workers
  # external_workers = [
  #   { hostname = "dedicated-1", public_ipv4 = "1.2.3.4" }
  # ]

  # Optional: etcd backups to S3-compatible storage
  # talos_backup_s3 = {
  #   enabled    = true
  #   url        = "https://fsn1.your-objectstorage.com"
  #   bucket     = "my-talos-backups"
  #   region     = "auto"
  #   access_key = "<access-key>"
  #   secret_key = "<secret-key>"
  # }
}
```

### Deploy

```shell
terraform init
terraform apply
```

### Access the cluster

```shell
terraform output -raw talosconfig > ~/.talos/config
terraform output -raw kubeconfig  > ~/.kube/config

kubectl get nodes
```

### Destroy

First set `cluster_delete_protection = false`, then:

```shell
terraform destroy
```

## Tailscale

Nodes are accessed via Tailscale. Use an OAuth client secret (`tskey-client-xxx`) rather than an auth key — OAuth secrets do not expire and auto-generate fresh device tokens on each node boot.

1. Go to [Tailscale admin → OAuth clients](https://login.tailscale.com/admin/settings/oauth) and create a client with `auth_keys` **write** scope.
2. Set at least one tag in `tailscale.tags` and ensure it exists in your ACL `tagOwners`.
3. Approve the advertised subnet route (`10.0.0.0/16` by default) in the Tailscale admin console, or configure `autoApprovers` in your ACL policy.

## External Workers

Dedicated or external servers can join the cluster as workers. Talos must be pre-installed on the server before running `terraform apply`.

```hcl
external_workers = [
  {
    hostname    = "dedicated-1"
    public_ipv4 = "1.2.3.4"
    labels      = { "node.kubernetes.io/instance-type" = "dedicated" }
    taints      = [{ key = "dedicated", value = "true", effect = "NoSchedule" }]
  }
]
```

## Credits

- Based on [terraform-hcloud-kubernetes](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes)
