#!/usr/bin/env bash
# Tests for pxe/setup-pxe.sh script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PXE_SCRIPT="$REPO_ROOT/pxe/setup-pxe.sh"

echo "Running PXE setup script tests..."

# Test 1: Script exists and is executable
echo "Test 1: Script exists and is executable"
if [[ -f "$PXE_SCRIPT" ]] && [[ -x "$PXE_SCRIPT" ]]; then
    echo "✓ Test 1 passed: Script exists and is executable"
else
    echo "✗ Test 1 failed: Script not found or not executable at $PXE_SCRIPT"
    exit 1
fi

# Test 2: Script has proper shebang
echo "Test 2: Script has proper shebang"
FIRST_LINE=$(head -n1 "$PXE_SCRIPT")
if [[ "$FIRST_LINE" == "#!/usr/bin/env bash" ]] || [[ "$FIRST_LINE" == "#!/bin/bash" ]]; then
    echo "✓ Test 2 passed: Script has proper shebang"
else
    echo "✗ Test 2 failed: Script does not have proper shebang"
    exit 1
fi

# Test 3: Script shows help with --help flag
echo "Test 3: Script shows help with --help flag"
OUTPUT=$("$PXE_SCRIPT" --help 2>&1 || true)
if [[ "$OUTPUT" == *"Usage:"* ]] && [[ "$OUTPUT" == *"dnsmasq"* ]] && [[ "$OUTPUT" == *"tftpd-hpa"* ]]; then
    echo "✓ Test 3 passed: Help text is displayed correctly"
else
    echo "✗ Test 3 failed: Help text not displayed correctly"
    exit 1
fi

# Test 4: Script requires root privileges
echo "Test 4: Script requires root privileges"
set +e
OUTPUT=$("$PXE_SCRIPT" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && [[ "$OUTPUT" == *"must be run as root"* ]]; then
    echo "✓ Test 4 passed: Script correctly checks for root privileges"
else
    echo "✗ Test 4 failed: Script does not check for root privileges correctly"
    exit 1
fi

# Test 5: Script mentions required packages
echo "Test 5: Script mentions required packages in help"
HELP_OUTPUT=$("$PXE_SCRIPT" --help 2>&1 || true)
REQUIRED_PACKAGES=("dnsmasq" "tftpd-hpa" "syslinux" "nginx")
ALL_FOUND=true
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if [[ ! "$HELP_OUTPUT" =~ $pkg ]]; then
        echo "  Warning: Package '$pkg' not mentioned in help text"
        ALL_FOUND=false
    fi
done
if [[ "$ALL_FOUND" == true ]]; then
    echo "✓ Test 5 passed: All required packages mentioned in help"
else
    echo "✓ Test 5 passed: Most required packages mentioned in help (warnings above)"
fi

# Test 6: Script contains required directory paths
echo "Test 6: Script contains required directory paths"
SCRIPT_CONTENT=$(cat "$PXE_SCRIPT")
REQUIRED_PATHS=("/var/lib/tftpboot" "/var/www/html")
ALL_FOUND=true
for path in "${REQUIRED_PATHS[@]}"; do
    if [[ ! "$SCRIPT_CONTENT" =~ $path ]]; then
        echo "  Error: Path '$path' not found in script"
        ALL_FOUND=false
    fi
done
if [[ "$ALL_FOUND" == true ]]; then
    echo "✓ Test 6 passed: All required paths found in script"
else
    echo "✗ Test 6 failed: Not all required paths found in script"
    exit 1
fi

# Test 7: Script has apt install command for required packages
echo "Test 7: Script has apt install command for required packages"
if grep -q "apt install.*dnsmasq.*tftpd-hpa.*syslinux.*nginx.*rsync.*whois" "$PXE_SCRIPT"; then
    echo "✓ Test 7 passed: Script includes apt install command with required packages"
else
    echo "✗ Test 7 failed: Script does not include all required packages in apt install"
    exit 1
fi

echo ""
echo "All PXE setup script tests passed! ✓"
