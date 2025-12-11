#!/bin/bash

# ==========================================
# Obsidian AutoSync 初始化配置脚本
# ==========================================

# 脚本文件所在的目录 (src 目录)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
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
            IS_GIT_REPO=0
            if [ -d "$DEST_DIR/.git" ]; then
                echo "✅ 目标路径是一个有效的 Git 仓库."
                IS_GIT_REPO=1
            else
                echo "⚠️  警告: 目标路径存在，但似乎不是 Git 仓库 (未找到 .git)。"
                read -p "   是否初始化该目录为 Git 仓库? (y/n): " init_confirm
                if [[ "$init_confirm" == "y" || "$init_confirm" == "Y" ]]; then
                    echo "正在 $DEST_DIR 初始化 Git 仓库..."
                    git -C "$DEST_DIR" init
                    echo "✅ Git 仓库已成功初始化."
                    IS_GIT_REPO=1
                else
                    read -p "   是否继续而不初始化? (y/n): " continue_confirm
                    if [[ "$continue_confirm" == "y" || "$continue_confirm" == "Y" ]]; then
                        break
                    fi
                fi
            fi

            if [ $IS_GIT_REPO -eq 1 ]; then
                # 检查远程仓库配置
                if ! git -C "$DEST_DIR" remote get-url origin &>/dev/null; then
                    echo "⚠️  警告: 未检测到远程仓库配置 (remote 'origin')。"
                    read -p "   是否需要配置远程仓库地址? (y/n): " remote_confirm
                    if [[ "$remote_confirm" == "y" || "$remote_confirm" == "Y" ]]; then
                        while true; do
                            read -e -p "   请输入远程仓库 URL (例如 git@github.com:user/repo.git): " REMOTE_URL
                            if [[ -n "$REMOTE_URL" ]]; then
                                # 检查 remote 'origin' 是否已存在
                                if git -C "$DEST_DIR" remote | grep -q '^origin$'; then
                                    echo "   检测到已存在的 remote 'origin'，将更新其 URL..."
                                    git -C "$DEST_DIR" remote set-url origin "$REMOTE_URL"
                                else
                                    git -C "$DEST_DIR" remote add origin "$REMOTE_URL"
                                fi

                                # 通过回读 URL 来验证操作是否真的成功
                                if [[ "$(git -C "$DEST_DIR" remote get-url origin)" == "$REMOTE_URL" ]]; then
                                    echo "✅ 远程仓库 'origin' 已成功配置."
                                    # 尝试将当前分支重命名为 main (现代 Git 仓库的推荐做法)
                                    git -C "$DEST_DIR" branch -M main
                                    break
                                else
                                    echo "❌ 远程仓库配置失败，请检查 URL 或权限后重试。"
                                fi
                            else
                                echo "❌ URL 不能为空。"
                            fi
                        done
                    else
                        echo "⚠️  已跳过远程配置。请稍后手动运行 'git remote add origin <url>'。"
                    fi
                else
                    EXISTING_URL=$(git -C "$DEST_DIR" remote get-url origin)
                    echo "✅ 已检测到远程仓库: $EXISTING_URL"
                fi
                break
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

# 4. SSH Key 自动配置
echo ""
echo "👉 正在自动查找 SSH 私钥..."

# 在默认位置查找潜在的 SSH 密钥
ssh_keys=()
# 使用循环以获得比 mapfile 更好的可移植性
while IFS= read -r line; do
    ssh_keys+=("$line")
done < <(find "$HOME/.ssh" -maxdepth 1 -type f -name "id_*" ! -name "*.pub" 2>/dev/null)

SSH_KEY_PATH=""

# 情况 1：找到密钥
if [ ${#ssh_keys[@]} -gt 0 ]; then
    echo "✅ 发现了以下 SSH 私钥:"
    options=("${ssh_keys[@]}" "手动输入其他路径" "生成一个新的密钥")
    
    # PS3 是 `select` 的提示符
    PS3="请选择一个选项: "
    select choice in "${options[@]}"; do
        case "$choice" in
            "手动输入其他路径")
                read -e -p "请输入 SSH 私钥路径: " SSH_KEY_PATH
                break
                ;;
            "生成一个新的密钥")
                SSH_KEY_PATH="generate_new"
                break
                ;;
            *)
                if [[ -n "$choice" ]]; then
                    SSH_KEY_PATH="$choice"
                    break
                else
                    echo "❌ 无效选项，请输入选项对应的数字。"
                fi
                ;;
        esac
    done
    PS3="" # Reset prompt
