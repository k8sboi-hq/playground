# Libvirt Terraform IaC

This is a playground for provisioning virtual machines using Infrastructure as Code (IaC) with Terraform and the [dmacvicar/libvirt provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs) (v0.9.0).

With IaC, provisioning VMs should be as easy as possible - define your infrastructure in code, version control it, and provision consistently every time.

## What's Included

This Terraform configuration provisions:
- **Storage Pool**: Directory-based storage pool for VM images
- **Base Image**: Downloads cloud-ready OS images (Fedora, CentOS Stream, Ubuntu, or Debian)
- **VM Disk**: Creates a disk volume from the base image
- **Cloud-Init**: Configures VMs on first boot (users, SSH keys, packages)
- **Virtual Machine**: Complete VM with configurable CPU, memory, and network

## Prerequisites

### 1. Install KVM/QEMU and libvirt

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install qemu-kvm libvirt virt-install virt-manager
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

**Verify installation:**
```bash
virsh version
sudo virsh list --all
```

### 2. Install Terraform

**Using package manager (Fedora/RHEL):**
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install terraform
```

**Using package manager (Ubuntu/Debian):**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Verify installation:**
```bash
terraform version
```

### 3. Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t ed25519 -C "terraform-vm" -f ~/.ssh/terraform_vm
```

## Getting Started

### 1. Configure Variables

Copy the example configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update the values:
```hcl
# Required: Add your SSH public key
ssh_public_key = "ssh-ed25519 AAAAC3Nza... your-email@example.com"

# Optional: Customize VM settings
vm_name = "my-test-vm"
memory  = 2048  # MB
vcpu    = 2
```

**Important**: `terraform.tfvars` is gitignored to prevent committing sensitive data.

### 2. Initialize Terraform

Download the provider and initialize the backend:
```bash
terraform init
```

### 3. Plan the Deployment

Review what will be created:
```bash
terraform plan
```

### 4. Apply the Configuration

Create the VM:
```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Access Your VM

After successful deployment, get the VM's IP address:
```bash
terraform output vm_ip
```

SSH into the VM:
```bash
ssh -i ~/.ssh/terraform_vm terraform@<VM_IP>
```

## Managing VMs

### View VM Information

```bash
# Show all outputs
terraform output

# Show specific output
terraform output vm_ip

# List VMs with virsh
virsh list --all

# Show VM info
virsh dominfo my-test-vm
```

### Modify VM Configuration

Edit `terraform.tfvars` to change settings:
```hcl
memory = 4096  # Increase to 4GB
vcpu   = 4     # Increase to 4 CPUs
```

Apply changes:
```bash
terraform apply
```

**Note**: Some changes (like memory/CPU) may require VM restart.

### Destroy VM

Remove all resources:
```bash
terraform destroy
```

Type `yes` when prompted.

## Configuration Options

### Available Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `libvirt_uri` | Libvirt connection URI | `qemu:///system` |
| `storage_pool_name` | Storage pool name | `terraform-pool` |
| `storage_pool_path` | Storage pool directory | `/var/lib/libvirt/images/terraform` |
| `vm_name` | Virtual machine name | `terraform-vm` |
| `domain` | Domain for FQDN | `local` |
| `memory` | Memory in MB | `2048` |
| `vcpu` | Number of CPUs | `2` |
| `disk_size` | Disk size in bytes | `10737418240` (10GB) |
| `base_image_url` | OS image URL | Fedora 42 |
| `network_name` | Libvirt network | `default` |
| `ssh_public_key` | SSH public key | (required) |
| `vm_user` | Default username | `terraform` |

### Supported OS Images

The configuration uses cloud-init compatible images:

**Fedora 42** (default):
```hcl
base_image_url = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
```

**CentOS Stream 9**:
```hcl
base_image_url = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
```

**Ubuntu 22.04 LTS**:
```hcl
base_image_url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
```

**Debian 12**:
```hcl
base_image_url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
```

## Cloud-Init Customization

The `cloud_init.cfg` file controls VM initialization. You can customize:

- User creation and SSH keys
- Package installation
- Initial commands
- Network configuration
- Timezone and locale

Edit `cloud_init.cfg` and run `terraform apply` to update.

## Troubleshooting

### Permission Denied

If you get permission errors:
```bash
# Add yourself to libvirt group
sudo usermod -aG libvirt $USER

# Log out and back in, or run:
newgrp libvirt

# Verify permissions
groups | grep libvirt
```

### Storage Pool Creation Failed

If the storage pool directory doesn't exist:
```bash
sudo mkdir -p /var/lib/libvirt/images/terraform
sudo chown -R $USER:libvirt /var/lib/libvirt/images/terraform
```

### VM Not Getting IP Address

Check the default network:
```bash
virsh net-list --all
virsh net-start default  # If not active
virsh net-autostart default
```

### Download Base Image Manually

If automatic download fails:
```bash
cd /var/lib/libvirt/images/terraform
wget https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2
```

### View VM Console

If SSH doesn't work, access the console:
```bash
virsh console my-test-vm
# Press Ctrl+] to exit
```

## Advanced Usage

### Multiple VMs

To create multiple VMs, use Terraform count or for_each:

```hcl
# In main.tf, modify the domain resource:
resource "libvirt_domain" "vm" {
  count  = var.vm_count
  name   = "${var.vm_name}-${count.index}"
  # ... rest of configuration
}
```

### Custom Network

Create a custom network:
```hcl
resource "libvirt_network" "custom_net" {
  name      = "terraform-net"
  mode      = "nat"
  domain    = "terraform.local"
  addresses = ["10.17.3.0/24"]
}
```

### Remote libvirt

Connect to remote KVM host:
```hcl
libvirt_uri = "qemu+ssh://user@remote-host/system"
```

## File Structure

```
.
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output definitions
├── cloud_init.cfg             # Cloud-init user data template
├── terraform.tfvars.example   # Example configuration
├── terraform.tfvars           # Your configuration (gitignored)
├── .gitignore                 # Git ignore rules
└── README.md                  # This file
```

## Cleanup

To completely remove all Terraform resources:

```bash
# Destroy VMs and volumes
terraform destroy

# Remove Terraform files (optional)
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Resources

- [Libvirt Provider Documentation](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [KVM/QEMU Documentation](https://www.linux-kvm.org/page/Documents)

## Security Notes

- Never commit `terraform.tfvars` (contains sensitive data)
- Never commit SSH private keys
- Use strong SSH keys (ed25519 or RSA 4096-bit)
- Keep Terraform state file secure (contains sensitive data)
- For production, use remote state backend with encryption