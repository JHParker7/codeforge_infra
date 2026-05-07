locals {
  control_plane_ips = [for i in range(3) : module.control_plane[i].ip_address]
  worker_ips        = [for i in range(3) : module.worker[i].ip_address]
  cp_names          = ["cp-1", "cp-2", "cp-3"]
  worker_names      = ["worker-1", "worker-2", "worker-3"]
}
