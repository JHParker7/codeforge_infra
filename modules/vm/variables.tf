variable "name" { type = string }
variable "vm_id" { type = number }
variable "proxmox_node" { type = string }
variable "template_proxmox_node" { type = string }
variable "template_vm_id" { type = number }
variable "cores" { type = number }
variable "memory_gb" { type = number }
variable "disk_gb" { type = number }
variable "datastore" { type = string }
variable "network_bridge" { type = string }
variable "ip_address" { type = string }
variable "cidr_prefix" { type = number }
variable "gateway" { type = string }
variable "dns_server" { type = string }
variable "username" { type = string }
variable "ssh_public_key" {
    type = string
    default = ""
    }
