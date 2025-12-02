output "vm_name" {
  description = "Name of the created VM"
  value       = libvirt_domain.vm.name
}

output "vm_id" {
  description = "ID of the created VM"
  value       = libvirt_domain.vm.id
}

output "vm_ip" {
  description = "IP address of the VM - use 'virsh domifaddr <vm_name>' to get IP address"
  value       = "Check with: virsh domifaddr ${libvirt_domain.vm.name}"
}

output "vm_memory" {
  description = "Memory allocated to the VM in MB"
  value       = libvirt_domain.vm.memory
}

output "vm_vcpu" {
  description = "Number of vCPUs allocated to the VM"
  value       = libvirt_domain.vm.vcpu
}

output "storage_pool" {
  description = "Storage pool name"
  value       = libvirt_pool.vm_pool.name
}

output "disk_volume_id" {
  description = "ID of the VM disk volume"
  value       = libvirt_volume.vm_disk.id
}

output "disk_size_bytes" {
  description = "Size of the VM disk in bytes"
  value       = libvirt_volume.vm_disk.capacity
}
