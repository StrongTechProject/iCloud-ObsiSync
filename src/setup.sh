#!/bin/bash

# ==========================================
# Obsidian AutoSync Setup Wizard
# ==========================================

# Directory of this script (src directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
DEFAULT_LOG_RETENTION=7

echo "--------------------------------------------------"
echo "👋 Welcome to the Obsidian AutoSync setup wizard"
echo "This script will generate '$CONFIG_FILE'."
echo "--------------------------------------------------"

# 0. Dependency check
echo "🔍 Checking required commands..."
MISSING_DEPS=0
for cmd in git rsync; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: command '$cmd' not found. Please install it first."
        MISSING_DEPS=1
    else
        echo "✅ Found $cmd"
    fi
done

if [ $MISSING_DEPS -ne 0 ]; then
    echo "⚠️  Missing dependencies detected. Install git and rsync, then rerun this script."
    exit 1
fi

# 1. Ask for Obsidian source path
while true; do
    echo ""
    echo "👉 Please enter the Obsidian source directory:"
    echo "   (usually your Obsidian Vault path)"
    echo "   (tip: you can drag the folder into this terminal window)"
    read -e -p "Path: " SOURCE_DIR
    # Strip quotes (macOS drag & drop may add them)
    SOURCE_DIR="${SOURCE_DIR%\"}"
    SOURCE_DIR="${SOURCE_DIR#\"}"
    
    if [ -d "$SOURCE_DIR" ]; then
        echo "✅ Source path is valid."
        break
    else
        echo "❌ Error: directory does not exist. Try again."
    fi
done

# 2. Ask for local git repository path
while true; do
    echo ""
    echo "👉 Please enter the local git repository path (Destination):"
    echo "   (enter the same path as above if you want to track the source directly)"
    read -e -p "Path: " DEST_DIR
    DEST_DIR="${DEST_DIR%\"}"
    DEST_DIR="${DEST_DIR#\"}"

    if [ -d "$DEST_DIR" ]; then
        if [ -w "$DEST_DIR" ]; then
            IS_GIT_REPO=0
            if [ -d "$DEST_DIR/.git" ]; then
                echo "✅ Destination path contains a git repository."
                IS_GIT_REPO=1
            else
                echo "⚠️  Warning: destination exists but .git was not found."
                read -p "   Initialize this directory as a git repo? (y/n): " init_confirm
                if [[ "$init_confirm" == "y" || "$init_confirm" == "Y" ]]; then
                    echo "Initializing git repository in $DEST_DIR..."
                    git -C "$DEST_DIR" init
                    echo "✅ Git repository initialized."
                    IS_GIT_REPO=1
                else
                    read -p "   Continue without initializing? (y/n): " continue_confirm
                    if [[ "$continue_confirm" == "y" || "$continue_confirm" == "Y" ]]; then
                        break
                    fi
                fi
            fi

            if [ $IS_GIT_REPO -eq 1 ]; then
                # Ensure remote origin exists
                if ! git -C "$DEST_DIR" remote get-url origin &>/dev/null; then
                    echo "⚠️  Warning: remote 'origin' is not configured."
                    read -p "   Would you like to configure a remote now? (y/n): " remote_confirm
                    if [[ "$remote_confirm" == "y" || "$remote_confirm" == "Y" ]]; then
                        while true; do
                            read -e -p "   Enter remote URL (e.g. git@github.com:user/repo.git): " REMOTE_URL
                            if [[ -n "$REMOTE_URL" ]]; then
                                # Update remote origin if it exists already
                                if git -C "$DEST_DIR" remote | grep -q '^origin$'; then
                                    echo "   Remote 'origin' exists; updating URL..."
                                    git -C "$DEST_DIR" remote set-url origin "$REMOTE_URL"
                                else
                                    git -C "$DEST_DIR" remote add origin "$REMOTE_URL"
                                fi

                                # Verify the result matches what we just set
                                if [[ "$(git -C "$DEST_DIR" remote get-url origin)" == "$REMOTE_URL" ]]; then
                                    echo "✅ Remote 'origin' configured."
                                    # Normalize branch name to main
                                    git -C "$DEST_DIR" branch -M main
                                    break
                                else
                                    echo "❌ Failed to configure remote. Check the URL or permissions."
                                fi
                            else
                                echo "❌ URL cannot be empty."
                            fi
                        done
                    else
                        echo "⚠️  Remote configuration skipped. You can run 'git remote add origin <url>' later."
                    fi
                else
                    EXISTING_URL=$(git -C "$DEST_DIR" remote get-url origin)
                    echo "✅ Remote detected: $EXISTING_URL"
                fi
                break
            fi
        else
             echo "❌ Error: no write permission to destination. Check file permissions."
        fi
    else
        echo "❌ Error: directory does not exist. Create it first or enter a different path."
    fi
