#!/usr/bin/env bash
set -euo pipefail

# setup-pxe.sh
# Idempotent PXE/NFS/TFTP setup that by default publishes a single Ubuntu LTS headless image.
# Re-running with arguments can switch the served image to a custom ISO or an image downloaded from a URL.

# Defaults
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}
STATIC_IP=${STATIC_IP:-"192.168.4.139"}
DHCP_RANGE_START=${DHCP_RANGE_START:-"192.168.4.50"}
DHCP_RANGE_END=${DHCP_RANGE_END:-"192.168.4.150"}
GATEWAY_IP=${GATEWAY_IP:-"192.168.4.139"}
DNS_SERVER=${DNS_SERVER:-"8.8.8.8"}

TFTP_ROOT=${TFTP_ROOT:-"/srv/tftp"}
NFS_ROOT=${NFS_ROOT:-"/srv/nfs/pxe"}
ISO_MOUNT=${ISO_MOUNT:-"/mnt/iso"}
EXPORTS_FILE=${EXPORTS_FILE:-"/etc/exports.d/pxe.exports"}
DNSMASQ_CONF=${DNSMASQ_CONF:-"/etc/dnsmasq.conf"}

# Behavior controls
DRY_RUN=0
FORCE=0
IMAGE="ubuntu-lts-headless" # default image identifier
BASE_ISO=""                # path to ISO for built-in LTS if user provides
CUSTOM_ISO=""
IMAGE_URL=""               # optional URL to download an ISO
UBUNTU_LTS_VERSION=${UBUNTU_LTS_VERSION:-"24.04"}

print_help(){
  cat <<EOF
Usage: $0 [options]

Options:
  --interface IFACE        Network interface (default: $NETWORK_INTERFACE)
  --static-ip IP          PXE/NFS host IP (default: $STATIC_IP)
  --image NAME            Image to publish: 'ubuntu-lts-headless' (default) or 'custom'
  --base-iso PATH         Path to ISO for the Ubuntu LTS image (optional)
  --custom-iso PATH       Path to a custom ISO to publish when --image custom
  --image-url URL         Download ISO from URL and publish it
  --force                 Overwrite existing served image
  --dry-run               Print actions but do not modify the system
  -h, --help              Show this help

Examples:
  # Default: set up PXE and serve Ubuntu LTS headless (downloads if --base-iso not provided)
  sudo $0

  # Serve a custom ISO (already present locally)
  sudo $0 --image custom --custom-iso /path/to/custom.iso --force

  # Download and serve an ISO from a URL
  sudo $0 --image custom --image-url https://example.com/myiso.iso --force
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --interface) NETWORK_INTERFACE="$2"; shift 2;;
    --static-ip) STATIC_IP="$2"; shift 2;;
    --image) IMAGE="$2"; shift 2;;
    --base-iso) BASE_ISO="$2"; shift 2;;
    --custom-iso) CUSTOM_ISO="$2"; shift 2;;
    --image-url) IMAGE_URL="$2"; shift 2;;
    --force) FORCE=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) print_help; exit 0;;
    --) shift; break;;
    *) echo "Unknown option: $1"; print_help; exit 2;;
  esac
done

