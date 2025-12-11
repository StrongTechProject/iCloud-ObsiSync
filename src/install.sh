#!/bin/bash

# ==========================================
# Obsidian AutoSync 一键安装脚本
# ==========================================

set -e

# ⚠️ TODO: 请将此处修改为你的 GitHub 用户名
GITHUB_USER="StrongTechProject"
REPO_NAME="iCloud-ObsiSync"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
INSTALL_DIR="$HOME/${REPO_NAME}"

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
# 获取脚本所在的真实目录 (src)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# 4. 运行配置向导
echo "⚙️  正在启动配置向导..."
cd "$INSTALL_DIR"
chmod +x src/*.sh

# 启动交互式配置
./src/setup.sh