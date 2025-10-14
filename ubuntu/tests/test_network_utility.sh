#!/usr/bin/env bash
# Tests for network-utility

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NETWORK_UTILITY="$REPO_ROOT/ubuntu/bin/network-utility"

echo "Running network-utility tests..."

# Test 1: Help command
echo "Test 1: Help command"
OUTPUT=$("$NETWORK_UTILITY" help)
if [[ "$OUTPUT" == *"Network Utility - Manage network configurations and services"* ]]; then
    echo "✓ Test 1 passed: Help command works"
else
    echo "✗ Test 1 failed: Help command output incorrect"
    exit 1
fi

# Test 2: Install static-ip --help
echo "Test 2: Install static-ip --help"
OUTPUT=$("$NETWORK_UTILITY" install static-ip --help)
if [[ "$OUTPUT" == *"--interface"* ]] && [[ "$OUTPUT" == *"--address"* ]]; then
    echo "✓ Test 2 passed: static-ip help works"
else
    echo "✗ Test 2 failed: static-ip help output incorrect"
    exit 1
fi

# Test 3: Install pxe --help
echo "Test 3: Install pxe --help"
OUTPUT=$("$NETWORK_UTILITY" install pxe --help)
if [[ "$OUTPUT" == *"--interface"* ]] && [[ "$OUTPUT" == *"--static-ip"* ]]; then
    echo "✓ Test 3 passed: pxe help works"
else
    echo "✗ Test 3 failed: pxe help output incorrect"
    exit 1
fi

# Test 4: Install tailscale --help
echo "Test 4: Install tailscale --help"
OUTPUT=$("$NETWORK_UTILITY" install tailscale --help)
if [[ "$OUTPUT" == *"--authkey"* ]] && [[ "$OUTPUT" == *"--hostname"* ]]; then
    echo "✓ Test 4 passed: tailscale help works"
else
    echo "✗ Test 4 failed: tailscale help output incorrect"
    exit 1
fi

# Test 5: Install static-ip --dry-run
echo "Test 5: Install static-ip --dry-run"
OUTPUT=$("$NETWORK_UTILITY" install static-ip --interface eth0 --address 192.168.1.100/24 --gateway 192.168.1.1 --dry-run)
if [[ "$OUTPUT" == *"DRY RUN"* ]] && [[ "$OUTPUT" == *"eth0"* ]] && [[ "$OUTPUT" == *"192.168.1.100/24"* ]]; then
    echo "✓ Test 5 passed: static-ip dry-run works"
else
    echo "✗ Test 5 failed: static-ip dry-run output incorrect"
    exit 1
fi

# Test 6: Install tailscale --dry-run
echo "Test 6: Install tailscale --dry-run"
OUTPUT=$("$NETWORK_UTILITY" install tailscale --dry-run 2>&1)
if [[ "$OUTPUT" == *"Starting Tailscale setup"* ]]; then
    echo "✓ Test 6 passed: tailscale dry-run works"
else
    echo "✗ Test 6 failed: tailscale dry-run output incorrect"
    exit 1
fi

# Test 7: Unknown command
echo "Test 7: Unknown command"
set +e
OUTPUT=$("$NETWORK_UTILITY" invalid-command 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && [[ "$OUTPUT" == *"Unknown command"* ]]; then
    echo "✓ Test 7 passed: Unknown command handled correctly"
else
    echo "✗ Test 7 failed: Unknown command not handled correctly"
    exit 1
fi

# Test 8: Unknown install subcommand
echo "Test 8: Unknown install subcommand"
set +e
OUTPUT=$("$NETWORK_UTILITY" install invalid-subcommand 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && [[ "$OUTPUT" == *"Unknown install subcommand"* ]]; then
    echo "✓ Test 8 passed: Unknown install subcommand handled correctly"
else
    echo "✗ Test 8 failed: Unknown install subcommand not handled correctly"
    exit 1
fi

echo ""
echo "All tests passed! ✓"
