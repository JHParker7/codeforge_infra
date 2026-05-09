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

# ── Talos ─────────────────────────────────────────────────────────────────────

variable "talos_version" {
  description = "Talos release to deploy"
  type        = string
  default     = "1.13.0"
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
