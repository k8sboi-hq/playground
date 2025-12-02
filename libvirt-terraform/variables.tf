variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "storage_pool_name" {
  description = "Name of the storage pool"
  type        = string
  default     = "terraform-pool"
}

variable "storage_pool_path" {
  description = "Path for the storage pool directory"
  type        = string
  default     = "/var/lib/libvirt/images/terraform"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "terraform-vm"
}

variable "domain" {
  description = "Domain name for FQDN"
  type        = string
  default     = "local"
}

variable "memory" {
  description = "Amount of memory in MB"
  type        = number
  default     = 2048
}

variable "vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 2
}

variable "disk_size" {
  description = "Size of the VM disk in bytes"
  type        = number
  default     = 10737418240 # 10GB
}

variable "base_image_url" {
  description = "URL to download the base OS image"
  type        = string
  default     = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
}

variable "network_name" {
  description = "Name of the libvirt network to use"
  type        = string
  default     = "default"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "vm_user" {
  description = "Default user for the VM"
  type        = string
  default     = "terraform"
}
variable "vm_user_password_hashed" {
  description = "Default user password for the VM"
  type        = string
  default     = ""
}
