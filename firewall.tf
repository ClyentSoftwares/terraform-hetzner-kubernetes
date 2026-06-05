resource "hcloud_firewall" "control_plane" {
  name = "${var.cluster_name}-control-plane"

  rule {
    description = "Talos API"
    direction   = "in"
    protocol    = "tcp"
    port        = "50000"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "KubeSpan WireGuard"
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "Tailscale WireGuard"
    direction   = "in"
    protocol    = "udp"
    port        = "41641"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0"]
  }

  labels = { cluster = var.cluster_name }
}

resource "hcloud_firewall" "worker" {
  count = length(local.worker_servers) > 0 ? 1 : 0
  name  = "${var.cluster_name}-worker"

  rule {
    description = "Talos API"
    direction   = "in"
    protocol    = "tcp"
    port        = "50000"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "KubeSpan WireGuard"
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "Tailscale WireGuard"
    direction   = "in"
    protocol    = "udp"
    port        = "41641"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0"]
  }

  labels = { cluster = var.cluster_name }
}

resource "hcloud_firewall_attachment" "control_plane" {
  firewall_id = hcloud_firewall.control_plane.id
  server_ids  = [for s in hcloud_server.control_plane : s.id]
}

resource "hcloud_firewall_attachment" "worker" {
  count       = length(local.worker_servers) > 0 ? 1 : 0
  firewall_id = hcloud_firewall.worker[0].id
  server_ids  = [for s in hcloud_server.worker : s.id]
}
