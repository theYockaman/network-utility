#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

$APP_NAME="git-utility"


exit_program() {
    echo "Exiting program."
    exit 0
}

delete_app() {
    source /usr/local/lib/$APP_NAME/delete_app.sh
}


log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}