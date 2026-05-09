locals {
  pg_ssh_private_key = file(pathexpand(var.pg_ssh_private_key_path))

  # "pg-1=http://x.x.x.1:2380,pg-2=http://x.x.x.2:2380,pg-3=http://x.x.x.3:2380"
  pg_etcd_cluster = join(",", [
    for i in range(3) : "pg-${i + 1}=http://${var.pg_ips[i]}:2380"
  ])

  # "x.x.x.1:2379,x.x.x.2:2379,x.x.x.3:2379"
  pg_etcd_hosts = join(",", [for ip in var.pg_ips : "${ip}:2379"])
}
