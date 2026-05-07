# ── Proxmox ───────────────────────────────────────────────────────────────────

variable "proxmox_nodes" {
  description = "Proxmox nodes to spread VMs across (round-robin)"
  type        = list(string)
  default     = ["pve"]
}

variable "vm_id_base" {
  description = "Starting VM ID; CPs get base+0..2, workers get base+3..5"
  type        = number
  default     = 200
}

variable "datastore" {
  description = "Proxmox datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "iso_datastore" {
  description = "Proxmox datastore for the Talos ISO"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "network_interface" {
  description = "NIC name inside the VM as reported by Talos (virtio is typically eth0)"
  type        = string
  default     = "eth0"
}

variable "network_gateway" {
  description = "Default gateway — used only in the VIP keepalive check"
  type        = string
}

variable "dns_server" {
  description = "DNS server pushed into all nodes via machine config"
  type        = string
  default     = "8.8.8.8"
}

variable "control_plane_vip" {
  description = "Virtual IP managed by Talos — used as the Kubernetes API endpoint"
  type        = string
}

variable "network_prefix" {
  description = "CIDR prefix length (informational; used in outputs)"
  type        = number
  default     = 24
}

# ── Talos / Kubernetes ────────────────────────────────────────────────────────

variable "talos_version" {
  description = "Talos release to deploy"
  type        = string
  default     = "1.9.5"
}

variable "cluster_name" {
  description = "Kubernetes cluster name embedded in certificates"
  type        = string
  default     = "codeforge"
}

variable "kubernetes_version" {
  description = "Kubernetes version; must be supported by the chosen Talos release"
  type        = string
  default     = "1.32.3"
}

variable "pod_cidr" {
  description = "Pod network CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service network CIDR"
  type        = string
  default     = "10.96.0.0/12"
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
