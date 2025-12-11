#!/bin/bash

# ==========================================
# Obsidian AutoSync 一键安装脚本
# ==========================================

set -e

# ⚠️ TODO: 请将此处修改为你的 GitHub 用户名
GITHUB_USER="StrongTechProject"
REPO_NAME="iCloud-ObsiSync"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

# 智能判断安装目录
# 获取脚本所在的真实目录 (src) - 用于检测是否本地运行
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2>/dev/null && pwd )" || true
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 如果脚本是在 Git 仓库内运行 (本地执行)，则使用当前根目录
if [[ -d "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/install.sh" ]]; then
    INSTALL_DIR="$PROJECT_ROOT"
else
    # 否则 (curl 运行)，安装到当前执行目录下的子文件夹
    INSTALL_DIR="$(pwd)/${REPO_NAME}"
fi

echo "--------------------------------------------------"
echo "🚀 开始安装 Obsidian AutoSync"
echo "--------------------------------------------------"

# 1. 检查并安装依赖 (Git, Rsync)
DEPENDENCIES=("git" "rsync")
MISSING_DEPS=()

for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "⚠️  检测到缺少必要依赖: ${MISSING_DEPS[*]}"
    read -p "   是否确认自动安装这些依赖? (y/n) " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消，脚本退出。请手动安装: ${MISSING_DEPS[*]}"
        exit 1
    fi

    echo "⬇️  正在尝试自动安装依赖..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install "${MISSING_DEPS[@]}"
        else
            echo "❌ macOS 下未找到 Homebrew，无法自动安装。请先安装 Homebrew。"
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
        echo "❌ 无法识别的包管理器，请手动安装: ${MISSING_DEPS[*]}"
        exit 1
    fi

    # 再次检查
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "❌ 错误: 安装 '$dep' 失败，请手动安装。"
            exit 1
        fi
    done
    echo "✅ 依赖安装完成。"
fi

# 2. 准备安装目录

# 判断脚本是否已经在目标安装目录中运行
if [[ "$PROJECT_ROOT" == "$INSTALL_DIR" ]]; then
    echo "✅ 脚本正在安装目录中运行，跳过克隆步骤。"
else
    if [ -d "$INSTALL_DIR" ]; then
        echo "⚠️  目录 '$INSTALL_DIR' 已存在。"
        echo "   如果你继续，该目录将被删除并重新克隆。"
        BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "   即将把旧目录备份为: $BACKUP_DIR"
        read -p "   是否继续? (y/n) " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "已取消安装。"
            exit 1
        fi
        mv "$INSTALL_DIR" "$BACKUP_DIR"
        echo "✅ 已备份旧目录。"
    fi

    # 3. 克隆仓库
    echo "⬇️  正在克隆仓库..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 4. 创建快捷指令 'obsis'
echo "🔗 正在配置快捷指令 'obsis'..."
TARGET_BIN="/usr/local/bin/obsis"
# 使用 exec 确保 wrapper 不会吞掉信号，并且 BASH_SOURCE 指向正确
WRAPPER_CONTENT="#!/bin/bash
exec \"$INSTALL_DIR/src/menu.sh\" \"\$@\""

# 尝试写入 wrapper
create_shortcut() {
    if [ -w "/usr/local/bin" ]; then
        echo "$WRAPPER_CONTENT" > "$TARGET_BIN"
        chmod +x "$TARGET_BIN"
        return 0
    else
        echo "⚠️  正在尝试使用 sudo 创建快捷指令到 $TARGET_BIN ..."
        echo "   (需要管理员权限来写入 /usr/local/bin)"
        if echo "$WRAPPER_CONTENT" | sudo tee "$TARGET_BIN" > /dev/null; then
             sudo chmod +x "$TARGET_BIN"
             return 0
        else
             return 1
        fi
    fi
}

if create_shortcut; then
    echo "✅ 快捷指令已创建成功！以后只需在终端输入 'obsis' 即可打开菜单。"
else
    echo "❌ 快捷指令创建失败 (权限不足或取消)。"
    echo "   您仍然可以通过进入目录并运行 './src/menu.sh' 来使用。"
fi

# 5. 启动管理菜单
echo "⚙️  正在启动管理菜单..."
cd "$INSTALL_DIR"
chmod +x src/*.sh

# 启动管理菜单
./src/menu.sh