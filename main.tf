# ── Talos ISO ─────────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.iso_datastore
  node_name    = var.proxmox_nodes[0]
  url          = "https://github.com/siderolabs/talos/releases/download/v${var.talos_version}/metal-amd64.iso"
  file_name    = "talos-${var.talos_version}-metal-amd64.iso"
  overwrite    = false
}

# ── Virtual machines ──────────────────────────────────────────────────────────

module "control_plane" {
  count  = 3
  source = "./modules/talos_vm"

  name              = "k8s-${local.cp_names[count.index]}"
  vm_id             = var.vm_id_base + count.index
  proxmox_node      = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  talos_iso_file_id = proxmox_virtual_environment_download_file.talos_iso.id
  cores             = var.cp_cores
  memory_gb         = var.cp_memory_gb
  disk_gb           = var.cp_disk_gb
  datastore         = var.datastore
  network_bridge    = var.network_bridge
}

module "worker" {
  count  = 3
  source = "./modules/talos_vm"

  name              = "k8s-${local.worker_names[count.index]}"
  vm_id             = var.vm_id_base + 3 + count.index
  proxmox_node      = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  talos_iso_file_id = proxmox_virtual_environment_download_file.talos_iso.id
  cores             = var.worker_cores
  memory_gb         = var.worker_memory_gb
  disk_gb           = var.worker_disk_gb
  datastore         = var.datastore
  network_bridge    = var.network_bridge
}

# ── Talos cluster secrets ─────────────────────────────────────────────────────

resource "talos_machine_secrets" "this" {}

# ── Machine configurations ────────────────────────────────────────────────────

data "talos_machine_configuration" "control_plane" {
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.control_plane_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = "https://${var.control_plane_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
}

# ── Apply configs to control planes ──────────────────────────────────────────

resource "talos_machine_configuration_apply" "control_plane" {
  count                       = 3
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = local.control_plane_ips[count.index]
  endpoint                    = local.control_plane_ips[count.index]

  config_patches = [
    yamlencode({
      machine = {
        install = { disk = "/dev/sda" }
        network = {
          hostname = "k8s-${local.cp_names[count.index]}"
          interfaces = [{
            interface = "eth0"
            addresses = ["${local.control_plane_ips[count.index]}/${var.network_prefix}"]
            routes    = [{ network = "0.0.0.0/0", gateway = var.network_gateway }]
            vip       = { ip = var.control_plane_vip }
          }]
          nameservers = [var.dns_server]
        }
      }
      cluster = {
        network = {
          podSubnets     = [var.pod_cidr]
          serviceSubnets = [var.service_cidr]
        }
      }
    })
  ]

  depends_on = [module.control_plane, module.worker]
}

# ── Apply configs to workers ──────────────────────────────────────────────────

resource "talos_machine_configuration_apply" "worker" {
  count                       = 3
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_ips[count.index]
  endpoint                    = local.worker_ips[count.index]

  config_patches = [
    yamlencode({
      machine = {
        install = { disk = "/dev/sda" }
        network = {
          hostname = "k8s-${local.worker_names[count.index]}"
          interfaces = [{
            interface = "eth0"
            addresses = ["${local.worker_ips[count.index]}/${var.network_prefix}"]
            routes    = [{ network = "0.0.0.0/0", gateway = var.network_gateway }]
          }]
          nameservers = [var.dns_server]
        }
      }
    })
  ]

  depends_on = [module.control_plane, module.worker]
}

# ── Bootstrap etcd on cp-1 ────────────────────────────────────────────────────

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_ips[0]
  endpoint             = local.control_plane_ips[0]
  depends_on           = [talos_machine_configuration_apply.control_plane]
}

# ── Kubeconfig ────────────────────────────────────────────────────────────────

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_ips[0]
  endpoint             = local.control_plane_ips[0]
  depends_on           = [talos_machine_bootstrap.this]
}
