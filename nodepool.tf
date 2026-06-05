locals {
  # Allow scheduling on control planes if there are no worker nodes
  talos_allow_scheduling_on_control_planes = coalesce(
    (local.worker_count + local.external_worker_count) == 0
  )

  # Expand simplified nodepool input to full internal structure
  control_planes = [
    for np in var.control_planes : {
      name        = np.name
      location    = np.location
      server_type = np.type
      image       = np.image
      count       = 1
      backups     = false
      keep_disk   = false
      labels      = { nodepool = np.name }
      annotations = {}
      taints = local.talos_allow_scheduling_on_control_planes ? [] : [
        { key = "node-role.kubernetes.io/control-plane", value = "", effect = "NoSchedule" }
      ]
    }
  ]

  workers = [
    for np in var.workers : {
      name            = np.name
      location        = np.location
      server_type     = np.type
      image           = np.image
      count           = np.count
      backups         = false
      keep_disk       = false
      placement_group = true
      labels          = merge({ nodepool = np.name }, np.labels)
      annotations     = {}
      taints          = np.taints
    }
  ]

  external_workers = [
    for np in var.external_workers : {
      hostname    = np.hostname
      public_ipv4 = np.public_ipv4
      labels      = merge({ nodepool = np.hostname }, np.labels)
      annotations = {}
      taints      = np.taints
    }
  ]

  # Maps for fast lookup
  control_plane_nodepools       = local.control_planes
  control_plane_nodepools_map   = { for np in local.control_planes : np.name => np }
  worker_nodepools_map          = { for np in local.workers : np.name => np }
  external_worker_nodepools_map = { for np in local.external_workers : np.hostname => np }

  # Sums
  control_plane_count = length(local.control_planes)
  worker_count = sum(concat(
    [for np in local.workers : np.count if length(np.taints) == 0], [0]
  ))
  external_worker_count = length(local.external_workers)
}
