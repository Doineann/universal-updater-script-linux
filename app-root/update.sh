#!/usr/bin/env bash
set -e

# Load the local config
source ./config-updater.ini

# Run the universal updater
bash updater/updater.sh