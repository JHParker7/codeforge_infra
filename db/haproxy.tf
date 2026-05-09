resource "null_resource" "haproxy_setup" {
  count = 3

  triggers = {
    ips            = join(",", var.pg_ips)
    redis_password = var.redis_password
  }

  depends_on = [null_resource.patroni_setup, null_resource.redis_setup]

  connection {
    type        = "ssh"
    host        = var.pg_ips[count.index]
    user        = var.pg_username
    private_key = local.pg_ssh_private_key
    timeout     = "10m"
  }

  provisioner "file" {
    content = <<-VARS
      export PG_IP_1="${var.pg_ips[0]}"
      export PG_IP_2="${var.pg_ips[1]}"
      export PG_IP_3="${var.pg_ips[2]}"
      export HAPROXY_PG_PRIMARY_PORT="${var.haproxy_pg_primary_port}"
      export HAPROXY_PG_REPLICA_PORT="${var.haproxy_pg_replica_port}"
      export HAPROXY_REDIS_PORT="${var.haproxy_redis_port}"
      export HAPROXY_STATS_PORT="${var.haproxy_stats_port}"
    VARS
    destination = "/tmp/haproxy-vars.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/haproxy/setup.sh"
    destination = "/tmp/haproxy-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/haproxy-setup.sh",
      "sudo bash -c 'source /tmp/haproxy-vars.sh && bash /tmp/haproxy-setup.sh'",
    ]
  }
}
