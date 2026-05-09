resource "null_resource" "redis_setup" {
  triggers = {
    ip         = var.pg_ips[0]
    redis_port = var.redis_port
  }

  depends_on = [null_resource.patroni_setup]

  connection {
    type        = "ssh"
    host        = var.pg_ips[0]
    user        = var.pg_username
    private_key = local.pg_ssh_private_key
    timeout     = "10m"
  }

  provisioner "file" {
    content = <<-VARS
      export NODE_IP="${var.pg_ips[0]}"
      export REDIS_PORT="${var.redis_port}"
      export REDIS_PASSWORD="${var.redis_password}"
    VARS
    destination = "/tmp/redis-vars.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/redis/setup.sh"
    destination = "/tmp/redis-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/redis-setup.sh",
      "sudo bash -c 'source /tmp/redis-vars.sh && bash /tmp/redis-setup.sh'",
    ]
  }
}
