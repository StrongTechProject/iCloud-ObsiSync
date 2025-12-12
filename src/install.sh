#!/bin/bash

# ==========================================
# Obsidian AutoSync One-Click Installation Script
# ==========================================

set -e

# ⚠️ TODO: Change this to your GitHub username if you fork the project
GITHUB_USER="StrongTechProject"
REPO_NAME="Obsidian-Timemachine"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

# Smartly determine install directory
# Detect the real directory of the script (src) to see if it is run locally
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2>/dev/null && pwd )" || true
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# If the script runs inside the Git repo (local execution), use the current root directory
if [[ -d "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/install.sh" ]]; then
    INSTALL_DIR="$PROJECT_ROOT"
else
    # Otherwise (curl execution), install to a subdirectory under the current working directory
    INSTALL_DIR="$(pwd)/${REPO_NAME}"
fi

echo "--------------------------------------------------"
echo "🚀 Starting Obsidian AutoSync installation"
echo "--------------------------------------------------"

# 1. Check and install dependencies (Git, Rsync)
DEPENDENCIES=("git" "rsync")
MISSING_DEPS=()

for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "⚠️  Missing required dependencies: ${MISSING_DEPS[*]}"
    read -p "   Install these dependencies automatically? (y/n) " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled. Please install manually: ${MISSING_DEPS[*]}"
        exit 1
    fi

    echo "⬇️  Attempting to install dependencies..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install "${MISSING_DEPS[@]}"
        else
            echo "❌ Homebrew not found on macOS. Please install Homebrew first."
            exit 1
        fi
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update || true
        sudo apt-get install -y "${MISSING_DEPS[@]}"
    elif command -v yum &> /dev/null; then
        sudo yum install -y "${MISSING_DEPS[@]}"
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm "${MISSING_DEPS[@]}"
    else
        echo "❌ Unsupported package manager. Please install manually: ${MISSING_DEPS[*]}"
        exit 1
    fi

    # Double-check after installation
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "❌ Error: Failed to install '$dep'. Please install it manually."
            exit 1
        fi
    done
    echo "✅ Dependencies installed."
fi

# 2. Prepare install directory

# Detect whether we already run inside the install directory
if [[ "$PROJECT_ROOT" == "$INSTALL_DIR" ]]; then
    echo "✅ Running inside the install directory. Skipping clone."
else
    if [ -d "$INSTALL_DIR" ]; then
        echo "⚠️  Directory '$INSTALL_DIR' already exists."
        echo "   Continuing will move it to a backup and re-clone."
        BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "   Existing directory will be moved to: $BACKUP_DIR"
        read -p "   Continue? (y/n) " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
        mv "$INSTALL_DIR" "$BACKUP_DIR"
        echo "✅ Existing directory backed up."
    fi

    # 3. Clone repository
    echo "⬇️  Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 4. Create shortcut 'obsis'
echo "🔗 Configuring shortcut command 'obsis'..."
TARGET_BIN="/usr/local/bin/obsis"
# Use exec to preserve signals and keep BASH_SOURCE correct
WRAPPER_CONTENT="#!/bin/bash
exec \"$INSTALL_DIR/src/menu.sh\" \"\$@\""

# Attempt to write the wrapper
create_shortcut() {
    if [ -w "/usr/local/bin" ]; then
        echo "$WRAPPER_CONTENT" > "$TARGET_BIN"
        chmod +x "$TARGET_BIN"
        return 0
    else
        echo "⚠️  Trying to use sudo to create shortcut at $TARGET_BIN ..."
        echo "   (Administrator permission is needed to write to /usr/local/bin)"
        if echo "$WRAPPER_CONTENT" | sudo tee "$TARGET_BIN" > /dev/null; then
             sudo chmod +x "$TARGET_BIN"
             return 0
        else
             return 1
        fi
    fi
}

if create_shortcut; then
    echo "✅ Shortcut created! Just run 'obsis' in the terminal to open the menu."
else
    echo "❌ Failed to create shortcut (permission denied or cancelled)."
    echo "   You can still run './src/menu.sh' inside the directory."
fi

# 5. Launch management menu
echo "⚙️  Launching management menu..."
cd "$INSTALL_DIR"
chmod +x src/*.sh

# Start the management menu
./src/menu.sh
