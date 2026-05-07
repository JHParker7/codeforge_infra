locals {
  control_plane_ips = var.control_plane_ips
  worker_ips        = var.worker_ips
  cp_names          = ["cp-1", "cp-2", "cp-3"]
  worker_names      = ["worker-1", "worker-2", "worker-3"]
}
