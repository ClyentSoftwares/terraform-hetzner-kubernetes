# Example Deployment

Example deployment of a 3-node Talos control plane cluster on Hetzner Cloud with Tailscale access.

## Deploy

### 1. Fill in secrets

Edit `terraform.tfvars` — replace the placeholder values with your real Hetzner token and Tailscale credential.

**Tailscale: OAuth client secret (recommended) vs auth key**

Auth keys (`tskey-auth-xxx`) expire after a maximum of 90 days, which means nodes will fail to re-join your tailnet after a reboot once the key expires. Use an OAuth client secret instead:

1. Go to [Tailscale admin console → Settings → OAuth clients](https://login.tailscale.com/admin/settings/oauth) and create a new client with the `auth_keys` **write** scope with `tag:k8s` tag.
2. Copy the generated secret (`tskey-client-xxx`) and use it as `tailscale_auth_key` in `terraform.tfvars`.
3. Set at least one tag in the `tailscale.tags` variable — OAuth-issued keys require tagged devices.
4. Ensure the tag exists in your Tailscale ACL `tagOwners` section.

OAuth client secrets do not expire and automatically generate fresh device auth tokens on each node boot.

### 2. Init and apply

```bash
cd example
terraform init
terraform apply
```

This builds the Talos image, creates the servers, bootstraps the cluster, and deploys Cilium + hcloud-ccm. Takes ~10–15 minutes.

### 3. Approve the Tailscale subnet route

Each control plane node advertises `10.0.0.0/16` to your tailnet via the Tailscale extension. Until this route is approved, kubectl will not work.

Go to the [Tailscale admin console → Machines](https://login.tailscale.com/admin/machines), find each control plane node, and approve the `10.0.0.0/16` subnet route.

To auto-approve routes without manual approval, add an `autoApprovers` rule to your Tailscale ACL policy using the `k8s` tag (you will need to create this).

### 4. Get your configs

```bash
terraform output -raw talosconfig > ~/.talos/config
terraform output -raw kubeconfig > ~/.kube/rundown-staging.kubeconfig
$env:KUBECONFIG = "$HOME\.kube\rundown-staging.kubeconfig"  
```

### 5. Verify

```bash
kubectl --kubeconfig ~/.kube/rundown-staging.kubeconfig get nodes
```

kubectl connects via `10.0.64.126` (the private VIP), routed through whichever control plane currently holds the alias IP. If a control plane goes down, the VIP migrates automatically and kubectl keeps working.

---

## Notes

- `cluster_delete_protection = false` — `terraform destroy` works cleanly when done testing.
- **talosctl** always connects via the public IPs (port 50000, mTLS protected) - it does not require Tailscale.
- The kubeconfig endpoint is the private VIP (`10.0.64.126`), not a specific node's IP, so it survives individual node failures (HA).
- **OAuth client secrets** (`tskey-client-xxx`) are preferred over auth keys — they don't expire and auto-generate device tokens on each boot. Requires `tags` to be set and the OAuth client to have `auth_keys:write` scope.
