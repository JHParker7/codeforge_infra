output "control_plane_ips" {
  description = "IPs reported by the QEMU guest agent for each control plane node"
  value       = [for i in range(3) : module.control_plane[i].ip_address]
}

output "worker_ips" {
  description = "IPs reported by the QEMU guest agent for each worker node"
  value       = [for i in range(3) : module.worker[i].ip_address]
}
