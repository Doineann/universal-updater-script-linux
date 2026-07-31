#!/usr/bin/env bash
set -e

#
# Universal Updater
# ------------------
# A portable update mechanism supporting GitHub releases, redirect‑based
# installers, direct download endpoints, and custom version providers.
# It detects the installed version, determines the latest available
# version, safely stops the running application when required, downloads
# and installs updates, flattens nested extraction structures, preserves
# backups when configured, and restarts the application if it was
# previously active.
#

# Logging helper
log() { echo "- $1"; }

# ------------------------------------------------------------
# Resolve updater directory + load configuration
# ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config-updater.ini"
source "$CONFIG_FILE"

echo -e "\033[1;37mUniversal Updater: $UPDATER_APP_NAME\033[0m"

# ------------------------------------------------------------
# Normalize destination directory
# ------------------------------------------------------------
DEST_DIR="$UPDATER_DEST_DIR"
if [[ "$DEST_DIR" != /* ]]; then
    DEST_DIR="$ROOT_DIR/$DEST_DIR"
fi

VERSION_FILE="$DEST_DIR/version.txt"
CURRENT_VERSION=""

# ------------------------------------------------------------
# Determine installed version
# ------------------------------------------------------------
if [[ -f "$VERSION_FILE" ]]; then
    CURRENT_VERSION=$(<"$VERSION_FILE")
    CURRENT_VERSION=$(echo "$CURRENT_VERSION" | xargs)
    log "Installed version: $CURRENT_VERSION"
else
    log "No version.txt found — treating as fresh install."
fi

# ------------------------------------------------------------
# Determine latest version (GitHub → Direct → Custom)
# ------------------------------------------------------------
LATEST_VERSION=""
LATEST_FILENAME=""
LATEST_URL=""

#
# --- GitHub mode -------------------------------------------------------------
#
if [[ -n "$UPDATER_GITHUB_USER" && -n "$UPDATER_GITHUB_REPO" && -n "$UPDATER_GITHUB_ARTIFACT_PATTERN" ]]; then
    log "Using GitHub release mode..."

    FETCH="$SCRIPT_DIR/generic/github-fetch-latest-artifact.sh"

    LATEST_VERSION=$("$FETCH" "$UPDATER_GITHUB_USER" "$UPDATER_GITHUB_REPO" "$UPDATER_GITHUB_ARTIFACT_PATTERN" --show-tag)
    LATEST_FILENAME=$("$FETCH" "$UPDATER_GITHUB_USER" "$UPDATER_GITHUB_REPO" "$UPDATER_GITHUB_ARTIFACT_PATTERN" --show-filename)
    LATEST_URL=$("$FETCH" "$UPDATER_GITHUB_USER" "$UPDATER_GITHUB_REPO" "$UPDATER_GITHUB_ARTIFACT_PATTERN" --show-url)

#
# --- Direct download mode ----------------------------------------------------
#
elif [[ -n "$UPDATER_DOWNLOAD_LATEST_URL" ]]; then
    log "Using direct download mode..."

    ALL_HEADERS=$(curl -sI -L "$UPDATER_DOWNLOAD_LATEST_URL")

    REDIRECT_URL=$(echo "$ALL_HEADERS" \
        | grep -i '^location:' \
        | tail -n 1 \
        | sed -E 's/location:\s*//i' \
        | tr -d '\r\n' \
        | xargs)

    if [[ -n "$REDIRECT_URL" ]]; then
        LATEST_URL="$REDIRECT_URL"
        LATEST_FILENAME=$(basename "$REDIRECT_URL")
    else
        LATEST_URL="$UPDATER_DOWNLOAD_LATEST_URL"
        LATEST_FILENAME=$(basename "$UPDATER_DOWNLOAD_LATEST_URL")
    fi

    if [[ "$UPDATER_VERSION_SOURCE" == "filename" ]]; then
        LATEST_VERSION=$(echo "$LATEST_FILENAME" | sed -E "s/$UPDATER_VERSION_REGEX/\1/")
    else
        log "ERROR: Direct download mode requires UPDATER_VERSION_SOURCE=filename"
        exit 1
    fi

#
# --- Custom mode -------------------------------------------------------------
#
elif [[ -n "$UPDATER_CUSTOM_LATEST_COMMAND" ]]; then
    log "Using custom mode..."

    mapfile -t lines < <($UPDATER_CUSTOM_LATEST_COMMAND)
    LATEST_VERSION="${lines[0]}"
    LATEST_FILENAME="${lines[1]}"
    LATEST_URL="${lines[2]}"

else
    log "ERROR: No update source configured!"
    exit 1
fi

log "Latest available version: $LATEST_VERSION"

# ------------------------------------------------------------
# Compare versions
# ------------------------------------------------------------
NEED_UPDATE=0

if [[ -z "$CURRENT_VERSION" ]]; then
    NEED_UPDATE=1
elif [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
    NEED_UPDATE=1
fi

if [[ "$NEED_UPDATE" -eq 0 ]]; then
    log "Already up to date."
    exit 0
fi

log "Update required: $CURRENT_VERSION → $LATEST_VERSION"

# ------------------------------------------------------------
# Stop running application (if needed)
# ------------------------------------------------------------
WAS_RUNNING=0

if [[ -n "$UPDATER_APP_MAIN_EXECUTABLE" ]]; then
    if pgrep -x "$UPDATER_APP_MAIN_EXECUTABLE" > /dev/null; then
        WAS_RUNNING=1

        if [[ -z "$UPDATER_APP_STOP_COMMAND" ]]; then
            log "ERROR: Application '$UPDATER_APP_MAIN_EXECUTABLE' is running but no stop command is defined."
            exit 1
        fi

        log "Stopping application..."
        cd "$ROOT_DIR"
        eval "$UPDATER_APP_STOP_COMMAND"
        cd "$SCRIPT_DIR"

        log "Waiting for application to stop..."
        while pgrep -x "$UPDATER_APP_MAIN_EXECUTABLE" > /dev/null; do
            sleep 1
        done
    fi
fi

# ------------------------------------------------------------
# Pre-install hook
# ------------------------------------------------------------
if [[ -n "$UPDATER_PRE_INSTALL_COMMAND" ]]; then
    log "Running pre-install command..."
    cd "$ROOT_DIR"
    eval "$UPDATER_PRE_INSTALL_COMMAND"
    cd "$SCRIPT_DIR"
fi

# ------------------------------------------------------------
# Backup old version
# ------------------------------------------------------------
if [[ "$UPDATER_KEEP_BACKUP_VERSION" -eq 1 && -d "$DEST_DIR" ]]; then
    log "Creating backup..."
    rm -rf "${DEST_DIR}.backup"
    mv "$DEST_DIR" "${DEST_DIR}.backup"
fi

# ------------------------------------------------------------
# Download new version
# ------------------------------------------------------------
log "Downloading latest version..."
TMPFILE=$(mktemp)
curl -L "$LATEST_URL" -o "$TMPFILE"

# ------------------------------------------------------------
# Install new version
# ------------------------------------------------------------
log "Installing new version..."
mkdir -p "$DEST_DIR"

if [[ -z "$UPDATER_EXTRACT_COMMAND" ]]; then
    case "${LATEST_FILENAME,,}" in
        *.tar.gz|*.tgz)          UPDATER_EXTRACT_COMMAND="tar -xzf" ;;
        *.tar.xz|*.txz|*.tar)    UPDATER_EXTRACT_COMMAND="tar -xf" ;;
        *.zip)                   UPDATER_EXTRACT_COMMAND="unzip" ;;
        *.appimage)              UPDATER_EXTRACT_COMMAND="mv_and_chmod" ;;
        *)                       UPDATER_EXTRACT_COMMAND="mv" ;;
    esac
