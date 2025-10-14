#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# APP_NAME should be set by the calling script
APP_NAME="${APP_NAME:-network-utility}"


exit_program() {
    echo "Exiting program."
    exit 0
}

delete_app() {
    local delete_script="/usr/local/lib/$APP_NAME/delete_app.sh"
    if [ -f "$delete_script" ]; then
        source "$delete_script"
    else
        # Fallback deletion logic
        echo "Removing $APP_NAME..."
        
        # Remove binary
        if [ -f "/usr/local/bin/$APP_NAME" ]; then
            sudo rm -f "/usr/local/bin/$APP_NAME"
            echo "Removed /usr/local/bin/$APP_NAME"
        fi
        
        # Remove lib directory
        if [ -d "/usr/local/lib/$APP_NAME" ]; then
            sudo rm -rf "/usr/local/lib/$APP_NAME"
            echo "Removed /usr/local/lib/$APP_NAME"
        fi
        
        echo "$APP_NAME has been removed from your system."
    fi
}


log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}