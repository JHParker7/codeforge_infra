output "control_plane_ips" {
  description = "IP addresses of the three control-plane nodes"
  value       = local.control_plane_ips
}

output "worker_ips" {
  description = "IP addresses of the three worker nodes"
  value       = local.worker_ips
}

output "control_plane_vip" {
  description = "Virtual IP for the Kubernetes API server"
  value       = var.control_plane_vip
}

output "kubeconfig_path" {
  description = "Local path to the generated kubeconfig (server points to VIP)"
  value       = "${local.tmp_dir}/kubeconfig"
}

output "vm_ids" {
  description = "Proxmox VM IDs for all six nodes"
  value = {
    control_planes = [for m in module.control_plane : m.vm_id]
    workers        = [for m in module.worker : m.vm_id]
  }
}
