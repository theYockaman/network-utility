#!/usr/bin/env bash
set -euo pipefail

# setup-tailscale.sh
# Installs Tailscale on Ubuntu and optionally runs `tailscale up` with an auth key or interactive login.
# Usage:
#  sudo bash setup-tailscale.sh --authkey tskey-... --hostname myserver --up
#  bash setup-tailscale.sh --dry-run

AUTHKEY=""
HOSTNAME=""
DRY_RUN=0
DO_UP=0

print_help(){
    cat <<EOF
Usage: $0 [options]

Options:
  --authkey KEY       Tailscale auth key (tskey-...)
  --hostname NAME     Set device hostname for Tailscale
  --up                Run 'tailscale up' after install (requires sudo)
  --dry-run           Print actions but don't modify system
  -h, --help          Show this help
EOF
}

while [[ ${#} -gt 0 ]]; do
    case "$1" in
        --authkey) AUTHKEY="$2"; shift 2;;
        --hostname) HOSTNAME="$2"; shift 2;;
        --up) DO_UP=1; shift;;
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

echo "Starting Tailscale setup"

# Check if tailscale is already installed
if command -v tailscale >/dev/null 2>&1 && command -v tailscaled >/dev/null 2>&1; then
    echo "Tailscale already installed."
else
    echo "Installing Tailscale (APT repository)"
    run_cmd sudo apt-get update
    # Add apt repo and install
    run_cmd sudo apt-get install -y curl gnupg apt-transport-https
    run_cmd curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    run_cmd sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu focal main" > /etc/apt/sources.list.d/tailscale.list'
    run_cmd sudo apt-get update
    run_cmd sudo apt-get install -y tailscale
fi

if [ "$DO_UP" -eq 1 ]; then
    # Build up command
    UP_CMD="sudo tailscale up"
    [ -n "$AUTHKEY" ] && UP_CMD="$UP_CMD --authkey $AUTHKEY"
    [ -n "$HOSTNAME" ] && UP_CMD="$UP_CMD --hostname $HOSTNAME"

    echo "Running: $UP_CMD"
    run_cmd $UP_CMD
    echo "tailscale up executed"
else
    echo "Install complete. Run 'sudo tailscale up' to authenticate this device to your Tailnet."
    if [ -n "$AUTHKEY" ] || [ -n "$HOSTNAME" ]; then
        echo "You can re-run this script with --up to automatically run 'tailscale up' with the provided flags."
    fi
fi

echo "Done"
exit 0
