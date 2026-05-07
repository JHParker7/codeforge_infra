# ── Proxmox connection ────────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://192.168.1.10:8006"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (needed for self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_nodes" {
  description = "Proxmox node name to deploy VMs on"
  type        = list
  default     = ["pve"]
}

variable "template_proxmox_node" {
  description = "Proxmox node name to get template from"
  type        = string
  default     = "pve"
}

# ── Template & storage ────────────────────────────────────────────────────────

variable "template_vm_id" {
  description = "Proxmox VM ID of the Ubuntu cloud-init template to clone"
  type        = number
}

variable "vm_id_base" {
  description = "Starting Proxmox VM ID; nodes get IDs vm_id_base through vm_id_base+5"
  type        = number
  default     = 200
}

variable "datastore" {
  description = "Proxmox datastore for VM disks and cloud-init drives"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge to attach VMs to"
  type        = string
  default     = "vmbr0"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "base_network" {
  description = "First three octets of the node IP range, e.g. 192.168.1"
  type        = string
}

variable "network_prefix" {
  description = "CIDR prefix length for the node subnet"
  type        = number
  default     = 24
}

variable "network_gateway" {
  description = "Default gateway for all VMs"
  type        = string
}

variable "dns_server" {
  description = "DNS server injected via cloud-init"
  type        = string
  default     = "8.8.8.8"
}

variable "control_plane_vip" {
  description = "Floating virtual IP managed by keepalived — used as the Kubernetes API endpoint"
  type        = string
}

variable "cp_ip_start" {
  description = "Last octet of the first control-plane IP (cp-2 and cp-3 get +1 and +2)"
  type        = number
  default     = 11
}

variable "worker_ip_start" {
  description = "Last octet of the first worker IP"
  type        = number
  default     = 21
}

# ── SSH ───────────────────────────────────────────────────────────────────────

variable "ssh_public_key" {
  description = "Public SSH key injected into all VMs via cloud-init"
  type        = string
  default =  null
}

variable "username" {
  description = "username to use with ssh"
  type        = string
  default =  null
}

variable "vm_ssh_private_key_path" {
  description = "Local path to the SSH private key for connecting to VMs"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# ── Control plane sizing ──────────────────────────────────────────────────────

variable "cp_cores" {
  type    = number
  default = 2
}

variable "cp_memory_gb" {
  type    = number
  default = 4
}

variable "cp_disk_gb" {
  type    = number
  default = 50
}

# ── Worker sizing ─────────────────────────────────────────────────────────────

variable "worker_cores" {
  type    = number
  default = 8
}

variable "worker_memory_gb" {
  type    = number
  default = 8
}

variable "worker_disk_gb" {
  type    = number
  default = 100
}

# ── Kubernetes ────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes minor version to install, e.g. 1.31"
  type        = string
  default     = "1.31"
}

variable "pod_cidr" {
  description = "Pod network CIDR — must not overlap node or service networks; Calico default is 192.168.0.0/16"
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Service network CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

variable "calico_version" {
  description = "Calico release to install"
  type        = string
  default     = "3.29.0"
}
