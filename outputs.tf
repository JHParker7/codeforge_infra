output "kubeconfig" {
  description = "Kubeconfig for the cluster — pipe to a file or export KUBECONFIG"
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client config — save to ~/.talos/config"
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}

output "control_plane_ips" {
  value = local.control_plane_ips
}

output "worker_ips" {
  value = local.worker_ips
}
