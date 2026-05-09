# ── Phase 1: install and start Redis on each Patroni VM ───────────────────────

resource "null_resource" "redis_setup" {
  count = 3

  triggers = {
    ip         = var.pg_ips[count.index]
    redis_port = var.redis_port
  }

  depends_on = [null_resource.patroni_setup]

  connection {
    type        = "ssh"
    host        = var.pg_ips[count.index]
    user        = var.pg_username
    private_key = local.pg_ssh_private_key
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/redis/setup.sh"
    destination = "/tmp/redis-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/redis-setup.sh",
      join(" ", [
        "sudo env",
        "NODE_IP='${var.pg_ips[count.index]}'",
        "REDIS_PORT='${var.redis_port}'",
        "REDIS_PASSWORD='${var.redis_password}'",
        "bash /tmp/redis-setup.sh",
      ]),
    ]
  }
}

# ── Phase 2: create the cluster from pg-1 ─────────────────────────────────────

locals {
  redis_nodes = join(" ", [for ip in var.pg_ips : "${ip}:${var.redis_port}"])
}

resource "null_resource" "redis_cluster_create" {
  triggers = {
    nodes = local.redis_nodes
  }

  depends_on = [null_resource.redis_setup]

  connection {
    type        = "ssh"
    host        = var.pg_ips[0]
    user        = var.pg_username
    private_key = local.pg_ssh_private_key
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/redis/create_cluster.sh"
    destination = "/tmp/redis-create-cluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/redis-create-cluster.sh",
      join(" ", [
        "sudo env",
        "REDIS_NODES='${local.redis_nodes}'",
        "REDIS_PASSWORD='${var.redis_password}'",
        "bash /tmp/redis-create-cluster.sh",
      ]),
    ]
  }
}
