### 2025-12-02 20:01

- I successfully created VM from terraform script with latest provisioner v.0.9.1

### 2025-12-01 23:28

- limitation, cannot destroy vm with nvram

```log
╷
│ Error: Failed to Undefine Domain
│
│ Failed to undefine domain: Requested operation is not valid: cannot undefine domain with nvram
╵

```

- Finally fixed it!
- cloud iso image use UEFI boot, not legacy BIOS boot

### 2025-12-01 22:21

- some log from Claude

```log

Bash(sudo virsh domblkstat my-test-vm vda)
  ⎿  vda rd_req 2895
     vda rd_bytes 47404032
     vda wr_req 2
     … +5 lines (ctrl+o to expand)

● Good! Now I can see the issue. The VM IS using the disk, but barely writing to it:

  vda rd_bytes 47404032   # 45 MB read (booting/reading OS)
  vda wr_bytes 2048       # Only 2 KB written!

  The disk grew from 196KB to 384KB, but the VM has only written 2KB. This suggests the VM is stuck
  during boot or can't write properly. Let me check what's happening:

● Bash(sudo virsh qemu-monitor-command my-test-vm --hmp "info status")
  ⎿  Running…

● Bash(sudo journalctl -u libvirtd --since "10 minutes ago" | grep -i "my-test-vm" | grep -iE
      "error|warn|fail" | head -20)
  ⎿  Waiting…

● Bash(ps aux | grep "[q]emu.*my-test-vm" | grep -o "\-S")
  ⎿  Waiting…

```

- running some diagnostics

````bash
 sudo qemu-img info /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2
image: /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2
file format: qcow2
virtual size: 2.2 GiB (2361393152 bytes)
disk size: 659 MiB
cluster_size: 65536
Format specific information:
    compat: 0.10
    compression type: zlib
    refcount bits: 16
Child node '/file':
    filename: /var/lib/libvirt/images/terraform/my-test-vm-base.qcow2
    protocol type: file
    file length: 659 MiB (691142656 bytes)
    disk size: 659 MiB
```

### 2025-11-23 00:21

- I learn new trick from Claude, to inspect the generated XML from terraform before applying it

```bash
 terraform providers schema -json | jq -r
      '.provider_schemas."registry.terraform.io/dmacvicar/libvirt".resource_schemas.libvirt_volume.block.attributes | keys'
```

### 2025-11-22 17:44

- latest error

```log
│ Error: Invalid Domain Configuration
│
│   with libvirt_domain.vm,
│   on main.tf line 94, in resource "libvirt_domain" "vm":
│   94: resource "libvirt_domain" "vm" {
│
│ Failed to convert domain configuration to XML: failed to lookup volume terraform-vm-cloudinit.iso in pool terraform-pool: Storage
│ volume not found: no storage vol with matching name 'terraform-vm-cloudinit.iso'
╵

playground/libvirt-terraform on  playground-libvirt-terraform [!?] via 💠 default took 19s
❯ sudo virsh vol-list --pool terraform-pool
 Name                      Path
--------------------------------------------------------------------------------------
 terraform-vm-base.qcow2   /var/lib/libvirt/images/terraform/terraform-vm-base.qcow2
 terraform-vm-disk.iso     /var/lib/libvirt/images/terraform/terraform-vm-disk.iso
 terraform-vm-disk.qcow2   /var/lib/libvirt/images/terraform/terraform-vm-disk.qcow2
````

- after that I got new error, but the old one is resolved

```log
│ Error: Domain Creation Failed
│
│   with libvirt_domain.vm,
│   on main.tf line 94, in resource "libvirt_domain" "vm":
│   94: resource "libvirt_domain" "vm" {
│
│ Failed to define domain in libvirt: XML error: an os <type> must be specified
╵
```

### 2025-11-22 16:47

Tried running bootstrap terraform from Claude, got the error

```log
terraform apply test-plan
libvirt_cloudinit_disk.cloudinit: Creating...
libvirt_pool.vm_pool: Creating...
libvirt_cloudinit_disk.cloudinit: Creation complete after 0s [id=467d43007f78559c]
libvirt_pool.vm_pool: Creation complete after 0s [id=acd4e092-d384-4b4a-bce6-d5a380ace496]
libvirt_volume.base_image: Creating...
libvirt_volume.base_image: Still creating... [00m10s elapsed]
libvirt_volume.base_image: Creation complete after 16s [id=/var/lib/libvirt/images/terraform/terraform-vm-base.qcow2]
libvirt_volume.vm_disk: Creating...
libvirt_volume.vm_disk: Creation complete after 0s [id=/var/lib/libvirt/images/terraform/terraform-vm-disk.qcow2]
libvirt_domain.vm: Creating...
╷
│ Error: Invalid Domain Configuration
│
│   with libvirt_domain.vm,
│   on main.tf line 82, in resource "libvirt_domain" "vm":
│   82: resource "libvirt_domain" "vm" {
│
│ Failed to convert domain configuration to XML: failed to lookup volume terraform-vm-cloudinit.iso in pool terraform-pool: Storage
│ volume not found: no storage vol with matching name 'terraform-vm-cloudinit.iso'
```

the `terraform-pool` is created, confirmed by `sudo virsh pool-list`

why no storage volume found?
