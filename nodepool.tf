locals {
  # Infer whether scheduling on control planes is allowed.
  # Explicit override takes precedence; otherwise allow if no workers exist.
  talos_allow_scheduling_on_control_planes = coalesce(
    var.allow_scheduling_on_control_planes,
    (local.worker_sum + local.cluster_autoscaler_max_sum) == 0
  )

  # Expand simplified nodepool input to full internal structure.
  control_plane_nodepools = [
    for np in var.control_plane_nodepools : {
      name        = np.name
      location    = np.location
      server_type = np.type
      count       = np.count
      backups     = false
      keep_disk   = false
      labels      = { nodepool = np.name }
      annotations = {}
      taints = local.talos_allow_scheduling_on_control_planes ? [] : [
        { key = "node-role.kubernetes.io/control-plane", value = "", effect = "NoSchedule" }
      ]
    }
  ]

  worker_nodepools = [
    for np in var.worker_nodepools : {
      name            = np.name
      location        = np.location
      server_type     = np.type
      count           = np.count
      backups         = false
      keep_disk       = false
      placement_group = true
      labels          = { nodepool = np.name }
      annotations     = {}
      taints          = []
    }
  ]

  cluster_autoscaler_nodepools = [
    for np in var.cluster_autoscaler_nodepools : {
      name        = np.name
      location    = np.location
      server_type = np.type
      min         = np.min
      max         = np.max
      labels      = { nodepool = np.name }
      annotations = {}
      taints      = []
    }
  ]

  # Maps for fast lookup
  control_plane_nodepools_map      = { for np in local.control_plane_nodepools : np.name => np }
  worker_nodepools_map             = { for np in local.worker_nodepools : np.name => np }
  cluster_autoscaler_nodepools_map = { for np in local.cluster_autoscaler_nodepools : np.name => np }

  # Sums
  control_plane_sum = sum(concat(
    [for np in local.control_plane_nodepools : np.count], [0]
  ))
  worker_sum = sum(concat(
    [for np in local.worker_nodepools : np.count if length(np.taints) == 0], [0]
  ))
  cluster_autoscaler_min_sum = sum(concat(
    [for np in local.cluster_autoscaler_nodepools : np.min if length(np.taints) == 0], [0]
  ))
  cluster_autoscaler_max_sum = sum(concat(
    [for np in local.cluster_autoscaler_nodepools : np.max if length(np.taints) == 0], [0]
  ))
}
