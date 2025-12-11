#!/bin/bash

# ==========================================
# Obsidian AutoSync 管理菜单
# ==========================================

# 获取脚本所在目录 (src 目录)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 项目根目录
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$SCRIPT_DIR/config.sh"
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"

# 加载配置函数
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "⚠️  未找到配置文件 ($CONFIG_FILE)。"
        echo "   建议先执行 '1. 快速开始' 进行初始化。"
        return 1
    fi
}

# 1. 快速开始
do_setup() {
    if [ -x "$SETUP_SCRIPT" ]; then
        "$SETUP_SCRIPT"
    else
        echo "❌ 错误: 找不到安装脚本 $SETUP_SCRIPT"
    fi
}

# 2. 检查同步状态 (立即同步)
do_check_status() {
    echo "🔄 [立即同步并检查状态]"
    if ! load_config; then return; fi
    
    SYNC_SCRIPT="$SCRIPT_DIR/sync_and_push.sh"
    if [ ! -x "$SYNC_SCRIPT" ]; then
        echo "❌ 错误: 找不到同步脚本 $SYNC_SCRIPT"
        return
    fi

    echo "⏳ 正在执行同步 (这可能需要几秒钟)..."
    "$SYNC_SCRIPT"
    
    # 检查最新的日志文件
    if [ ! -d "$LOG_DIR" ]; then
        echo "❌ 错误: 日志目录不存在。"
        return
    fi
    
    LATEST_LOG=$(find "$LOG_DIR" -name "backup-*.log" -type f | sort -r | head -n 1)
    
    if [ -f "$LATEST_LOG" ]; then
        echo "📄 分析日志: $(basename "$LATEST_LOG")"
        echo "-----------------------------------"
        
        # 简单的日志分析逻辑
        if grep -q "✅ 成功: 已推送到 GitHub" "$LATEST_LOG"; then
            echo "✅ 状态: 同步成功 (有更新已推送)"
        elif grep -q "☕ 无变动，跳过推送" "$LATEST_LOG"; then
            echo "✅ 状态: 同步成功 (无本地变动)"
        elif grep -q "❌ 错误" "$LATEST_LOG" || grep -q "❌ 致命错误" "$LATEST_LOG"; then
            echo "❌ 状态: 同步失败 (请查看详细日志)"
            echo "   关键错误信息:"
            grep "❌" "$LATEST_LOG" | tail -n 3
        else
            echo "⚠️  状态: 未知 (无法从日志中判断)"
        fi
        echo "-----------------------------------"
    else
        echo "❌ 错误: 未找到生成的日志文件。"
    fi
}

# 3. 修改配置
do_configure() {
    echo "🔧 [修改配置]"
    if ! load_config; then return; fi

    echo "当前配置:"
    echo "  1. Git 仓库路径 (DEST_DIR): $DEST_DIR"
    echo "  2. 日志目录 (LOG_DIR):     $LOG_DIR"
    
    # 检查 Crontab 状态
    SYNC_SCRIPT="$SCRIPT_DIR/sync_and_push.sh"
    CRON_JOB=$(crontab -l 2>/dev/null | grep "$SYNC_SCRIPT")
    if [ -n "$CRON_JOB" ]; then
        echo "  3. 自动同步频率:           已启用 ($CRON_JOB)"
    else
        echo "  3. 自动同步频率:           未启用"
    fi
    echo ""

    read -p "你要修改哪一项? (1/2/3/c取消): " choice
    case "$choice" in
        1)
            echo "请输入新的 Git 仓库路径:"
            read -e -p "Path: " NEW_DEST
            NEW_DEST="${NEW_DEST%\"}"
            NEW_DEST="${NEW_DEST#\"}"
            
            if [ -d "$NEW_DEST" ]; then
                # 转义路径中的特殊字符 (e.g., & |) 以防止 sed 命令出错
                ESCAPED_DEST=$(printf '%s\n' "$NEW_DEST" | sed 's:[&|]:\\&:g')

                if [[ "$OSTYPE" == "darwin"* ]]; then
                     sed -i '' "s|DEST_DIR=\".*\"|DEST_DIR=\"$ESCAPED_DEST\"|g" "$CONFIG_FILE"
                else
                     sed -i "s|DEST_DIR=\".*\"|DEST_DIR=\"$ESCAPED_DEST\"|g" "$CONFIG_FILE"
                fi
                echo "✅ Git 仓库路径已更新为: $NEW_DEST"
            else
                echo "❌ 错误: 目录不存在。"
            fi
            ;;
        2)
            echo "请输入新的日志目录路径:"
            read -e -p "Path: " NEW_LOG
            NEW_LOG="${NEW_LOG%\"}"
            NEW_LOG="${NEW_LOG#\"}"
            
            mkdir -p "$NEW_LOG"
            NEW_LOG_ABS=$(cd "$NEW_LOG" && pwd)

            # 转义路径中的特殊字符 (e.g., & |) 以防止 sed 命令出错
            ESCAPED_LOG=$(printf '%s\n' "$NEW_LOG_ABS" | sed 's:[&|]:\\&:g')

            if [[ "$OSTYPE" == "darwin"* ]]; then
                 sed -i '' "s|LOG_DIR=\".*\"|LOG_DIR=\"$ESCAPED_LOG\"|g" "$CONFIG_FILE"
            else
                 sed -i "s|LOG_DIR=\".*\"|LOG_DIR=\"$ESCAPED_LOG\"|g" "$CONFIG_FILE"
            fi
            echo "✅ 日志目录已更新为: $NEW_LOG_ABS"
            ;;
        3)
            echo "⏱️  [配置自动同步频率]"
            echo "请选择预设频率:"
            echo "  1. 每 15 分钟 (推荐)"
            echo "  2. 每小时"
            echo "  3. 每天 (凌晨 2:00)"
            echo "  4. 禁用自动同步"
            echo "  5. 手动输入 Cron 表达式"
            
            read -p "请选择 [1-5]: " cron_choice
            
            NEW_CRON_SCHEDULE=""
            case "$cron_choice" in
                1) NEW_CRON_SCHEDULE="*/15 * * * *";;
                2) NEW_CRON_SCHEDULE="0 * * * *";;
                3) NEW_CRON_SCHEDULE="0 2 * * *";;
                4) NEW_CRON_SCHEDULE="DISABLED";;
                5) 
                   echo "请输入 Cron 表达式 (例如 '*/30 * * * *'):"
                   read -e -p "Cron: " NEW_CRON_SCHEDULE
                   ;;
                *) echo "❌ 无效选项"; return;;
            esac

            # 使用 mktemp 创建安全的临时文件，并通过管道操作简化流程
            CRON_TMP_FILE=$(mktemp)

            # 从当前 crontab 中移除旧任务，并将结果存入临时文件
            # 使用 grep -F 可以确保将脚本路径作为固定字符串匹配，避免特殊字符问题
            crontab -l 2>/dev/null | grep -v -F "$SYNC_SCRIPT" > "$CRON_TMP_FILE"

            if [ "$NEW_CRON_SCHEDULE" != "DISABLED" ] && [ -n "$NEW_CRON_SCHEDULE" ]; then
                # 添加新任务到临时文件
                echo "$NEW_CRON_SCHEDULE $SYNC_SCRIPT" >> "$CRON_TMP_FILE"
                echo "✅ 已配置新任务: $NEW_CRON_SCHEDULE"
            elif [ "$NEW_CRON_SCHEDULE" == "DISABLED" ]; then
                echo "✅ 已禁用自动同步任务。"
            fi

            # 从临时文件加载新的 crontab
            crontab "$CRON_TMP_FILE"
            rm "$CRON_TMP_FILE" # 清理临时文件
            echo "✅ Crontab 已成功更新。"
            ;;
        c|C)
            echo "已取消。"
            ;; 
        *)
            echo "无效选项。"
            ;; 
    esac
}

