# Debugging UEFI Boot Failure in libvirt/Terraform VM

## Problem Statement

VM created with Terraform and libvirt provider was failing to boot with the following error:
```
BdsDxe: failed to load Boot0002 "UEFI Misc Device" from PciRoot(0x0)/Pci(0x2,0x2)/Pci(0x0,0x0): Not Found
BdsDxe: No bootable option or device was found.
BdsDxe: Press any key to enter the Boot Manager Menu.
```

## Debugging Workflow

### Step 1: Understand the Infrastructure Configuration

**What I checked**: Read the Terraform configuration files (`main.tf`, `cloud_init.cfg`, `variables.tf`, `terraform.tfvars`)

**Why**: To understand:
- What OS image is being used (Fedora 42 Cloud Base)
- How the VM is configured (UEFI/EFI firmware, Q35 machine type)
- Disk configuration (virtio bus, qcow2 format with backing store)
- Boot configuration (EFI loader paths, NVRAM settings)

**Key findings**:
- VM configured with UEFI/EFI firmware: `firmware = "efi"`
- Using OVMF (Open Virtual Machine Firmware)
- Disk created from base image with backing store
- Cloud-init configured for first boot

### Step 2: Verify VM Exists and State

**What I checked**:
```bash
sudo virsh list --all
```

**Why**: Confirm the VM is actually created and running, not just a Terraform state issue

**Finding**: VM `my-test-vm` exists and is in "running" state (ID: 39)

### Step 3: Examine Terraform State

**What I checked**:
```bash
terraform show
```

**Why**: Verify what Terraform thinks it created vs actual infrastructure

**Key findings**:
- All resources created successfully
- Disk volumes exist in the storage pool
- Cloud-init disk generated
- Domain (VM) configuration applied

### Step 4: Check VM's Block Devices

**What I checked**:
```bash
sudo virsh domblkstat my-test-vm vda
sudo virsh qemu-monitor-command my-test-vm --hmp "info block"
```

**Why**: Verify disks are attached and accessible by the VM

**Findings**:
- Main disk (`vda`) attached to virtio backend
- Cloud-init ISO attached to SATA (`sda`)
- Disk paths correct: `/var/lib/libvirt/images/terraform/my-test-vm-disk.qcow2`
- Only 83 read requests to vda - very low, suggesting boot isn't progressing

### Step 5: Verify Base Image Integrity

**What I checked**:
```bash
ls -lh /home/khoahd/working/playground/libvirt-terraform/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2
sudo qemu-img info /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2
```

**Why**: Ensure the source image exists and wasn't corrupted during copy

**Findings**:
- Base image: 508 MB, qcow2 format
- Virtual size: 5 GiB
- Image appears intact

### Step 6: Analyze Disk Partition Layout

**What I checked**:
```bash
sudo virt-filesystems --long --parts --blkdevs -h -a /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2
sudo virt-filesystems --long -a /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2
```

**Why**: Confirm the image has proper partitions, especially an EFI System Partition (ESP)

**Findings**:
- `/dev/sda1`: 2.0M (BIOS boot partition)
- `/dev/sda2`: 100M vfat labeled "EFI" ✅ **EFI System Partition found**
- `/dev/sda3`: 1000M ext4 labeled "BOOT"
- `/dev/sda4`: 3.9G btrfs labeled "fedora" (root filesystem)

This is a properly structured UEFI-bootable disk.

### Step 7: Verify EFI Partition Contents

**What I checked**:
```bash
sudo guestfish -a /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2 -r <<'EOF'
run
mount /dev/sda2 /
ls /
find /
EOF
```

**Why**: Ensure the EFI partition contains bootloader files (GRUB, shim)

**Findings**: ✅ All necessary files present:
```
EFI/BOOT/BOOTX64.EFI    # Fallback bootloader
EFI/BOOT/grubx64.efi
EFI/fedora/grubx64.efi  # Fedora's GRUB
EFI/fedora/shim.efi     # Secure Boot shim
EFI/fedora/shimx64.efi
```

The image has proper UEFI boot files, so the issue isn't with the image itself.

### Step 8: Inspect VM's XML Configuration

**What I checked**:
```bash
sudo virsh dumpxml my-test-vm | grep -A 50 "os"
```

**Why**: See how libvirt actually configured the VM (may differ from Terraform)

