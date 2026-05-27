locals {
  firewall_kube_api_source  = var.firewall_kube_api_source
  firewall_talos_api_source = var.firewall_talos_api_source

  # Auto-detect current public IP when no source CIDRs are specified
  firewall_use_current_ipv4 = local.network_public_ipv4_enabled && local.firewall_kube_api_source == null && local.firewall_talos_api_source == null
  firewall_use_current_ipv6 = false

  current_ip = concat(
    local.firewall_use_current_ipv4 ? ["${chomp(data.http.current_ipv4[0].response_body)}/32"] : [],
  )

  firewall_kube_api_sources = distinct(compact(concat(
    coalesce(local.firewall_kube_api_source, []),
    coalesce(local.current_ip, [])
  )))
  firewall_talos_api_sources = distinct(compact(concat(
    coalesce(local.firewall_talos_api_source, []),
    coalesce(local.current_ip, [])
  )))

  firewall_rules_list = concat(
    length(local.firewall_kube_api_sources) > 0 ? [
      {
        description = "Allow Incoming Requests to Kube API"
        direction   = "in"
        source_ips  = local.firewall_kube_api_sources
        protocol    = "tcp"
        port        = local.kube_api_port
      }
    ] : [],
    length(local.firewall_talos_api_sources) > 0 ? [
      {
        description = "Allow Incoming Requests to Talos API"
        direction   = "in"
        source_ips  = local.firewall_talos_api_sources
        protocol    = "tcp"
        port        = local.talos_api_port
      }
    ] : [],
  )

  firewall_id = hcloud_firewall.this.id
}

data "http" "current_ipv4" {
  count = local.firewall_use_current_ipv4 ? 1 : 0
  url   = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }

  lifecycle {
    postcondition {
      condition     = contains([200], self.status_code)
      error_message = "HTTP status code invalid"
    }
  }
}

resource "hcloud_firewall" "this" {
  name = var.cluster_name

  dynamic "rule" {
    for_each = local.firewall_rules_list
    content {
      description     = rule.value.description
      direction       = rule.value.direction
      source_ips      = lookup(rule.value, "source_ips", [])
      destination_ips = lookup(rule.value, "destination_ips", [])
      protocol        = rule.value.protocol
      port            = lookup(rule.value, "port", null)
    }
  }

  labels = {
    cluster = var.cluster_name
  }
}
