resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  clone {
    vm_id     = var.template_vm_id
    node_name = var.template_proxmox_node
    full      = true
    retries   = 3
  }

  agent {
    enabled = true
  }

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

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore

    dns {
      servers = [var.dns_server]
    }

    ip_config {
      ipv4 {
        address = "${var.ip_address}/${var.cidr_prefix}"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.username
      keys     = var.ssh_public_key == "" ? null : [trimspace(var.ssh_public_key)]
    }
  }

  lifecycle {
    # Cloud-init only runs on first boot; re-applying must not re-trigger it.
    ignore_changes = [initialization]
  }
}
