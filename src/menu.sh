#!/bin/bash

# ==========================================
# Obsidian AutoSync Management Menu
# ==========================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$SCRIPT_DIR/config.sh"
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "⚠️  Config file not found ($CONFIG_FILE)."
        echo "   Run '1. Quick Start' first to initialize."
        return 1
    fi
}

do_setup() {
    if [ -x "$SETUP_SCRIPT" ]; then
        "$SETUP_SCRIPT"
    else
        echo "❌ Error: Setup script not found at $SETUP_SCRIPT"
    fi
}

do_check_status() {
    echo "🔄 [Run sync now and inspect status]"
    if ! load_config; then return; fi
    
    SYNC_SCRIPT="$SCRIPT_DIR/sync_and_push.sh"
    if [ ! -x "$SYNC_SCRIPT" ]; then
        echo "❌ Error: Sync script not found at $SYNC_SCRIPT"
        return
    fi

    echo "⏳ Running sync (this may take a few seconds)..."
    "$SYNC_SCRIPT"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo "❌ Error: Log directory does not exist."
        return
    fi
    
    LATEST_LOG=$(find "$LOG_DIR" -name "backup-*.log" -type f | sort -r | head -n 1)
    
    if [ -f "$LATEST_LOG" ]; then
        echo "📄 Inspecting log: $(basename "$LATEST_LOG")"
        echo "-----------------------------------"
        
        if grep -q "✅ 成功: 已推送到 GitHub" "$LATEST_LOG"; then
            echo "✅ Status: Sync succeeded (changes pushed)"
        elif grep -q "☕ 无变动，跳过推送" "$LATEST_LOG"; then
            echo "✅ Status: Sync succeeded (no changes)"
        elif grep -q "❌ 错误" "$LATEST_LOG" || grep -q "❌ 致命错误" "$LATEST_LOG"; then
            echo "❌ Status: Sync failed (see log for details)"
            echo "   Key error lines:"
            grep "❌" "$LATEST_LOG" | tail -n 3
        else
            echo "⚠️  Status: Unknown (cannot determine from log)"
        fi
        echo "-----------------------------------"
    else
        echo "❌ Error: No log file found."
    fi
}

do_configure() {
    echo "🔧 [Configure]"
    if ! load_config; then return; fi

    echo "Current settings:"
    echo "  1. Git repository path (DEST_DIR): $DEST_DIR"
    echo "  2. Log directory (LOG_DIR):        $LOG_DIR"
    
    SYNC_SCRIPT="$SCRIPT_DIR/sync_and_push.sh"
    CRON_JOB=$(crontab -l 2>/dev/null | grep "$SYNC_SCRIPT")
    if [ -n "$CRON_JOB" ]; then
        echo "  3. Auto-sync schedule:            Enabled ($CRON_JOB)"
    else
        echo "  3. Auto-sync schedule:            Disabled"
    fi
    echo ""

    read -p "Which item do you want to change? (1/2/3/c to cancel): " choice
    case "$choice" in
        1)
            echo "Enter new Git repository path:"
            read -e -p "Path: " NEW_DEST
            NEW_DEST="${NEW_DEST%\"}"
            NEW_DEST="${NEW_DEST#\"}"
            
            if [ -d "$NEW_DEST" ]; then
                ESCAPED_DEST=$(printf '%s\n' "$NEW_DEST" | sed 's:[&|]:\\&:g')

                if [[ "$OSTYPE" == "darwin"* ]]; then
                     sed -i '' "s|DEST_DIR=\".*\"|DEST_DIR=\"$ESCAPED_DEST\"|g" "$CONFIG_FILE"
                else
                     sed -i "s|DEST_DIR=\".*\"|DEST_DIR=\"$ESCAPED_DEST\"|g" "$CONFIG_FILE"
                fi
                echo "✅ Git repository path updated to: $NEW_DEST"
            else
                echo "❌ Error: Directory does not exist."
            fi
            ;;
        2)
            echo "Enter new log directory path:"
            read -e -p "Path: " NEW_LOG
            NEW_LOG="${NEW_LOG%\"}"
            NEW_LOG="${NEW_LOG#\"}"
            
            mkdir -p "$NEW_LOG"
            NEW_LOG_ABS=$(cd "$NEW_LOG" && pwd)

            ESCAPED_LOG=$(printf '%s\n' "$NEW_LOG_ABS" | sed 's:[&|]:\\&:g')

            if [[ "$OSTYPE" == "darwin"* ]]; then
                 sed -i '' "s|LOG_DIR=\".*\"|LOG_DIR=\"$ESCAPED_LOG\"|g" "$CONFIG_FILE"
            else
                 sed -i "s|LOG_DIR=\".*\"|LOG_DIR=\"$ESCAPED_LOG\"|g" "$CONFIG_FILE"
            fi
            echo "✅ Log directory updated to: $NEW_LOG_ABS"
            ;;
        3)
            echo "⏱️  [Configure auto-sync schedule]"
            echo "Select a preset:"
            echo "  1. Every 15 minutes (recommended)"
            echo "  2. Every hour"
            echo "  3. Daily (02:00)"
            echo "  4. Disable auto-sync"
            echo "  5. Enter custom cron expression"
            
            read -p "Select [1-5]: " cron_choice
            
            NEW_CRON_SCHEDULE=""
            case "$cron_choice" in
                1) NEW_CRON_SCHEDULE="*/15 * * * *";;
                2) NEW_CRON_SCHEDULE="0 * * * *";;
                3) NEW_CRON_SCHEDULE="0 2 * * *";;
                4) NEW_CRON_SCHEDULE="DISABLED";;
                5) 
                   echo "Enter a cron expression (for example '*/30 * * * *'):"
                   read -e -p "Cron: " NEW_CRON_SCHEDULE
                   ;;
                *) echo "❌ Invalid option"; return;;
            esac

            CRON_TMP_FILE=$(mktemp)

            crontab -l 2>/dev/null | grep -v -F "$SYNC_SCRIPT" > "$CRON_TMP_FILE"

            if [ "$NEW_CRON_SCHEDULE" != "DISABLED" ] && [ -n "$NEW_CRON_SCHEDULE" ]; then
                echo "$NEW_CRON_SCHEDULE $SYNC_SCRIPT" >> "$CRON_TMP_FILE"
                echo "✅ Scheduled new cron job: $NEW_CRON_SCHEDULE"
            elif [ "$NEW_CRON_SCHEDULE" == "DISABLED" ]; then
                echo "✅ Auto-sync disabled."
            fi

            crontab "$CRON_TMP_FILE"
            rm "$CRON_TMP_FILE"
            echo "✅ Crontab updated."
            ;;
        c|C)
            echo "Cancelled."
            ;; 
        *)
            echo "Invalid option."
            ;; 
    esac
}

