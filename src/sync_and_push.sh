#!/bin/bash

# Resolve the absolute path of the script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# ================= Configuration =================

# 1. Defaults (used when config.sh is missing)
SOURCE_DIR="/Users/your_username/Library/Mobile Documents/iCloud~md~obsidian/Documents/your_vault"
DEST_DIR="/path/to/your/local/backup/folder"
LOG_DIR="$SCRIPT_DIR/logs"
SSH_KEY_PATH="/path/to/your/private/ssh_key"
LOG_RETENTION_DAYS=7

# 2. Load config file (when available)
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=config.sh
    source "$CONFIG_FILE"
fi

# 3. Global Git SSH configuration so every git command uses the provided key
export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes"

# 4. Dynamic log configuration
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi
# Generate one log file per day
LOG_FILE="$LOG_DIR/backup-$(date '+%Y-%m-%d').log"

# ===========================================

# Force consistent locale
export LC_ALL=en_US.UTF-8

# --- Utility: append log ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# --- Utility: send macOS notification on failures ---
notify_error() {
    local message="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e "display notification \"$message\" with title \"Obsidian Backup Failed\" subtitle \"Check the log for details\" sound name \"Basso\""
    fi
}

# --- Stage 0: log rotation ---
# Remove logs older than LOG_RETENTION_DAYS
if [ -d "$LOG_DIR" ]; then
    find "$LOG_DIR" -name "backup-*.log" -type f -mtime +"$LOG_RETENTION_DAYS" -delete
fi

log "=== Starting automated backup ==="

# --- Stage 1: environment prep ---
# Enter the git repo first so relative paths for git/rsync are safe
cd "$DEST_DIR" || {
    log "❌ Fatal error: unable to enter directory $DEST_DIR"
    notify_error "Unable to locate backup directory"
    exit 1
}

# Detect the current git branch
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="main" # Fallback if detection fails
    log "⚠️ Could not detect current branch; defaulting to $CURRENT_BRANCH"
fi

# Avoid quoted Chinese paths in git output
git config core.quotepath false

# --- Stage 2: pull remote updates ---
# Using merge instead of rebase keeps things predictable
log "🔄 Checking remote updates (git pull)..."
git pull origin "$CURRENT_BRANCH" >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    log "⚠️ Warning: git pull failed. Could be networking or conflicts. Proceeding with rsync anyway..."
    # Continue because the local rsync needs to run even when pull fails
else
    log "✅ Git pull completed."
fi

# --- Stage 3: rsync from iCloud mirror ---
# We are already in DEST_DIR
# Compare canonical paths to see whether source/dest are identical
REAL_SOURCE=$(cd "$SOURCE_DIR" 2>/dev/null && pwd)
REAL_DEST=$(cd "$DEST_DIR" 2>/dev/null && pwd)

if [[ "$REAL_SOURCE" == "$REAL_DEST" ]]; then
    log "📂 Source and destination directories match; skipping rsync and going straight to git commit..."
else
    log "📂 Starting rsync sync..."
    rsync -av --delete --exclude '.git' --exclude '.DS_Store' "$SOURCE_DIR/" "$DEST_DIR/" >> "$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then
        log "❌ Error: rsync sync failed (exit code $?)."
        notify_error "Rsync file sync failed"
        exit 1
    fi
fi

# --- Stage 4: commit and push ---
if [[ -n $(git status -s) ]]; then
    log "📝 Changes detected; preparing to commit..."
    
    git add .
    git commit -m "Auto-save: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
    
    log "🚀 Pushing to GitHub..."
    git push origin "$CURRENT_BRANCH" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✅ Success: pushed to GitHub."
    else
        log "❌ Error: git push failed. Check the log for details."
        notify_error "Git push failed; check for network issues or conflicts"
    fi
else
    log "☕ No changes detected; skipping push."
fi

echo "-------------------------------------" >> "$LOG_FILE"