else
    # 情况 2：未找到密钥
    echo "🤔 未在默认位置 (~/.ssh/) 找到 SSH 私钥。"
    read -p "是否需要为您生成一个新的 SSH 密钥? (y/n): " generate_confirm
    if [[ "$generate_confirm" == "y" || "$generate_confirm" == "Y" ]]; then
        SSH_KEY_PATH="generate_new"
    else
        echo "⚠️  警告: 未选择 SSH 密钥。"
        read -e -p "您仍然可以手动输入一个路径 (留空则跳过): " SSH_KEY_PATH
    fi
fi

# 密钥生成逻辑
if [[ "$SSH_KEY_PATH" == "generate_new" ]]; then
    echo "⚙️  开始生成新的 SSH 密钥..."
    # 为新密钥请求邮箱地址
    user_email=""
    while [ -z "$user_email" ]; do
        read -p "请输入您的邮箱地址 (用于密钥注释): " user_email
    done
    
    # 建议一个唯一的名称以避免覆盖现有密钥
    NEW_KEY_PATH="$HOME/.ssh/id_ed25519_obsidian_sync"
    
    # 检查文件是否已存在
    if [ -f "$NEW_KEY_PATH" ]; then
        echo "⚠️  警告: 文件 '$NEW_KEY_PATH' 已存在。"
        read -p "   是否覆盖? (y/n): " overwrite_confirm
        if [[ "$overwrite_confirm" != "y" && "$overwrite_confirm" != "Y" ]]; then
            echo "   操作取消。"
            SSH_KEY_PATH="" # 重置路径
        fi
    fi
    
    # 如果路径仍然设置，则继续生成
    if [[ "$SSH_KEY_PATH" == "generate_new" ]]; then
        echo "   正在生成 ED25519 密钥..."
        # 非交互式生成 ED25519 密钥
        ssh-keygen -t ed25519 -C "$user_email" -f "$NEW_KEY_PATH" -N ""
        
        if [ -f "$NEW_KEY_PATH" ]; then
            echo "✅ 新的 SSH 密钥已成功生成于: $NEW_KEY_PATH"
            SSH_KEY_PATH="$NEW_KEY_PATH"
        else
            echo "❌ 错误: 密钥生成失败。"
            SSH_KEY_PATH="" # 重置路径以避免问题
        fi
    fi
fi

# 对用户的最终检查和显示公钥
if [ -n "$SSH_KEY_PATH" ] && [ -f "$SSH_KEY_PATH" ]; then
    echo "✅ 已选择此 SSH 私钥: $SSH_KEY_PATH"
    PUBLIC_KEY_PATH="${SSH_KEY_PATH}.pub"
    if [ -f "$PUBLIC_KEY_PATH" ]; then
        echo ""
        echo "--------------------------------------------------"
        echo "🔴 重要操作: 请将以下公钥内容添加到您的 GitHub 账户!"
        echo "   1. 访问: https://github.com/settings/keys"
        echo "   2. 点击 'New SSH key'"
        echo "   3. 将下面的内容完整粘贴到 'Key' 字段中:"
        echo "-------------------[ PUBLIC KEY START ]-------------------"
        cat "$PUBLIC_KEY_PATH"
        echo "--------------------[ PUBLIC KEY END ]--------------------"
        echo ""
        read -n 1 -s -r -p "完成 GitHub 添加操作后，按任意键继续..."
    fi
elif [ -n "$SSH_KEY_PATH" ]; then
    # 用户输入的路径不存在或生成失败的情况
    echo "⚠️  警告: 指定的路径 '$SSH_KEY_PATH' 不是一个有效的文件。"
fi

# 如果 SSH_KEY_PATH 仍然为空，通知用户。
if [ -z "$SSH_KEY_PATH" ]; then
    echo "⚠️  警告: 未配置 SSH 密钥路径。脚本将继续，但 Git 推送可能会失败或要求密码。"
fi

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