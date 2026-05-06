locals {
  control_plane_ips = [
    "${var.base_network}.${var.cp_ip_start}",
    "${var.base_network}.${var.cp_ip_start + 1}",
    "${var.base_network}.${var.cp_ip_start + 2}",
  ]

  worker_ips = [
    "${var.base_network}.${var.worker_ip_start}",
    "${var.base_network}.${var.worker_ip_start + 1}",
    "${var.base_network}.${var.worker_ip_start + 2}",
  ]

  cp_names     = ["cp-1", "cp-2", "cp-3"]
  worker_names = ["worker-1", "worker-2", "worker-3"]

  # Highest priority = preferred keepalived MASTER
  cp_priorities = [101, 100, 99]

  ssh_private_key = file(pathexpand(var.vm_ssh_private_key_path))
}
