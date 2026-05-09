# ── Talos image with qemu-guest-agent extension ───────────────────────────────

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = ["siderolabs/qemu-guest-agent"]
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = "v${var.talos_version}"
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "metal"
  architecture  = "amd64"
}

# ── Talos ISO (one copy per Proxmox node) ─────────────────────────────────────

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  count        = length(var.proxmox_nodes)
  content_type = "iso"
  datastore_id = var.iso_datastore
  node_name    = var.proxmox_nodes[count.index]
  url          = data.talos_image_factory_urls.this.urls.iso
  file_name    = "talos-${var.talos_version}-qemu-guest-agent-metal-amd64.iso"
  overwrite    = false
}

# ── Virtual machines ──────────────────────────────────────────────────────────

module "control_plane" {
  count  = 3
  source = "./modules/talos_vm"

  name              = "k8s-${local.cp_names[count.index]}"
  vm_id             = var.vm_id_base + count.index
  proxmox_node      = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  talos_iso_file_id = proxmox_virtual_environment_download_file.talos_iso[count.index % length(var.proxmox_nodes)].id
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
  talos_iso_file_id = proxmox_virtual_environment_download_file.talos_iso[count.index % length(var.proxmox_nodes)].id
  cores             = var.worker_cores
  memory_gb         = var.worker_memory_gb
  disk_gb           = var.worker_disk_gb
  datastore         = var.datastore
  network_bridge    = var.network_bridge
}
