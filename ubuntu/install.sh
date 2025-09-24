#!/bin/bash

START_DIR="$(pwd)"
APP_NAME="bash-app-template"
INSTALL_DIR="/opt/github/$APP_NAME"
BIN_DIR="/usr/local/bin"   # or use ~/bin for user-only
LIB_DIR="/usr/local/lib/$APP_NAME"

echo "📂 Creating install dir..."
sudo mkdir -p /opt/github

# Check for git, install if missing
if ! command -v git >/dev/null 2>&1; then

    echo "🔄 Updating system..."
    sudo apt update -y

    echo "📦 Installing Git & curl..."
    sudo apt install -y git curl

    echo "✅ Git version:"
    git --version
fi


# Clean old install
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️ Removing old install..."
    sudo rm -rf "$INSTALL_DIR"
fi

echo "📥 Downloading repository..."
sudo git clone "https://github.com/theYockaman/$APP_NAME.git" "$INSTALL_DIR"


# Simple installer for git-utility on Ubuntu
echo "Installing $APP_NAME..."

# 1. Copy bin files
echo "Copying binaries to $BIN_DIR..."
sudo cp $INSTALL_DIR/ubuntu/bin/$APP_NAME "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/$APP_NAME"

# 2. Copy lib files
echo "Copying libraries to $LIB_DIR..."
sudo mkdir -p "$LIB_DIR"
sudo cp -r $INSTALL_DIR/ubuntu/lib/* "$LIB_DIR/"

echo "Removing original repository folder: $APP_NAME"
sudo rm -rf $INSTALL_DIR

echo "$APP_NAME installed successfully!"
echo "You can run it by typing '$APP_NAME' in the terminal."