do_view_logs() {
    echo "📄 [View logs]"
    if ! load_config; then return; fi

    if [ ! -d "$LOG_DIR" ]; then
        echo "❌ Log directory does not exist: $LOG_DIR"
        return
    fi

    LATEST_LOG=$(find "$LOG_DIR" -name "backup-*.log" -type f | sort -r | head -n 1)

    if [ -z "$LATEST_LOG" ]; then
        echo "📭 No logs found in directory."
    else
        echo "Opening latest log: $LATEST_LOG"
        echo "Press Ctrl+C to exit"
        echo "-----------------------------------"
        tail -f "$LATEST_LOG"
    fi
}

do_uninstall() {
    echo "🗑️  [Uninstall]"
    echo "⚠️  Warning: this removes config files and project code."
    echo "   (Your Obsidian data stays untouched)"
    echo ""
    echo "Please review your crontab for any entries referencing this project."
    echo "Run 'crontab -e' and remove them manually if needed."
    echo ""
    read -p "Are you sure you want to uninstall? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        echo "Removing..."
        rm -f "$CONFIG_FILE"
        rm -rf "${SCRIPT_DIR}/logs"
        
        echo "✅ Config file removed."
        echo "⚠️  Run the following command to delete the project folder:"
        echo "   cd .. && rm -rf \"$(basename "$PROJECT_ROOT")\""
        exit 0
    else
        echo "Cancelled."
    fi
}

while true; do
    clear
    echo ""
    echo "==========================================="
    echo "      Obsidian-Timemachine Console"
    echo "==========================================="
    echo " 1. Quick Start (initialize or reset config)"
    echo " 2. Check sync status (run immediately)"
    echo " 3. Configure options"
    echo " 4. View real-time sync logs"
    echo " 5. Uninstall"
    echo " q. Quit"
    echo "-------------------------------------------"
    read -p "Choose an option [1-5, q]: " choice

    case "$choice" in
        1)
            do_setup
            ;;
        2)
            do_check_status
            ;;
        3)
            do_configure
            ;;
        4)
            do_view_logs
            ;;
        5)
            do_uninstall
            ;;
        q|Q)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option, try again."
            ;;
    esac
    
    if [[ "$choice" =~ ^[1235]$ ]]; then
        echo ""
        read -n 1 -s -r -p "Press any key to return to the menu..."
    fi

done
