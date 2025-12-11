#!/bin/bash

# ==========================================
# Obsidian AutoSync 初始化配置脚本
# ==========================================

CONFIG_FILE="config.sh"
DEFAULT_LOG_RETENTION=7

echo "--------------------------------------------------"
echo "👋 欢迎使用 Obsidian AutoSync 配置向导"
echo "此脚本将生成 '$CONFIG_FILE' 配置文件。"
echo "--------------------------------------------------"

# 0. 环境依赖检查
echo "🔍 正在检查系统依赖..."
MISSING_DEPS=0
for cmd in git rsync; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ 错误: 未找到命令 '$cmd'。请先安装它。"
        MISSING_DEPS=1
    else
        echo "✅ Found $cmd"
    fi
done

if [ $MISSING_DEPS -ne 0 ]; then
    echo "⚠️  缺少必要依赖，脚本无法继续。请安装 git 和 rsync 后重试。"
    exit 1
fi

# 1. 获取 iCloud 源路径
while true; do
    echo ""
    echo "👉 请输入 Obsidian iCloud 源目录路径 (Source):"
    echo "   (提示: 你可以直接将文件夹拖入此终端窗口)"
    read -e -p "Path: " SOURCE_DIR
    # 去除可能存在的引号（macOS 拖拽可能会加引号）
    SOURCE_DIR="${SOURCE_DIR%\"}"
    SOURCE_DIR="${SOURCE_DIR#\"}"
    
    if [ -d "$SOURCE_DIR" ]; then
        echo "✅ 源路径有效."
        break
    else
        echo "❌ 错误: 目录不存在，请重新输入。"
    fi
done

# 2. 获取本地 Git 仓库路径
while true; do
    echo ""
    echo "👉 请输入本地 Git 仓库目标路径 (Destination):"
    read -e -p "Path: " DEST_DIR
    DEST_DIR="${DEST_DIR%\"}"
    DEST_DIR="${DEST_DIR#\"}"

    if [ -d "$DEST_DIR" ]; then
        if [ -w "$DEST_DIR" ]; then
             if [ -d "$DEST_DIR/.git" ]; then
                echo "✅ 目标路径是一个有效的 Git 仓库."
                break
            else
                echo "⚠️  警告: 目标路径存在，但似乎不是 Git 仓库 (未找到 .git)。"
                read -p "   是否继续? (y/n): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    break
                fi
            fi
        else
             echo "❌ 错误: 对目标路径没有写入权限，请检查权限设置。"
        fi
    else
        echo "❌ 错误: 目录不存在，请先创建该目录或重新输入。"
    fi
done

# 3. 设置日志目录
echo ""
echo "👉 请输入日志存放目录 (留空则默认为 ./logs):"
read -e -p "Path: " LOG_DIR
if [ -z "$LOG_DIR" ]; then
    LOG_DIR="./logs"
fi

# 创建并转换为绝对路径 (这对 Cron 运行至关重要)
mkdir -p "$LOG_DIR"
# 使用 cd && pwd 获取绝对路径，兼容性好
LOG_DIR=$(cd "$LOG_DIR" && pwd)
echo "✅ 日志目录已准备 (绝对路径): $LOG_DIR"

# 4. SSH Key 配置
while true; do
    echo ""
    echo "👉 请输入用于 GitHub 的 SSH 私钥路径:"
    echo "   (通常在 ~/.ssh/id_rsa 或 ~/.ssh/id_ed25519)"
    read -e -p "Path: " SSH_KEY_PATH
    SSH_KEY_PATH="${SSH_KEY_PATH%\"}"
    SSH_KEY_PATH="${SSH_KEY_PATH#\"}"

    if [ -f "$SSH_KEY_PATH" ]; then
        echo "✅ SSH Key 文件存在."
        break
    else
        echo "⚠️  警告: 文件不存在。"
        read -p "   是否确认使用此路径? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            break
        fi
    fi
done

# 5. 生成配置文件
echo ""
echo "正在生成 $CONFIG_FILE ..."

cat > "$CONFIG_FILE" <<EOF
# Obsidian AutoSync Configuration
# Generated on $(date)

SOURCE_DIR="$SOURCE_DIR"
DEST_DIR="$DEST_DIR"
LOG_DIR="$LOG_DIR"
SSH_KEY_PATH="$SSH_KEY_PATH"
LOG_RETENTION_DAYS=$DEFAULT_LOG_RETENTION
EOF

echo "--------------------------------------------------"
echo "🎉 配置完成！"
echo "请确保你的主脚本 (sync_and_push.sh) 包含以下代码来加载配置："
echo "source \"\$(dirname \"\$0\")/config.sh\""
echo "--------------------------------------------------"