fi

case "$UPDATER_EXTRACT_COMMAND" in
    mv)
        TARGET="$DEST_DIR/$LATEST_FILENAME"
        mv "$TMPFILE" "$TARGET"
        ;;

    mv_and_chmod)
        TARGET="$DEST_DIR/$LATEST_FILENAME"
        mv "$TMPFILE" "$TARGET"
        chmod +x "$TARGET"
        ;;

    *)
        $UPDATER_EXTRACT_COMMAND "$TMPFILE" -C "$DEST_DIR"
        ;;
esac

# ------------------------------------------------------------
# Auto-flatten extracted directory structure
# ------------------------------------------------------------
while true; do
    entries=$(find "$DEST_DIR" -mindepth 1 -maxdepth 1)
    count=$(echo "$entries" | wc -l)

    if [[ "$count" -eq 1 ]]; then
        only=$(echo "$entries")
        if [[ -d "$only" ]]; then
            log "Flattening extracted directory: $(basename "$only")"
            tmp=$(mktemp -d)
            mv "$only"/* "$tmp"
            rm -rf "$only"
            mv "$tmp"/* "$DEST_DIR"
            rm -rf "$tmp"
            continue
        fi
    fi

    break
done

# ------------------------------------------------------------
# Write installed version
# ------------------------------------------------------------
echo "$LATEST_VERSION" > "$VERSION_FILE"
log "Installed version updated."

# ------------------------------------------------------------
# Post-install hook
# ------------------------------------------------------------
if [[ -n "$UPDATER_POST_INSTALL_COMMAND" ]]; then
    log "Running post-install command..."
    cd "$ROOT_DIR"
    eval "$UPDATER_POST_INSTALL_COMMAND"
    cd "$SCRIPT_DIR"
fi

# ------------------------------------------------------------
# Restart application (if it was running)
# ------------------------------------------------------------
if [[ $WAS_RUNNING -eq 1 && -n "$UPDATER_APP_RESTART_COMMAND" ]]; then
    log "Restarting application..."
    cd "$ROOT_DIR"
    eval "$UPDATER_APP_RESTART_COMMAND"
    cd "$SCRIPT_DIR"
fi

log "Update complete: $LATEST_VERSION"
exit 0
