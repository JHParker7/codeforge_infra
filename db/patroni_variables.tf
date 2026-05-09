variable "timezone" {
  description = "Timezone for all db VMs (e.g. Europe/London)"
  type        = string
  default     = "Europe/London"
}

# ── Ubuntu template ───────────────────────────────────────────────────────────

variable "pg_template_vm_id" {
  description = "VM ID of the Ubuntu cloud-init template to clone"
  type        = number
}

variable "pg_template_proxmox_node" {
  description = "Proxmox node that hosts the Ubuntu template"
  type        = string
}

# ── Patroni VMs ───────────────────────────────────────────────────────────────

variable "pg_vm_id_base" {
  description = "Starting VM ID for Patroni nodes; nodes get base+0..2"
  type        = number
  default     = 210
}

variable "pg_ips" {
  description = "Static IPv4 addresses for the 3 Patroni nodes"
  type        = list(string)
}

variable "pg_network_prefix" {
  description = "CIDR prefix length for the Patroni node subnet"
  type        = number
  default     = 24
}

variable "pg_network_gateway" {
  description = "Default gateway for Patroni nodes"
  type        = string
}

variable "pg_dns_server" {
  description = "DNS server for Patroni nodes"
  type        = string
  default     = "8.8.8.8"
}

variable "pg_username" {
  description = "SSH username on the Ubuntu cloud-init system"
  type        = string
  default     = "ubuntu"
}

variable "pg_ssh_public_key" {
  description = "SSH public key injected into Patroni VMs during NixOS installation"
  type        = string
}

variable "pg_ssh_private_key_path" {
  description = "Local path to the SSH private key used for provisioning"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "pg_cores" {
  type    = number
  default = 4
}

variable "pg_memory_gb" {
  type    = number
  default = 8
}

variable "pg_disk_gb" {
  type    = number
  default = 100
}

# ── PostgreSQL / Patroni ──────────────────────────────────────────────────────

variable "pg_cluster_name" {
  description = "Patroni scope name; must be unique per Proxmox environment"
  type        = string
  default     = "postgres"
}

variable "pg_version" {
  description = "PostgreSQL major version to install"
  type        = string
  default     = "16"
}

variable "etcd_version" {
  description = "etcd release to download and install alongside Patroni"
  type        = string
  default     = "3.5.12"
}

variable "pg_superuser_password" {
  description = "Password for the postgres superuser"
  type        = string
}

variable "pg_replication_password" {
  description = "Password for the replicator user created by Patroni bootstrap"
  type        = string
}
