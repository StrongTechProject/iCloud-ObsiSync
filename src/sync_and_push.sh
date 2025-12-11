#!/bin/zsh

# 获取脚本所在目录的绝对路径
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# ================= 配置区域 =================

# 1. 默认配置 (如果 config.sh 不存在)
SOURCE_DIR="/Users/your_username/Library/Mobile Documents/iCloud~md~obsidian/Documents/your_vault"
DEST_DIR="/path/to/your/local/backup/folder"
LOG_DIR="$SCRIPT_DIR/logs"
SSH_KEY_PATH="/path/to/your/private/ssh_key"
LOG_RETENTION_DAYS=7

# 2. 加载配置文件 (如果存在)
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=config.sh
    source "$CONFIG_FILE"
fi

# 3. 全局 Git SSH 配置
# 确保后续所有 git 操作都使用指定的 SSH Key
export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes"

# 4. 动态日志配置
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi
# 每日生成一个新的日志文件
LOG_FILE="$LOG_DIR/backup-$(date '+%Y-%m-%d').log"

# ===========================================

# 设置语言环境
export LC_ALL=en_US.UTF-8

# --- 工具函数: 写日志 ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# --- 工具函数: 发送 macOS 系统通知 (仅在出错时触发) ---
notify_error() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Obsidian Backup 失败\" subtitle \"请检查日志\" sound name \"Basso\""
}

# --- 阶段 0: 日志清理 (Log Rotation) ---
# 清理超过 LOG_RETENTION_DAYS 天的旧日志
if [ -d "$LOG_DIR" ]; then
    find "$LOG_DIR" -name "backup-*.log" -type f -mtime +"$LOG_RETENTION_DAYS" -delete
    # log "已清理 $LOG_RETENTION_DAYS 天前的旧日志" # 此时 log 函数尚未定义，且 LOG_FILE 刚确定
fi

log "=== 开始执行自动备份 ==="

# --- 阶段 1: 准备环境 ---
# 必须先进入 Git 目录，后续的 git pull 和 rsync 相对路径才安全
cd "$DEST_DIR" || {
    log "❌ 致命错误: 无法进入目录 $DEST_DIR"
    notify_error "无法找到备份目录"
    exit 1
}

# 修复 Git 中文乱码
git config core.quotepath false

# --- 阶段 2: 拉取远程更新 (Auto Pull) ---
# 使用 rebase 模式可以保持提交历史整洁（可选 --rebase，这里用默认 merge 比较稳妥）
log "🔄 正在检查远程更新 (Git Pull)..."
git pull origin main >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    log "⚠️ 警告: Git Pull 失败。可能是网络问题或存在冲突。将尝试继续执行 Rsync..."
    # 注意：这里不退出，因为我们希望本地备份（Rsync）具有最高优先级
else
    log "✅ Git Pull 完成。"
fi

# --- 阶段 3: 从 iCloud 镜像同步 (Rsync) ---
# 注意：此时我们已经在 DEST_DIR 里面了
log "📂 开始 Rsync 同步..."
rsync -av --delete --exclude '.git' --exclude '.DS_Store' "$SOURCE_DIR/" "$DEST_DIR/" >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    log "❌ 错误: Rsync 同步失败 (状态码 $?)。"
    notify_error "Rsync 文件同步失败"
    exit 1
fi

# --- 阶段 4: 提交与推送 (Commit & Push) ---
if [[ -n $(git status -s) ]]; then
    log "📝 检测到变动，准备提交..."
    
    git add .
    git commit -m "Auto-save: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
    
    log "🚀 正在推送到 GitHub..."
    git push origin main >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✅ 成功: 已推送到 GitHub。"
    else
        log "❌ 错误: Git Push 失败。请检查日志详情。"
        notify_error "Git Push 失败，请检查网络或冲突"
    fi
else
    log "☕ 无变动，跳过推送。"
fi

echo "-------------------------------------" >> "$LOG_FILE"