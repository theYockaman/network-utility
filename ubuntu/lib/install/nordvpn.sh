#!/bin/bash
set -e

# Update and install prerequisites
sudo apt update
sudo apt upgrade -y
sudo apt install -y wget curl gnupg lsb-release

# Add NordVPN GPG key and repository if not already present
if [ ! -f /etc/apt/trusted.gpg.d/nordvpn.asc ]; then
    wget -qO - https://repo.nordvpn.com/gpg/nordvpn_public.asc | sudo tee /etc/apt/trusted.gpg.d/nordvpn.asc > /dev/null
fi

if [ ! -f /etc/apt/sources.list.d/nordvpn.list ]; then
    echo "deb https://repo.nordvpn.com/deb/nordvpn/debian stable main" | sudo tee /etc/apt/sources.list.d/nordvpn.list > /dev/null
fi

sudo apt update

# Install NordVPN
sudo apt install -y nordvpn

# Get NordVPN token from parameter or prompt
if [ -n "$1" ]; then
    NORDVPN_TOKEN="$1"
else
    read -s -p "Enter your NordVPN token: " NORDVPN_TOKEN
    echo
     if [ -z "$NORDVPN_TOKEN" ]; then
        echo "No NordVPN token provided. Exiting."
        exit 1
    fi
fi

# Login to NordVPN (replace with your own token)
if ! sudo nordvpn account | grep -q "Logged in"; then
    echo "Logging in to NordVPN..."
    sudo nordvpn login --token "$NORDVPN_TOKEN"
fi


# Enable autoconnect and meshnet
sudo nordvpn set autoconnect on
sudo nordvpn set meshnet on

# Show NordVPN status
sudo nordvpn status

echo "NordVPN installation and setup complete."