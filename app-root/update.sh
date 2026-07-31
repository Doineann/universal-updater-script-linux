#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load the local config
source "$SCRIPT_DIR/config-updater.ini"

# Run the universal updater
bash "$SCRIPT_DIR/updater/updater.sh"