**Critical findings**:
```xml
<os firmware='efi'>
  <type arch='x86_64' machine='pc-q35-9.2'>hvm</type>
  <loader readonly='yes' secure='no' type='pflash'>/usr/share/edk2/ovmf/OVMF_CODE.fd</loader>
  <nvram template='/usr/share/edk2/ovmf/OVMF_VARS.fd'>/var/lib/libvirt/qemu/nvram/my-test-vm.fd</nvram>
  <boot dev='hd'/>
</os>
...
<disk type='volume' device='disk'>
  <driver name='qemu' type='raw'/>  ⚠️ **PROBLEM FOUND**
  <source pool='terraform-pool' volume='my-test-vm-disk.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

**THE ROOT CAUSE**: Driver type set to `raw` but disk is actually `qcow2`!

### Step 9: Confirm Disk Format Mismatch

**What I checked**:
```bash
sudo file /var/lib/libvirt/images/terraform/my-test-vm-disk.qcow2
```

**Why**: Verify the actual disk format

**Finding**:
```
QEMU QCOW Image (v3), has backing file (path /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2)
```

Confirmed: Disk IS qcow2, but libvirt is treating it as raw format.

## Root Cause Analysis

When libvirt tries to read a qcow2 disk as raw format:
1. It doesn't understand the qcow2 header/metadata
2. Cannot follow the backing store chain
3. Cannot read the actual partition table
4. UEFI firmware cannot find bootable partitions
5. Boot fails with "No bootable option or device"

## The Fix

Add explicit driver configuration in `main.tf`:

```hcl
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
    driver = {           # ← Added this
      name = "qemu"
      type = "qcow2"     # ← Explicitly specify format
    }
  },
  # ... cloud-init disk ...
]
```

## Why This Happened

The libvirt Terraform provider didn't automatically detect/set the disk format from the volume's configuration. Even though we specified:

```hcl
resource "libvirt_volume" "vm_disk" {
  target = {
    format = {
      type = "qcow2"  # This wasn't propagated to the domain disk config
    }
  }
}
```

The format needs to be explicitly set in the `libvirt_domain` resource's disk configuration.

## Debugging Lessons Learned

### 1. **Follow the Boot Path**
- Start from where the error occurs (UEFI firmware)
- Work backwards: Firmware → Disk → Partitions → Boot files

### 2. **Verify Each Layer**
- Image integrity (qemu-img)
- Partition structure (virt-filesystems)
- File presence (guestfish)
- VM configuration (virsh dumpxml)

### 3. **Check Configuration vs Reality**
- What Terraform says (terraform show)
- What libvirt says (virsh dumpxml)
- What the actual files are (file, qemu-img info)

### 4. **Low-Level Inspection Tools**
- `qemu-img info` - Image format and backing chains
- `virt-filesystems` - Partition layout
- `guestfish` - Mount and explore images
- `virsh dumpxml` - Actual running configuration
- `virsh domblkstat` - Disk I/O statistics (low reads = not booting)

### 5. **Common UEFI Boot Issues**
When a UEFI VM won't boot, check:
1. ✅ Firmware files exist (OVMF_CODE.fd, OVMF_VARS.fd)
2. ✅ EFI partition exists and is FAT32
3. ✅ Bootloader files present (BOOTX64.EFI, grubx64.efi)
4. ❌ **Disk driver format matches actual format** ← Our issue
5. Boot order in firmware
6. NVRAM corruption

## Prevention

Always explicitly set disk driver type in Terraform:

```hcl
# For qcow2 disks
driver = {
  name = "qemu"
  type = "qcow2"
}

# For raw disks/ISOs
driver = {
  name = "qemu"
  type = "raw"
}
```

## References

- [libvirt Domain XML format](https://libvirt.org/formatdomain.html#hard-drives-floppy-disks-cdroms)
- [QEMU disk image formats](https://www.qemu.org/docs/master/system/images.html)
- [UEFI boot process](https://en.wikipedia.org/wiki/UEFI#Booting)
- [OVMF (UEFI firmware for VMs)](https://github.com/tianocore/tianocore.github.io/wiki/OVMF)

---

**Date**: 2025-12-02
**VM**: my-test-vm (Fedora 42 Cloud Base)
**Environment**: libvirt on Fedora 42 host
**Terraform Provider**: dmacvicar/libvirt ~> 0.9.1