# 4. 查看日志
do_view_logs() {
    echo "📄 [查看日志]"
    if ! load_config; then return; fi

    if [ ! -d "$LOG_DIR" ]; then
        echo "❌ 日志目录不存在: $LOG_DIR"
        return
    fi

    # 找到最新的日志文件
    LATEST_LOG=$(find "$LOG_DIR" -name "backup-*.log" -type f | sort -r | head -n 1)

    if [ -z "$LATEST_LOG" ]; then
        echo "📭 目录下没有找到日志文件。"
    else
        echo "正在打开最新日志: $LATEST_LOG"
        echo "按 Ctrl+C 退出查看"
        echo "-----------------------------------"
        tail -f "$LATEST_LOG"
    fi
}

# 5. 卸载项目
do_uninstall() {
    echo "🗑️  [卸载项目]"
    echo "⚠️  警告: 这将删除配置文件和本项目代码。"
    echo "   (不会删除你的 Obsidian 数据或 iCloud 数据)"
    echo ""
    echo "请务必检查你的 Crontab (定时任务) 是否引用了本项目。"
    echo "运行 'crontab -e' 查看并手动删除相关行。"
    echo ""
    read -p "确定要卸载吗? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        echo "正在删除..."
        rm -f "$CONFIG_FILE"
        rm -rf "${SCRIPT_DIR}/logs" # 删除默认日志目录
        
        echo "✅ 配置文件已删除。"
        echo "⚠️  请执行以下命令完全删除项目文件夹:"
        echo "   cd .. && rm -rf \"$(basename "$PROJECT_ROOT")\""
        exit 0
    else
        echo "已取消。"
    fi
}

# 主循环

while true; do

    # 清屏以获得更好的菜单体验

    clear

    echo ""

    echo "==========================================="

    echo "    Obsidian AutoSync 管理菜单"

    echo "==========================================="

    echo " 1. 快速开始 (初始化或重置配置)"

    echo " 2. 检查同步状态 (立即同步)"

    echo " 3. 修改配置"

    echo " 4. 查看实时同步日志"

    echo " 5. 卸载"

    echo " q. 退出"

    echo "-------------------------------------------"

    read -p "请输入选项 [1-5, q]: " choice



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

            echo "👋 感谢使用，再见!"

            exit 0

            ;;

        *)

            echo "❌ 无效选项，请重试。"

            ;;

    esac

    

    # 对需要暂停的操作进行处理，提升用户体验

    # 查看日志 (4) 和退出 (q) 不需要暂停

    if [[ "$choice" =~ ^[1235]$ ]]; then

        echo ""

        read -n 1 -s -r -p "按任意键返回主菜单..."

    fi

done