done

# 3. Configure log directory
echo ""
echo "👉 Enter log directory (leave blank for ./logs):"
read -e -p "Path: " LOG_DIR
if [ -z "$LOG_DIR" ]; then
    LOG_DIR="./logs"
fi

# Make sure Cron gets an absolute path
mkdir -p "$LOG_DIR"
# Convert to absolute using cd && pwd for portability
LOG_DIR=$(cd "$LOG_DIR" && pwd)
echo "✅ Log directory ready (absolute path): $LOG_DIR"

# 4. SSH key auto-detection
echo ""
echo "👉 Searching for existing SSH private keys..."

# Look for SSH keys in the default location
ssh_keys=()
# Loop to preserve portability vs. mapfile
while IFS= read -r line; do
    ssh_keys+=("$line")
done < <(find "$HOME/.ssh" -maxdepth 1 -type f -name "id_*" ! -name "*.pub" 2>/dev/null)

SSH_KEY_PATH=""

# Case 1: keys found
if [ ${#ssh_keys[@]} -gt 0 ]; then
    echo "✅ Detected the following SSH private keys:"
    options=("${ssh_keys[@]}" "Enter another path manually" "Generate a new key")
    
    # PS3 controls the select prompt
    PS3="Pick an option: "
    select choice in "${options[@]}"; do
        case "$choice" in
            "Enter another path manually")
                read -e -p "Enter SSH private key path: " SSH_KEY_PATH
                break
                ;;
            "Generate a new key")
                SSH_KEY_PATH="generate_new"
                break
                ;;
            *)
                if [[ -n "$choice" ]]; then
                    SSH_KEY_PATH="$choice"
                    break
                else
                    echo "❌ Invalid selection. Choose a valid number."
                fi
                ;;
        esac
    done
    PS3="" # Reset prompt
else
    # Case 2: no key discovered
    echo "🤔 No SSH private keys found in ~/.ssh."
    read -p "Create a new SSH key now? (y/n): " generate_confirm
    if [[ "$generate_confirm" == "y" || "$generate_confirm" == "Y" ]]; then
        SSH_KEY_PATH="generate_new"
    else
        echo "⚠️  Warning: no SSH key selected."
        read -e -p "You can still enter a path manually (leave blank to skip): " SSH_KEY_PATH
    fi
fi

# Optional key generation
if [[ "$SSH_KEY_PATH" == "generate_new" ]]; then
    echo "⚙️  Generating a new SSH key..."
    # Ask for email to embed as a comment
    user_email=""
    while [ -z "$user_email" ]; do
        read -p "Enter your email (for the key comment): " user_email
    done
    
    # Suggest a unique path to avoid overwriting existing keys
    NEW_KEY_PATH="$HOME/.ssh/id_ed25519_obsidian_sync"
    
    # Guard against overwriting an existing file
    if [ -f "$NEW_KEY_PATH" ]; then
        echo "⚠️  Warning: file '$NEW_KEY_PATH' already exists."
        read -p "   Overwrite it? (y/n): " overwrite_confirm
        if [[ "$overwrite_confirm" != "y" && "$overwrite_confirm" != "Y" ]]; then
            echo "   Cancelled."
            SSH_KEY_PATH="" # reset so we do not continue
        fi
    fi
    
    # Continue only if the sentinel is still set
    if [[ "$SSH_KEY_PATH" == "generate_new" ]]; then
        echo "   Creating ED25519 key..."
        # Non-interactive ED25519 generation
        ssh-keygen -t ed25519 -C "$user_email" -f "$NEW_KEY_PATH" -N ""
        
        if [ -f "$NEW_KEY_PATH" ]; then
            echo "✅ New SSH key generated at: $NEW_KEY_PATH"
            SSH_KEY_PATH="$NEW_KEY_PATH"
        else
            echo "❌ Error: key generation failed."
            SSH_KEY_PATH="" # reset because creation failed
        fi
    fi
