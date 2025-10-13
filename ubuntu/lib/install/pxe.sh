#!/bin/bash
set -e

# -------------------------------
# PXE Server Auto Installer Script
# For Ubuntu on Raspberry Pi
# -------------------------------

# --- CONFIGURATION ---
STATIC_IP="192.168.4.139"
NETWORK_INTERFACE="eth0"
DHCP_RANGE_START="192.168.4.50"
DHCP_RANGE_END="192.168.4.150"
GATEWAY_IP="192.168.4.139"
DNS_SERVER="8.8.8.8"

BASE_ISO="ubuntu-base.iso"
CUSTOM_ISO="ubuntu-custom.iso"

TFTP_ROOT="/srv/tftp"
NFS_ROOT="/srv/nfs/ubuntu"
ISO_MOUNT="/mnt/iso"

# -------------------------------
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt install -y dnsmasq tftpd-hpa nfs-kernel-server syslinux-common rsync

# -------------------------------
echo "Setting static IP for $NETWORK_INTERFACE (manual step recommended)"
echo "Make sure /etc/netplan is configured for $STATIC_IP before continuing."
sleep 3





# -------------------------------
echo "Configuring dnsmasq (DHCP + TFTP)..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true


sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=$NETWORK_INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h

# PXE boot
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=$TFTP_ROOT

# Optional: specify your gateway and DNS
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$DNS_SERVER
EOF





# --- CONFIGURATION ---
STATIC_IP="192.168.4.139"
NETWORK_INTERFACE="eth0"
DHCP_RANGE_START="192.168.4.50"
DHCP_RANGE_END="192.168.4.150"
GATEWAY_IP="192.168.4.139"
DNS_SERVER="8.8.8.8"

BASE_ISO="ubuntu-base.iso"
CUSTOM_ISO="ubuntu-custom.iso"

TFTP_ROOT="/srv/tftp"
NFS_ROOT="/srv/nfs/ubuntu"
ISO_MOUNT="/mnt/iso"

# -------------------------------
echo "Setting up TFTP directory..."
sudo mkdir -p $TFTP_ROOT/pxelinux.cfg
sudo cp /usr/lib/PXELINUX/pxelinux.0 $TFTP_ROOT/

sudo tee $TFTP_ROOT/pxelinux.cfg/default > /dev/null <<EOF
DEFAULT menu.c32
PROMPT 0
TIMEOUT 50
ONTIMEOUT ubuntu

LABEL ubuntu
  MENU LABEL Install Ubuntu Base
  KERNEL ubuntu/base/vmlinuz
  INITRD ubuntu/base/initrd
  APPEND root=/dev/nfs nfsroot=$STATIC_IP:$NFS_ROOT/base ip=dhcp rw

LABEL custom
  MENU LABEL Install Ubuntu Custom
  KERNEL ubuntu/custom/vmlinuz
  INITRD ubuntu/custom/initrd
  APPEND root=/dev/nfs nfsroot=$STATIC_IP:$NFS_ROOT/custom ip=dhcp rw
EOF

# -------------------------------
echo "Preparing NFS directories..."
sudo mkdir -p $NFS_ROOT/base
sudo mkdir -p $NFS_ROOT/custom

# -------------------------------
function extract_iso() {
    local iso=$1
    local target=$2
    echo "Extracting $iso into $target..."
    if [ ! -f "$iso" ]; then
        echo "Error: $iso not found in current directory!"
        exit 1
    fi
    sudo mkdir -p $ISO_MOUNT
    sudo mount -o loop $iso $ISO_MOUNT
    sudo rsync -a $ISO_MOUNT/ $target/
    sudo umount $ISO_MOUNT
}

# Extract base and custom images
extract_iso $BASE_ISO $NFS_ROOT/base
extract_iso $CUSTOM_ISO $NFS_ROOT/custom

# -------------------------------
echo "Configuring NFS exports..."
sudo tee /etc/exports > /dev/null <<EOF
$NFS_ROOT/base *(ro,sync,no_subtree_check)
$NFS_ROOT/custom *(ro,sync,no_subtree_check)
EOF

sudo exportfs -ra

# -------------------------------
echo "Enabling and starting services..."
sudo systemctl enable --now dnsmasq
sudo systemctl enable --now tftpd-hpa
sudo systemctl enable --now nfs-kernel-server

# -------------------------------
echo "PXE server setup complete!"
echo "Base image:  $NFS_ROOT/base"
echo "Custom image: $NFS_ROOT/custom"
echo "PXE IP: $STATIC_IP"
echo "Clients can now PXE boot on your network."
0