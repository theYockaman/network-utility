#!/bin/bash

# Installs and enables SSH on Ubuntu

set -e

echo "Updating package list..."
sudo apt update

echo "Installing OpenSSH Server..."
sudo apt install -y openssh-server

echo "Enabling and starting SSH service..."
sudo systemctl enable ssh
sudo systemctl start ssh

echo "Checking SSH service status..."
sudo systemctl status ssh --no-pager

echo "Enabling firewall rule for SSH..."
sudo ufw allow ssh

echo "SSH installation and setup complete!"

SERVER_IP=$(hostname -I | awk '{print $1}')
CURRENT_USER=$(whoami)

echo "You can now connect to this machine using: ssh $CURRENT_USER@$SERVER_IP"