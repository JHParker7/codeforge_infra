# ── Ubuntu VMs ────────────────────────────────────────────────────────────────

module "patroni" {
  count  = 3
  source = "./modules/vm"

  name                  = "pg-${count.index + 1}"
  vm_id                 = var.pg_vm_id_base + count.index
  proxmox_node          = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  template_vm_id        = var.pg_template_vm_id
  template_proxmox_node = var.pg_template_proxmox_node
  ip_address            = var.pg_ips[count.index]
  cidr_prefix           = var.pg_network_prefix
  gateway               = var.pg_network_gateway
  dns_server            = var.pg_dns_server
  username              = var.pg_username
  ssh_public_key        = var.pg_ssh_public_key
  cores                 = var.pg_cores
  memory_gb             = var.pg_memory_gb
  disk_gb               = var.pg_disk_gb
  datastore             = var.datastore
  network_bridge        = var.network_bridge
}

# ── Apply etcd + PostgreSQL + Patroni configuration ───────────────────────────

resource "null_resource" "patroni_setup" {
  count = 3

  triggers = {
    ip           = var.pg_ips[count.index]
    pg_version   = var.pg_version
    etcd_version = var.etcd_version
  }

  depends_on = [module.patroni]

  connection {
    type        = "ssh"
    host        = var.pg_ips[count.index]
    user        = var.pg_username
    private_key = local.pg_ssh_private_key
    timeout     = "15m"
  }

  provisioner "file" {
    content = <<-VARS
      export NODE_NAME="pg-${count.index + 1}"
      export NODE_IP="${var.pg_ips[count.index]}"
      export ETCD_CLUSTER="${local.pg_etcd_cluster}"
      export ETCD_HOSTS="${local.pg_etcd_hosts}"
      export PG_SCOPE="${var.pg_cluster_name}"
      export PG_SUPER_PASS="${var.pg_superuser_password}"
      export PG_REPL_PASS="${var.pg_replication_password}"
      export PG_VERSION="${var.pg_version}"
      export ETCD_VERSION="${var.etcd_version}"
      export TIMEZONE="${var.timezone}"
    VARS
    destination = "/tmp/patroni-vars.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/patroni/setup.sh"
    destination = "/tmp/patroni-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/patroni-setup.sh",
      "sudo bash -c 'source /tmp/patroni-vars.sh && bash /tmp/patroni-setup.sh'",
    ]
  }
}