run_cmd(){
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

require_cmd(){
  command -v "$1" >/dev/null 2>&1 || { echo "Required command '$1' not found" >&2; exit 1; }
}

# Wait for IP address to appear on interface
_wait_for_ip(){
  local ip="$1"
  local interface="$2"
  local max_wait=30
  local elapsed=0
  
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would wait for IP $ip to be configured on $interface (up to ${max_wait}s)"
    return 0
  fi
  
  echo "Waiting for IP $ip to be configured on $interface..."
  while [ $elapsed -lt $max_wait ]; do
    # Use precise matching with "/" or space or end of line after IP to avoid partial matches
    if ip addr show "$interface" 2>/dev/null | grep -qE "inet ${ip}(/| |$)"; then
      echo "IP $ip is now active on $interface"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  
  echo "Warning: IP $ip not detected on $interface after ${max_wait}s. Continuing anyway..."
  return 1
}

# Helper function to check if an ISO URL exists
try_download_iso(){
  local url="$1"
  echo "Checking ISO URL: $url"
  if curl -f -I -s --connect-timeout 10 --max-time 30 "$url" >/dev/null 2>&1; then
    echo "$url"
    return 0
  fi
  return 1
}

# Helper function to parse HTML page for ISO filename
find_iso_on_page(){
  local page_url="$1"
  echo "Searching for ISO on: $page_url"
  local iso_filename
  iso_filename=$(curl -s --connect-timeout 10 --max-time 30 "$page_url" 2>/dev/null | grep -o 'href="[^"]*live-server-amd64\.iso"' | head -1 | sed 's/href="//;s/"//')
  if [ -n "$iso_filename" ]; then
    echo "$iso_filename"
    return 0
  fi
  return 1
}

require_cmd rsync
require_cmd tee

echo "Setting up PXE (image=$IMAGE)"

echo "Installing packages: dnsmasq tftpd-hpa nfs-kernel-server syslinux-common rsync"
run_cmd sudo apt-get update
run_cmd sudo apt-get install -y dnsmasq tftpd-hpa nfs-kernel-server syslinux-common rsync curl

echo "Configure dnsmasq (backup existing if present)"
if [ -f "$DNSMASQ_CONF" ]; then
  run_cmd sudo cp -f "$DNSMASQ_CONF" "${DNSMASQ_CONF}.backup"
fi

# Create drop-in configuration to avoid conflicts with systemd-resolved
run_cmd sudo mkdir -p /etc/dnsmasq.d

# Detect if systemd-resolved is active
SYSTEMD_RESOLVED_ACTIVE=0
if [ "$DRY_RUN" -eq 1 ]; then
  # Check without sudo in dry-run mode (try with sudo first as fallback)
  if systemctl is-active --quiet systemd-resolved 2>/dev/null || sudo systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    SYSTEMD_RESOLVED_ACTIVE=1
    echo "systemd-resolved is active - would configure dnsmasq for DHCP/TFTP-only mode (port=0)"
  fi
else
  if sudo systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    SYSTEMD_RESOLVED_ACTIVE=1
    echo "systemd-resolved is active - configuring dnsmasq for DHCP/TFTP-only mode (port=0)"
  fi
fi

# Build dnsmasq configuration
if [ $SYSTEMD_RESOLVED_ACTIVE -eq 1 ]; then
  run_cmd sudo tee /etc/dnsmasq.d/pxe.conf > /dev/null <<EOF
# PXE-specific configuration - scoped to interface to avoid conflicts with systemd-resolved
# Using port=0 to disable DNS service (DHCP/TFTP-only mode) because systemd-resolved is active
interface=$NETWORK_INTERFACE
bind-dynamic
port=0
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=$TFTP_ROOT
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$DNS_SERVER
EOF
else
  run_cmd sudo tee /etc/dnsmasq.d/pxe.conf > /dev/null <<EOF
# PXE-specific configuration - scoped to interface
interface=$NETWORK_INTERFACE
bind-dynamic
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=$TFTP_ROOT
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$DNS_SERVER
EOF
fi

echo "Prepare TFTP and NFS directories"
run_cmd sudo mkdir -p "$TFTP_ROOT/pxelinux.cfg"
run_cmd sudo mkdir -p "$NFS_ROOT"
run_cmd sudo mkdir -p "$ISO_MOUNT"

PXELINUX_SRC="/usr/lib/PXELINUX/pxelinux.0"
if [ -f "$PXELINUX_SRC" ]; then
  run_cmd sudo cp -f "$PXELINUX_SRC" "$TFTP_ROOT/"
fi

# Decide target name for the served image
if [ "$IMAGE" = "ubuntu-lts-headless" ]; then
  SERVE_NAME="ubuntu-lts"
else
  SERVE_NAME="custom"
fi

TARGET_DIR="$NFS_ROOT/$SERVE_NAME"

if [ -d "$TARGET_DIR" ] && [ $FORCE -ne 1 ]; then
  echo "Target image '$SERVE_NAME' already exists at $TARGET_DIR. Re-run with --force to overwrite or choose another image name." >&2
else
  echo "Preparing $TARGET_DIR"
  run_cmd sudo rm -rf "$TARGET_DIR" || true
  run_cmd sudo mkdir -p "$TARGET_DIR"

  download_and_extract(){
    local iso_path="$1"
    echo "Extracting ISO '$iso_path' to $TARGET_DIR"
    run_cmd sudo mount -o loop "$iso_path" "$ISO_MOUNT"
    run_cmd sudo rsync -a "$ISO_MOUNT/" "$TARGET_DIR/"
    run_cmd sudo umount "$ISO_MOUNT"
  }

  if [ "$IMAGE" = "ubuntu-lts-headless" ]; then
    # Choose a base ISO either provided or download using UBUNTU_LTS_VERSION
    if [ -n "$BASE_ISO" ]; then
      ISO_TO_USE="$BASE_ISO"
    elif [ -n "$IMAGE_URL" ]; then
      ISO_TO_USE="/var/tmp/$(basename "$IMAGE_URL")"
      run_cmd sudo mkdir -p /var/tmp
      run_cmd sudo curl -L --fail --connect-timeout 30 --max-time 3600 -o "$ISO_TO_USE" "$IMAGE_URL"
    else
      # Build Ubuntu releases URL with robust fallback
      ISO_NAME="ubuntu-${UBUNTU_LTS_VERSION}-live-server-amd64.iso"
      ISO_TO_USE="/var/tmp/$ISO_NAME"
      DOWNLOAD_URL="https://releases.ubuntu.com/${UBUNTU_LTS_VERSION}/${ISO_NAME}"
      
      echo "No base ISO provided - attempting to download Ubuntu LTS"
      
      # Try the initially constructed URL first
      if try_download_iso "$DOWNLOAD_URL"; then
        echo "Found ISO at $DOWNLOAD_URL"
      else
        echo "Initial URL failed, trying to find ISO on releases page..."
        # Try to find the ISO on the releases.ubuntu.com page
        RELEASES_PAGE="https://releases.ubuntu.com/${UBUNTU_LTS_VERSION}/"
        if ISO_FILENAME=$(find_iso_on_page "$RELEASES_PAGE"); then
          DOWNLOAD_URL="${RELEASES_PAGE}${ISO_FILENAME}"
          echo "Found ISO: $DOWNLOAD_URL"
          ISO_TO_USE="/var/tmp/$ISO_FILENAME"
        else
          echo "ISO not found on releases page, trying cdimage.ubuntu.com..."
          # Try cdimage.ubuntu.com as final fallback
          CDIMAGE_PAGE="https://cdimage.ubuntu.com/releases/${UBUNTU_LTS_VERSION}/release/"
          if ISO_FILENAME=$(find_iso_on_page "$CDIMAGE_PAGE"); then
            DOWNLOAD_URL="${CDIMAGE_PAGE}${ISO_FILENAME}"
            echo "Found ISO: $DOWNLOAD_URL"
            ISO_TO_USE="/var/tmp/$ISO_FILENAME"
          else
            echo "ERROR: Could not find Ubuntu ${UBUNTU_LTS_VERSION} live-server ISO" >&2
            echo "Please check the following URLs manually to find the ISO filename:" >&2
            echo "  - $RELEASES_PAGE" >&2
            echo "  - $CDIMAGE_PAGE" >&2
            echo "Then run: sudo $0 --image-url <ISO_URL>" >&2
            exit 1
          fi
        fi
      fi
      
      echo "Downloading ISO from: $DOWNLOAD_URL"
      run_cmd sudo mkdir -p /var/tmp
      run_cmd sudo curl -L --fail --connect-timeout 30 --max-time 3600 -o "$ISO_TO_USE" "$DOWNLOAD_URL"
    fi
    if [ ! -f "$ISO_TO_USE" ]; then
      echo "ISO not found: $ISO_TO_USE" >&2
      exit 1
    fi
    download_and_extract "$ISO_TO_USE"

  else
    # custom image
    if [ -n "$CUSTOM_ISO" ]; then
      ISO_TO_USE="$CUSTOM_ISO"
    elif [ -n "$IMAGE_URL" ]; then
      ISO_TO_USE="/var/tmp/$(basename "$IMAGE_URL")"
      run_cmd sudo mkdir -p /var/tmp
      run_cmd sudo curl -L --fail --connect-timeout 30 --max-time 3600 -o "$ISO_TO_USE" "$IMAGE_URL"
    else
      echo "When using --image custom you must provide --custom-iso or --image-url" >&2
      exit 1
    fi
    if [ ! -f "$ISO_TO_USE" ]; then
      echo "Custom ISO not found: $ISO_TO_USE" >&2
      exit 1
    fi
    download_and_extract "$ISO_TO_USE"
  fi
fi

echo "Write pxelinux menu for single image (can be re-run to change served image)"
run_cmd sudo tee "$TFTP_ROOT/pxelinux.cfg/default" > /dev/null <<EOF
DEFAULT ubuntu
PROMPT 0
TIMEOUT 50

LABEL ubuntu
  MENU LABEL Install $SERVE_NAME
  KERNEL $SERVE_NAME/vmlinuz
  INITRD $SERVE_NAME/initrd
  APPEND root=/dev/nfs nfsroot=$STATIC_IP:$TARGET_DIR ip=dhcp rw
EOF

echo "Exporting NFS"
run_cmd sudo mkdir -p "$(dirname "$EXPORTS_FILE")"
run_cmd sudo tee "$EXPORTS_FILE" > /dev/null <<EOF
$TARGET_DIR *(ro,sync,no_subtree_check)
EOF
run_cmd sudo exportfs -ra

echo "Enable and start services"
# Wait for the static IP to be available before starting dnsmasq
_wait_for_ip "$STATIC_IP" "$NETWORK_INTERFACE"
run_cmd sudo systemctl enable --now dnsmasq
run_cmd sudo systemctl enable --now tftpd-hpa
run_cmd sudo systemctl enable --now nfs-kernel-server

echo "PXE setup complete. Serving: $TARGET_DIR"
echo "TFTP root: $TFTP_ROOT"
echo "PXE server IP: $STATIC_IP"

exit 0
