output "ip_address" {
  description = "First non-loopback IPv4 reported by the QEMU guest agent"
  value = element([
    for i, name in proxmox_virtual_environment_vm.this.network_interface_names :
    proxmox_virtual_environment_vm.this.ipv4_addresses[i][0]
    if name != "lo" && length(proxmox_virtual_environment_vm.this.ipv4_addresses[i]) > 0
  ], 0)
}
