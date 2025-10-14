# network-utility

A comprehensive network configuration and management utility for Ubuntu/Debian systems. Provides both interactive menu and CLI interfaces for common network tasks.

## Features

- **Static IP Configuration**: Configure static IP addresses via netplan
- **PXE Boot Server**: Set up and manage PXE/NFS/TFTP boot servers
- **Tailscale VPN**: Install and configure Tailscale mesh VPN
- **NordVPN**: Install and configure NordVPN
- **Dual Interface**: Interactive whiptail menu or command-line interface
- **Idempotent Installers**: Safe to run multiple times

## Installation

### Ubuntu/Debian

```bash
sudo curl -s https://raw.githubusercontent.com/theYockaman/network-utility/main/ubuntu/install.sh | sudo bash
```

### Manual Installation

```bash
git clone https://github.com/theYockaman/network-utility.git
cd network-utility
sudo bash ubuntu/install.sh
```

## Usage

### Interactive Menu

Launch the interactive menu by running without arguments:

```bash
network-utility
```

This will present a whiptail menu with options for:
- Install Static IP
- Install PXE
- Install Tailscale
- Install NordVPN
- Delete (uninstall network-utility)
- Exit

### Command-Line Interface

#### Get Help

```bash
network-utility help
```

#### Static IP Configuration

Configure a static IP address:

```bash
# Dry run (preview configuration)
network-utility install static-ip --interface eth0 --address 192.168.4.139/24 --gateway 192.168.4.1 --dry-run

# Apply configuration
sudo network-utility install static-ip --interface eth0 --address 192.168.4.139/24 --gateway 192.168.4.1 --nameservers 8.8.8.8,1.1.1.1 --apply -y
```

Options:
- `--interface IFACE`: Network interface (default: eth0)
- `--address ADDR/CIDR`: IPv4 address with CIDR notation
- `--gateway GATEWAY`: IPv4 gateway
- `--nameservers CSV`: Comma-separated DNS servers
- `--apply`: Apply configuration immediately
- `--dry-run`: Preview configuration without applying
- `-y, --yes`: Skip confirmation prompts

#### PXE Boot Server

Set up a PXE boot server:

```bash
# Default setup (Ubuntu LTS headless)
sudo network-utility install pxe --interface eth0 --static-ip 192.168.4.139

# Custom ISO from local file
sudo network-utility install pxe --image custom --custom-iso /path/to/image.iso --force

# Download and serve an ISO from URL
sudo network-utility install pxe --image custom --image-url https://example.com/image.iso --force

# Dry run
network-utility install pxe --dry-run
```

Options:
- `--interface IFACE`: Network interface (default: eth0)
- `--static-ip IP`: PXE/NFS host IP (default: 192.168.4.139)
- `--image NAME`: Image type ('ubuntu-lts-headless' or 'custom')
- `--custom-iso PATH`: Path to custom ISO file
- `--image-url URL`: Download ISO from URL
- `--force`: Overwrite existing image
- `--dry-run`: Preview actions without executing

#### Tailscale VPN

Install and configure Tailscale:

```bash
# Install only
sudo network-utility install tailscale

# Install and connect with auth key
sudo network-utility install tailscale --authkey tskey-... --hostname myserver --up

# Dry run
network-utility install tailscale --dry-run
```

Options:
- `--authkey KEY`: Tailscale auth key (tskey-...)
- `--hostname NAME`: Set device hostname
- `--up`: Run 'tailscale up' after installation
- `--dry-run`: Preview actions without executing

#### NordVPN

Install and configure NordVPN:

```bash
# Interactive (will prompt for token)
sudo network-utility install nordvpn

# With token as argument
sudo network-utility install nordvpn YOUR_NORDVPN_TOKEN
```

#### Uninstall

Remove network-utility from your system:

```bash
network-utility delete
```

## Testing

Run the test suite:

```bash
bash ubuntu/tests/test_network_utility.sh
```

## Architecture

```
ubuntu/
├── bin/
│   └── network-utility          # Main entrypoint with dual-mode CLI
├── lib/
│   ├── utils.sh                 # Shared utility functions
│   └── install/
│       ├── static-ip.sh         # Static IP installer
│       ├── pxe.sh              # PXE server installer
│       ├── tailscale.sh        # Tailscale installer
│       └── nordvpn.sh          # NordVPN installer
├── install.sh                   # System installer
└── tests/
    └── test_network_utility.sh  # Test suite
```

## Requirements

- Ubuntu/Debian Linux
- Bash 4.0+
- sudo privileges for installation and configuration
- whiptail (auto-installed for interactive menu)

## License

MIT License - See LICENSE file for details 