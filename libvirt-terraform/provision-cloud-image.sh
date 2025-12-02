#!/usr/bin/env bash

set -e

VM_NAME="nfs-server"
IMAGE_DIR="/var/lib/libvirt/images"
CONFIG_DIR="${HOME}/cloud-init-configs/${VM_NAME}"

echo "=== NFS Server VM Setup with SSH Keys ==="

# TODO: templating this
# Check for SSH key
if [ ! -f ~/.ssh/id_ed25519.pub ] && [ ! -f ~/.ssh/id_rsa.pub ]; then
	echo "No SSH key found. Generating one..."
	ssh-keygen -t ed25519 -C "homelab-key" -f ~/.ssh/id_ed25519 -N ""
fi

# Get SSH public key
if [ -f ~/.ssh/id_ed25519.pub ]; then
	SSH_PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)
elif [ -f ~/.ssh/id_rsa.pub ]; then
	SSH_PUB_KEY=$(cat ~/.ssh/id_rsa.pub)
else
	echo "Error: No SSH public key found"
	exit 1
fi

echo "Using SSH public key: ${SSH_PUB_KEY:0:50}..."

# Create config directory
mkdir -p "${CONFIG_DIR}"

# Create user-data with SSH key
cat >"${CONFIG_DIR}/user-data" <<EOF
#cloud-config
hostname: nfs-server
fqdn: nfs-server.local
timezone: Asia/Ho_Chi_Minh

users:
  - name: root
    lock_passwd: false
    passwd: 
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}
  - name: daniel
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: 
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}

packages:
  - nfs-utils
  - firewalld
  - vim
  - htop
  - policycoreutils-python-utils

runcmd:
  - systemctl enable --now sshd firewalld nfs-server
  - firewall-cmd --permanent --add-service=ssh
  - firewall-cmd --permanent --add-service=nfs
  - firewall-cmd --permanent --add-service=rpc-bind
  - firewall-cmd --permanent --add-service=mountd
  - firewall-cmd --reload
  - mkdir -p /srv/nfs/k8s-volumes /srv/nfs/k8s-backups
  - chown -R nobody:nobody /srv/nfs
  - chmod 755 /srv/nfs/k8s-volumes
  - semanage fcontext -a -t nfs_t "/srv/nfs/k8s-volumes(/.*)?"
  - semanage fcontext -a -t nfs_t "/srv/nfs/k8s-backups(/.*)?"
  - restorecon -R /srv/nfs
  - setsebool -P nfs_export_all_rw on

power_state:
  mode: reboot
  condition: true
EOF

cat >"${CONFIG_DIR}/meta-data" <<EOF
instance-id: ${VM_NAME}-001
local-hostname: ${VM_NAME}
EOF

cat >"${CONFIG_DIR}/network-config" <<EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF

# Download cloud image if needed
echo "Checking for cloud image..."
cd "${IMAGE_DIR}"
if [ ! -f "fedora-cloud-base.qcow2" ]; then
	echo "Downloading Fedora Cloud Base..."
	sudo wget -O fedora-cloud-base.qcow2 \
		https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2
fi

# Create VM disks
echo "Creating VM disks..."
sudo cp fedora-cloud-base.qcow2 ${VM_NAME}.qcow2
sudo qemu-img resize ${VM_NAME}.qcow2 20G
sudo qemu-img create -f qcow2 ${VM_NAME}-data.qcow2 500G

# Create cloud-init ISO
echo "Creating cloud-init ISO..."
sudo genisoimage \
	-output ${IMAGE_DIR}/${VM_NAME}-cidata.iso \
	-volid cidata -joliet -rock \
	"${CONFIG_DIR}/user-data" \
	"${CONFIG_DIR}/meta-data" \
	"${CONFIG_DIR}/network-config"

# Remove old VM if exists
virsh destroy ${VM_NAME} 2>/dev/null || true
virsh undefine ${VM_NAME} --remove-all-storage 2>/dev/null || true

# Create VM
echo "Creating VM..."
virt-install \
	--name ${VM_NAME} \
	--memory 2048 \
	--vcpus 2 \
	--disk ${IMAGE_DIR}/${VM_NAME}.qcow2,device=disk,bus=virtio \
	--disk ${IMAGE_DIR}/${VM_NAME}-data.qcow2,device=disk,bus=virtio \
	--disk ${IMAGE_DIR}/${VM_NAME}-cidata.iso,device=cdrom \
	--os-variant fedora41 \
	--network network=default,model=virtio \
	--graphics none \
	--import \
	--noautoconsole

echo ""
echo "=== VM Created! ==="
echo "Waiting for cloud-init to complete (90 seconds)..."
sleep 90

echo ""
echo "Getting IP address..."
VM_IP=$(virsh domifaddr ${VM_NAME} | grep -oP '192\.168\.\d+\.\d+' | head -1)

if [ -n "${VM_IP}" ]; then
	echo "VM IP: ${VM_IP}"
	echo ""
	echo "Test SSH connection:"
	echo "  ssh daniel@${VM_IP}"
	echo "  ssh root@${VM_IP}"
	echo ""
	echo "No password should be required if SSH key is configured correctly!"
else
	echo "Could not determine IP. Check with: virsh domifaddr ${VM_NAME}"
fi
