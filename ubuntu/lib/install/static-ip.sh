#!/usr/bin/env bash
set -euo pipefail

# set-static-ip.sh
# Idempotent helper to create a Netplan file to set a static IPv4 address on an interface.
# Usage examples:
#  sudo bash set-static-ip.sh --interface eth0 --address 192.168.4.139/24 --gateway 192.168.4.1 --nameservers 8.8.8.8,1.1.1.1 --apply
#  bash set-static-ip.sh --interface eth0 --address 192.168.4.139/24 --dry-run

INTERFACE="eth0"
ADDRESS="192.168.4.139/24"
GATEWAY="192.168.4.1"
NAMESERVERS="8.8.8.8"
NETPLAN_FILE="/etc/netplan/01-pxe-static.yaml"
DRY_RUN=0
APPLY=0
ASSUME_YES=0

print_help(){
    cat <<EOF
Usage: $0 [options]

Options:
  --interface IFACE       Network interface (default: $INTERFACE)
  --address ADDR/CIDR     IPv4 address with CIDR (default: $ADDRESS)
  --gateway GATEWAY       IPv4 gateway (default: $GATEWAY)
  --nameservers CSV       Comma-separated DNS servers (default: $NAMESERVERS)
  --file PATH             Netplan file to write (default: $NETPLAN_FILE)
  --apply                 Run 'netplan apply' after writing (requires sudo)
  --dry-run               Print the netplan YAML that would be written
  -y, --yes               Don't prompt before writing
  -h, --help              Show this help
EOF
}

while [[ ${#} -gt 0 ]]; do
    case "$1" in
        --interface) INTERFACE="$2"; shift 2;;
        --address) ADDRESS="$2"; shift 2;;
        --gateway) GATEWAY="$2"; shift 2;;
        --nameservers) NAMESERVERS="$2"; shift 2;;
        --file) NETPLAN_FILE="$2"; shift 2;;
        --apply) APPLY=1; shift;;
        --dry-run) DRY_RUN=1; shift;;
        -y|--yes) ASSUME_YES=1; shift;;
        -h|--help) print_help; exit 0;;
        --) shift; break;;
        *) echo "Unknown option: $1"; print_help; exit 2;;
    esac
done

render_yaml(){
    cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${INTERFACE}:
      addresses: [${ADDRESS}]
      gateway4: ${GATEWAY}
      nameservers:
        addresses: [$(echo "${NAMESERVERS}" | sed "s/,/, /g")]
EOF
}

if [ "$DRY_RUN" -eq 1 ]; then
    echo "=== DRY RUN: netplan YAML ==="
    render_yaml
    exit 0
fi

YAML_CONTENT=$(render_yaml)

echo "Netplan file target: $NETPLAN_FILE"
echo "Interface: $INTERFACE"
echo "Address: $ADDRESS"
echo "Gateway: $GATEWAY"
echo "Nameservers: $NAMESERVERS"

if [ "$ASSUME_YES" -ne 1 ]; then
    read -r -p "Write netplan file and (optionally) apply it? [y/N]: " resp || true
    case "$resp" in
        [yY][eE][sS]|[yY]) ;;
        *) echo "Aborted by user."; exit 1;;
    esac
fi

echo "Backing up existing netplan files to /etc/netplan/backup-$(date +%s)"
sudo mkdir -p /etc/netplan
sudo mkdir -p /etc/netplan/backup-$(date +%s)
sudo cp -a /etc/netplan/*.yaml /etc/netplan/backup-$(date +%s) 2>/dev/null || true

echo "Writing netplan YAML to $NETPLAN_FILE"
echo "$YAML_CONTENT" | sudo tee "$NETPLAN_FILE" > /dev/null

if [ "$APPLY" -eq 1 ]; then
    echo "Applying netplan configuration (requires sudo)"
    sudo netplan apply
    echo "netplan apply completed"
else
    echo "Wrote $NETPLAN_FILE. Run 'sudo netplan apply' to activate the configuration, or re-run with --apply."
fi

echo "Done"

exit 0
