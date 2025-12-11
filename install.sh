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

# 1. 检查 Git
if ! command -v git &> /dev/null; then
    echo "❌ 错误: 未找到 git 命令，请先安装 Git。"
    exit 1
fi

# 2. 准备安装目录
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  目录 '$INSTALL_DIR' 已存在。"
    echo "   如果你继续，该目录将被删除并重新克隆。"
    BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    echo "   即将把旧目录备份为: $BACKUP_DIR"
    read -p "   是否继续? (y/n) " -n 1 -r
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

# 4. 运行配置向导
echo "⚙️  正在启动配置向导..."
cd "$INSTALL_DIR"
chmod +x src/*.sh

# 启动交互式配置
./src/setup.sh