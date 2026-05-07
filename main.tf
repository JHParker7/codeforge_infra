
# ── Cluster secrets ───────────────────────────────────────────────────────────
# Bootstrap token format required by kubeadm: [a-z0-9]{6}.[a-z0-9]{16}
resource "random_password" "token_id" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "random_password" "token_secret" {
  length  = 16
  special = false
  upper   = false
  numeric = true
}

# 64-hex-char key used to encrypt certs uploaded to kube-system during init
resource "random_id" "certificate_key" {
  byte_length = 32
}

locals {
  bootstrap_token = "${random_password.token_id.result}.${random_password.token_secret.result}"
  certificate_key = random_id.certificate_key.hex
  tmp_dir         = "${path.module}/tmp"
}

resource "null_resource" "ensure_tmp_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.tmp_dir}"
  }
}

# ── Virtual machines ──────────────────────────────────────────────────────────

module "control_plane" {
  count  = 3
  source = "./modules/vm"

  name           = "k8s-${local.cp_names[count.index]}"
  vm_id          = var.vm_id_base + count.index
  proxmox_node   = var.proxmox_nodes[count.index]
  template_vm_id = var.template_vm_id
  cores          = var.cp_cores
  memory_gb      = var.cp_memory_gb
  disk_gb        = var.cp_disk_gb
  datastore      = var.datastore
  network_bridge = var.network_bridge
  ip_address     = local.control_plane_ips[count.index]
  cidr_prefix    = var.network_prefix
  gateway        = var.network_gateway
  dns_server     = var.dns_server
  ssh_public_key = var.ssh_public_key
  username = var.username
  template_proxmox_node = var.template_proxmox_node
}

module "worker" {
  depends_on = [ module.control_plane ]
  count  = 3
  source = "./modules/vm"

  name           = "k8s-${local.worker_names[count.index]}"
  vm_id          = var.vm_id_base + 3 + count.index
  proxmox_node   = var.proxmox_nodes[count.index]
  template_vm_id = var.template_vm_id
  cores          = var.worker_cores
  memory_gb      = var.worker_memory_gb
  disk_gb        = var.worker_disk_gb
  datastore      = var.datastore
  network_bridge = var.network_bridge
  ip_address     = local.worker_ips[count.index]
  cidr_prefix    = var.network_prefix
  gateway        = var.network_gateway
  dns_server     = var.dns_server
  ssh_public_key = var.ssh_public_key
  username = var.username
  template_proxmox_node = var.template_proxmox_node
}

# ── Step 1: Common k8s prerequisites (all 6 nodes, runs in parallel) ──────────

resource "null_resource" "common_setup" {
  count = 6

  depends_on = [module.control_plane, module.worker]

  connection {
    type        = "ssh"
    host        = count.index < 3 ? local.control_plane_ips[count.index] : local.worker_ips[count.index - 3]
    user        = var.username
    private_key = local.ssh_private_key
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/01-common.sh"
    destination = "/tmp/01-common.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/01-common.sh",
      "sudo KUBERNETES_VERSION='${var.kubernetes_version}' bash /tmp/01-common.sh",
    ]
  }
}

# ── Step 2: keepalived + HAProxy on control planes (runs in parallel) ─────────

resource "null_resource" "haproxy_keepalived" {
  count = 3

  depends_on = [null_resource.common_setup]

  connection {
    type        = "ssh"
    host        = local.control_plane_ips[count.index]
    user        = var.username
    private_key = local.ssh_private_key
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/02-haproxy-keepalived.sh"
    destination = "/tmp/02-haproxy-keepalived.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/02-haproxy-keepalived.sh",
      "sudo VIP='${var.control_plane_vip}' NODE_IP='${local.control_plane_ips[count.index]}' PRIORITY='${local.cp_priorities[count.index]}' CP1_IP='${local.control_plane_ips[0]}' CP2_IP='${local.control_plane_ips[1]}' CP3_IP='${local.control_plane_ips[2]}' bash /tmp/02-haproxy-keepalived.sh",
    ]
  }
}

# ── Step 3: kubeadm init on cp-1 ──────────────────────────────────────────────

resource "null_resource" "control_plane_init" {
  depends_on = [null_resource.haproxy_keepalived]

  connection {
    type        = "ssh"
    host        = local.control_plane_ips[0]
    user        = var.username
    private_key = local.ssh_private_key
    timeout     = "20m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/03-control-plane-init.sh"
    destination = "/tmp/03-control-plane-init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/03-control-plane-init.sh",
      "sudo VIP='${var.control_plane_vip}' TOKEN='${local.bootstrap_token}' CERT_KEY='${local.certificate_key}' POD_CIDR='${var.pod_cidr}' SERVICE_CIDR='${var.service_cidr}' CALICO_VERSION='${var.calico_version}' bash /tmp/03-control-plane-init.sh",
    ]
  }
}

# ── Step 4: Pull join scripts from cp-1 to local tmp/ ────────────────────────

resource "null_resource" "fetch_join_scripts" {
  depends_on = [null_resource.control_plane_init, null_resource.ensure_tmp_dir]

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i '${pathexpand(var.vm_ssh_private_key_path)}' ubuntu@${local.control_plane_ips[0]} 'cat /tmp/cp-join.sh' > '${local.tmp_dir}/cp-join.sh'"
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i '${pathexpand(var.vm_ssh_private_key_path)}' ubuntu@${local.control_plane_ips[0]} 'cat /tmp/worker-join.sh' > '${local.tmp_dir}/worker-join.sh'"
  }
}

# ── Step 5: Join cp-2 and cp-3 as control planes (runs in parallel) ───────────

resource "null_resource" "control_plane_join" {
  count = 2

  depends_on = [null_resource.fetch_join_scripts]

  connection {
    type        = "ssh"
    host        = local.control_plane_ips[count.index + 1]
    user        = var.username
    private_key = local.ssh_private_key
    timeout     = "15m"
  }

  provisioner "file" {
    source      = "${local.tmp_dir}/cp-join.sh"
    destination = "/tmp/cp-join.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/cp-join.sh",
      "sudo bash /tmp/cp-join.sh",
    ]
  }
}

# ── Step 6: Join workers (runs in parallel) ───────────────────────────────────

resource "null_resource" "worker_join" {
  count = 3

  depends_on = [null_resource.fetch_join_scripts]

  connection {
    type        = "ssh"
    host        = local.worker_ips[count.index]
    user        = var.username
    private_key = local.ssh_private_key
    timeout     = "15m"
  }

  provisioner "file" {
    source      = "${local.tmp_dir}/worker-join.sh"
    destination = "/tmp/worker-join.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/worker-join.sh",
      "sudo bash /tmp/worker-join.sh",
    ]
  }
}

# ── Step 7: Fetch kubeconfig ──────────────────────────────────────────────────

resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.control_plane_join, null_resource.worker_join]

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -i '${pathexpand(var.vm_ssh_private_key_path)}' \
        ubuntu@${local.control_plane_ips[0]} \
        'sudo cat /etc/kubernetes/admin.conf' \
        | sed 's|server: https://[^:]*:6443|server: https://${var.control_plane_vip}:6443|' \
        > '${local.tmp_dir}/kubeconfig'
      chmod 600 '${local.tmp_dir}/kubeconfig'
    EOT
  }
}
