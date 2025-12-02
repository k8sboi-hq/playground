terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.1"
    }
  }

  # Local backend configuration
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# Create a storage pool
resource "libvirt_pool" "vm_pool" {
  name = var.storage_pool_name
  type = "dir"
  target = {
    path = var.storage_pool_path
  }
}

# Download base image
resource "libvirt_volume" "base_image" {
  name = "${var.vm_name}-base.qcow2"
  pool = libvirt_pool.vm_pool.name

  create = {
    content = {
      url = var.base_image_url
    }
  }
}

# Create volume for VM from base image
resource "libvirt_volume" "vm_disk" {
  name     = "${var.vm_name}-disk.qcow2"
  pool     = libvirt_pool.vm_pool.name
  capacity = var.disk_size
  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.base_image.path
    format = {
      type = "qcow2"
    }
  }
}

# Cloud-init configuration
data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")

  vars = {
    hostname = var.vm_name
    fqdn     = "${var.vm_name}.${var.domain}"
    ssh_key  = var.ssh_public_key
    vm_user  = var.vm_user
    vm_user_password_hashed = var.vm_user_password_hashed
  }
}

data "template_file" "meta_data" {
  template = file("${path.module}/meta_data.cfg")

  vars = {
    hostname = var.vm_name
  }
}

data "template_file" "network_config" {
  template = <<-EOF
    version: 2
    ethernets:
      eth0:
        dhcp4: true
  EOF
}

# Cloud-init disk for initial configuration
resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm_name}-cloudinit.iso"
  user_data      = data.template_file.user_data.rendered
  meta_data      = data.template_file.meta_data.rendered
  network_config = data.template_file.network_config.rendered
}

# Upload the cloud-init ISO into the pool.
resource "libvirt_volume" "cloudinit_volume" {
  name = "${var.vm_name}-cloudinit.iso"
  pool = libvirt_pool.vm_pool.name

  create = {
    content = {
      url = libvirt_cloudinit_disk.cloudinit.path
    }
  }
}

# Define the VM domain
resource "libvirt_domain" "vm" {
  name        = var.vm_name
  memory      = var.memory
  vcpu        = var.vcpu
  memory_unit = "MiB"
  type        = "kvm"

  os = {
    type         = "hvm"
    type_machine = "q35"
    type_arch    = "x86_64"
    boot_devices = [{
      dev = "hd"
    }]
    firmware        = "efi"
    loader          = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    loader_readonly = "yes"
    loader_type     = "pflash"
    loader_secure   = "no"
    nv_ram = {
      nv_ram   = "/var/lib/libvirt/qemu/nvram/${var.vm_name}.fd"
      template = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
    }
  }

  # Configure NVRAM to be removed on destroy


  # Enable ACPI for cloud images
  features = {
    acpi = true
  }


  devices = {
    # Disks
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.vm_pool.name
            volume = libvirt_volume.vm_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          name = "qemu"
          type = "qcow2"
        }
      },
      {
        source = {
          volume = {
            pool   = libvirt_volume.cloudinit_volume.pool
            volume = libvirt_volume.cloudinit_volume.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        device = "cdrom"
        driver = {
          name = "qemu"
          type = "raw"
        }
      }
    ]

    # Network interfaces
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = var.network_name
          }
        }
        # wait_for_ip = {
        #   source  = "lease"
        #   timeout = 300
        # }
      }
    ]

    # Console for debugging
    consoles = [
      {
        type        = "pty"
        target_type = "serial"
        target_port = 0
      }
    ]

    # Graphics for virt-manager access
    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]
  }
}
