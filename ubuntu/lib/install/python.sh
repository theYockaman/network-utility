#!/bin/bash
set -e

# Update and upgrade system packages
sudo apt update
sudo apt upgrade -y

# Install Python 3, pip, and venv
sudo apt install -y python3 python3-pip python3.12-venv

# Create a virtual environment in the user's home directory if it doesn't exist
VENV_DIR="$HOME/venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "Virtual environment created at $VENV_DIR"
else
    echo "Virtual environment already exists at $VENV_DIR"
fi

# Set ownership to the current user
sudo chown -R "$USER:$USER" "$VENV_DIR"

echo "To activate the virtual environment, run:"
echo "source ~/venv/bin/activate"