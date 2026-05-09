# ── NixOS ISO (one copy per Proxmox node) ─────────────────────────────────────

resource "proxmox_virtual_environment_download_file" "nixos_iso" {
  count        = length(var.proxmox_nodes)
  content_type = "iso"
  datastore_id = var.pg_iso_datastore
  node_name    = var.proxmox_nodes[count.index]
  url          = "https://channels.nixos.org/nixos-${var.nixos_version}/latest-nixos-minimal-x86_64-linux.iso"
  file_name    = "nixos-${var.nixos_version}-minimal-x86_64-linux.iso"
  overwrite    = false
}

# ── NixOS VMs ─────────────────────────────────────────────────────────────────

module "patroni" {
  count  = 3
  source = "./modules/vm"

  name              = "pg-${count.index + 1}"
  vm_id             = var.pg_vm_id_base + count.index
  proxmox_node      = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  nixos_iso_file_id = proxmox_virtual_environment_download_file.nixos_iso[count.index % length(var.proxmox_nodes)].id
  cores             = var.pg_cores
  memory_gb         = var.pg_memory_gb
  disk_gb           = var.pg_disk_gb
  datastore         = var.datastore
  network_bridge    = var.network_bridge
}

# ── Phase 1: Install NixOS onto the blank disk via nixos-anywhere ──────────────
# Requires nixos-anywhere + nix (with flakes) on the Terraform host.
# The QEMU guest agent in the NixOS installer ISO provides the live DHCP IP.

resource "null_resource" "nixos_install" {
  count = 3

  triggers = {
    vm_id = module.patroni[count.index].vm_id
  }

  depends_on = [module.patroni]

  provisioner "local-exec" {
    environment = {
      NODE_NAME       = "pg-${count.index + 1}"
      NODE_IP         = var.pg_ips[count.index]
      CIDR_PREFIX     = var.pg_network_prefix
      GATEWAY         = var.pg_network_gateway
      DNS_SERVER      = var.pg_dns_server
      NIXOS_VERSION   = var.nixos_version
      SSH_PUBLIC_KEY  = var.pg_ssh_public_key
      SSH_PRIVATE_KEY = local.pg_ssh_private_key
      INSTALLER_IP    = module.patroni[count.index].ip_address
    }
    command = "bash ${path.module}/scripts/patroni/install.sh"
  }
}

# ── Phase 2: Apply etcd + PostgreSQL + Patroni configuration ──────────────────

resource "null_resource" "patroni_setup" {
  count = 3

  triggers = {
    ip           = var.pg_ips[count.index]
    pg_version   = var.pg_version
    etcd_version = var.etcd_version
  }

  depends_on = [null_resource.nixos_install]

  connection {
    type        = "ssh"
    host        = var.pg_ips[count.index]
    user        = var.pg_username
    private_key = local.pg_ssh_private_key
    timeout     = "15m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/patroni/setup.sh"
    destination = "/tmp/patroni-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/patroni-setup.sh",
      join(" ", [
        "sudo",
        "NODE_NAME='pg-${count.index + 1}'",
        "NODE_IP='${var.pg_ips[count.index]}'",
        "ETCD_CLUSTER='${local.pg_etcd_cluster}'",
        "ETCD_HOSTS='${local.pg_etcd_hosts}'",
        "PG_SCOPE='${var.pg_cluster_name}'",
        "PG_SUPER_PASS='${var.pg_superuser_password}'",
        "PG_REPL_PASS='${var.pg_replication_password}'",
        "PG_VERSION='${var.pg_version}'",
        "ETCD_VERSION='${var.etcd_version}'",
        "bash /tmp/patroni-setup.sh",
      ]),
    ]
  }
}
