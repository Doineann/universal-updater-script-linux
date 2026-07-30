#!/usr/bin/env bash
set -e

# Resolve the directory where THIS script lives (the updater/ folder)
UPDATER_DIR="$(cd "$(dirname "$0")" && pwd)"

# The downstream project root is the parent directory of updater/
PROJECT_ROOT="$(cd "$UPDATER_DIR/.." && pwd)"

# Upstream repo URL (the repo containing this updater)
UPSTREAM_URL="https://github.com/doineann/universal-updater-script-linux.git"

# Branch to pull from
UPSTREAM_BRANCH="main"

echo "Updater directory: $UPDATER_DIR"
echo "Project root:      $PROJECT_ROOT"
echo "Updating subtree at '$UPDATER_DIR' from $UPSTREAM_URL ($UPSTREAM_BRANCH)"

# Run subtree update from the downstream project root
cd "$PROJECT_ROOT"

git subtree pull --prefix "$UPDATER_DIR" "$UPSTREAM_URL" "$UPSTREAM_BRANCH" --squash

echo "Subtree updated."