fi

# Final reminder to add the key to GitHub
if [ -n "$SSH_KEY_PATH" ] && [ -f "$SSH_KEY_PATH" ]; then
    echo "✅ Using SSH private key: $SSH_KEY_PATH"
    PUBLIC_KEY_PATH="${SSH_KEY_PATH}.pub"
    if [ -f "$PUBLIC_KEY_PATH" ]; then
        echo ""
        echo "--------------------------------------------------"
        echo "🔴 Important: add the following public key to your GitHub account."
        echo "   1. Visit https://github.com/settings/keys"
        echo "   2. Click 'New SSH key'"
        echo "   3. Paste the content below into the Key field:"
        echo "-------------------[ PUBLIC KEY START ]-------------------"
        cat "$PUBLIC_KEY_PATH"
        echo "--------------------[ PUBLIC KEY END ]--------------------"
        echo ""
        read -n 1 -s -r -p "Press any key once you finish adding the key to GitHub..."
    fi
elif [ -n "$SSH_KEY_PATH" ]; then
    # Provided path does not exist or keygen failed
    echo "⚠️  Warning: '$SSH_KEY_PATH' is not a valid file."
fi

# Notify user when key path is empty
if [ -z "$SSH_KEY_PATH" ]; then
    echo "⚠️  Warning: SSH key path is empty. Git pushes may fail or prompt for a password."
fi

# 5. Generate config file
echo ""
echo "Generating $CONFIG_FILE ..."

cat > "$CONFIG_FILE" <<EOF
# Obsidian AutoSync Configuration
# Generated on $(date)

SOURCE_DIR="$SOURCE_DIR"
DEST_DIR="$DEST_DIR"
LOG_DIR="$LOG_DIR"
SSH_KEY_PATH="$SSH_KEY_PATH"
LOG_RETENTION_DAYS=$DEFAULT_LOG_RETENTION
EOF

# 6. Configure autosync schedule (crontab)
echo ""
echo "--------------------------------------------------"
echo "⏱️  Configure auto-sync frequency"
echo "You can schedule it now or configure later from the menu."
echo "--------------------------------------------------"

echo "Choose a preset:"
echo "  1. Every 15 minutes (recommended)"
echo "  2. Hourly"
echo "  3. Daily (02:00)"
echo "  4. Skip for now (manual only)"

read -p "Select [1-4]: " cron_choice

SYNC_SCRIPT="$SCRIPT_DIR/sync_and_push.sh"
NEW_CRON_SCHEDULE=""

case "$cron_choice" in
    1) NEW_CRON_SCHEDULE="*/15 * * * *";;
    2) NEW_CRON_SCHEDULE="0 * * * *";;
    3) NEW_CRON_SCHEDULE="0 2 * * *";;
    4) NEW_CRON_SCHEDULE="";;
    *) echo "   Invalid selection; skipping schedule."; NEW_CRON_SCHEDULE="";;
esac

if [ -n "$NEW_CRON_SCHEDULE" ]; then
    echo "   Updating crontab..."
    
    # Create a temporary file safely
    CRON_TMP_FILE=$(mktemp)

    # Remove old entries for this script
    # Use grep -F to ensure literal matching
    crontab -l 2>/dev/null | grep -v -F "$SYNC_SCRIPT" > "$CRON_TMP_FILE"

    # Append the new job
    echo "$NEW_CRON_SCHEDULE $SYNC_SCRIPT" >> "$CRON_TMP_FILE"

    # Apply new crontab
    if crontab "$CRON_TMP_FILE"; then
        echo "✅ Auto-sync enabled: $NEW_CRON_SCHEDULE"
    else
        echo "❌ Failed to update crontab."
    fi
    
    rm "$CRON_TMP_FILE"
else
    echo "   Auto-sync setup skipped."
fi

echo "--------------------------------------------------"
echo "🎉 Setup complete!"
echo "Make sure your main script (sync_and_push.sh) loads the config with:"
echo "source \"\$(dirname \"\$0\")/config.sh\""
echo "--------------------------------------------------"
