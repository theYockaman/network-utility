#!/usr/bin/env bash
# Simple tests for mycli

set -euo pipefail

OUTPUT=$(bash bin/mycli greet Alice)
EXPECTED="Hello, Alice!"

if [[ "$OUTPUT" == "$EXPECTED" ]]; then
    echo "Test passed"
else
    echo "Test failed: expected '$EXPECTED', got '$OUTPUT'"
    exit 1
fi
