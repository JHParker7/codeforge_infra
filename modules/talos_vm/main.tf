resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_gb * 1024
  }

  disk {
    datastore_id = var.datastore
    discard      = "on"
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.disk_gb
    ssd          = true
  }

  cdrom {
    file_id   = var.talos_iso_file_id
    interface = "ide0"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # Required to read IPs back from the guest
  agent {
    enabled = true
    trim    = true
    timeout = "10m"
  }

  boot_order = ["scsi0", "ide0"]
}
