#!/usr/bin/env bash
set -e

#
# Universal Updater — Self Update (Atomic + Dynamic Directory)
# ------------------------------------------------------------
# Supports:
#   1. Raw standalone files        (no updater/.git)
#   2. Full git clone              (updater/.git exists → git pull)
#   3. Git subtree                 (normal or squash)
#

# ------------------------------------------------------------
# Resolve paths
# ------------------------------------------------------------
UPDATER_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$UPDATER_DIR/.." && pwd)"
UPDATER_NAME="$(basename "$UPDATER_DIR")"

echo "Updater directory: $UPDATER_DIR"
echo "Updater name:      $UPDATER_NAME"
echo "Project root:      $PROJECT_ROOT"

# ------------------------------------------------------------
# Upstream repo info
# ------------------------------------------------------------
UPSTREAM_URL="https://github.com/doineann/universal-updater-script-linux.git"
UPSTREAM_BRANCH="main"

# ------------------------------------------------------------
# Detection helpers
# ------------------------------------------------------------

# Mode 2: full git clone
is_full_clone() {
    [[ -d "$UPDATER_DIR/.git" ]]
}

# Mode 3: subtree (normal / squash)
detect_subtree_mode() {
    cd "$PROJECT_ROOT"

    # Project must be a git repo
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "none"
        return
    fi

    # Look for subtree commits
    if git log --grep="git-subtree-dir: $UPDATER_NAME" -n 1 >/dev/null 2>&1; then
        if git log --grep="git-subtree-split:" -n 1 >/dev/null 2>&1; then
            echo "squash"
        else
            echo "normal"
        fi
        return
    fi

    echo "none"
}

# ------------------------------------------------------------
# Determine installation mode
# ------------------------------------------------------------
echo ""
echo "Detecting updater installation mode..."

if is_full_clone; then
    MODE="clone"
    echo "→ Updater is a full git clone."
else
    SUBTREE_MODE="$(detect_subtree_mode)"
    if [[ "$SUBTREE_MODE" == "normal" ]]; then
        MODE="subtree"
        echo "→ Updater is a Git subtree (normal)."
    elif [[ "$SUBTREE_MODE" == "squash" ]]; then
        MODE="subtree"
        echo "→ Updater is a Git subtree (squash)."
    else
        MODE="standalone"
        echo "→ Updater is standalone."
    fi
fi

echo ""

# ------------------------------------------------------------
# Update logic
# ------------------------------------------------------------
case "$MODE" in

    clone)
        echo "Updating full git clone..."
        cd "$UPDATER_DIR"
        git pull "$UPSTREAM_URL" "$UPSTREAM_BRANCH"
        echo "Updater clone updated."
        ;;

    subtree)
        echo "Updating updater subtree..."
        cd "$PROJECT_ROOT"

        if [[ "$SUBTREE_MODE" == "squash" ]]; then
            echo "Using: git subtree pull (squash)"
            git subtree pull --prefix "$UPDATER_NAME" "$UPSTREAM_URL" "$UPSTREAM_BRANCH" --squash
        else
            echo "Using: git subtree pull (normal)"
            git subtree pull --prefix "$UPDATER_NAME" "$UPSTREAM_URL" "$UPSTREAM_BRANCH"
        fi

        echo "Updater subtree updated."
        ;;

    standalone)
        echo "Updating standalone updater..."

        NEW_DIR="$PROJECT_ROOT/${UPDATER_NAME}.new"
        OLD_DIR="$PROJECT_ROOT/${UPDATER_NAME}.old"

        echo "Downloading new updater to: $NEW_DIR"
        rm -rf "$NEW_DIR"
        git clone --depth 1 "$UPSTREAM_URL" "$NEW_DIR"
        rm -rf "$NEW_DIR/.git"

        echo "Doing atomic swap..."
        rm -rf "$OLD_DIR"
        mv "$UPDATER_DIR" "$OLD_DIR"
        mv "$NEW_DIR" "$UPDATER_DIR"

        echo "Removing old updater..."
        rm -rf "$OLD_DIR"

        echo "Standalone updater updated."
        ;;

esac

echo ""
echo "Update-self complete."
