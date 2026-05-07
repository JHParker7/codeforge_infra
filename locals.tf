locals {
  control_plane_ips = [for i in range(3) : "${var.base_network}.${var.cp_ip_start + i}"]
  worker_ips        = [for i in range(3) : "${var.base_network}.${var.worker_ip_start + i}"]
  cp_names          = ["cp-1", "cp-2", "cp-3"]
  worker_names      = ["worker-1", "worker-2", "worker-3"]
}
