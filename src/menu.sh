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

# 2. 更改路径
do_change_paths() {
    echo "🔧 [更改路径设置]"
    if ! load_config; then return; fi

    echo "当前配置:"
    echo "  1. Git 仓库路径 (DEST_DIR): $DEST_DIR"
    echo "  2. 日志目录 (LOG_DIR):     $LOG_DIR"
    echo ""

    read -p "你要修改哪一项? (1/2/c取消): " choice
    case "$choice" in
        1)
            echo "请输入新的 Git 仓库路径:"
            read -e -p "Path: " NEW_DEST
            # 去除引号
            NEW_DEST="${NEW_DEST%\"}"
            NEW_DEST="${NEW_DEST#\"}"
            
            if [ -d "$NEW_DEST" ]; then
                # 使用 sed 替换配置文件中的 DEST_DIR 行
                # 使用 | 作为分隔符避免路径中的 / 冲突
                if [[ "$OSTYPE" == "darwin"* ]]; then
                     sed -i '' "s|DEST_DIR=\".*\"|DEST_DIR=\"$NEW_DEST\"|g" "$CONFIG_FILE"
                else
                     sed -i "s|DEST_DIR=\".*\"|DEST_DIR=\"$NEW_DEST\"|g" "$CONFIG_FILE"
                fi
                echo "✅ Git 仓库路径已更新为: $NEW_DEST"
            else
                echo "❌ 错误: 目录不存在。"
            fi
            ;;
        2)
            echo "请输入新的日志目录路径:"
            read -e -p "Path: " NEW_LOG
            # 去除引号
            NEW_LOG="${NEW_LOG%\"}"
            NEW_LOG="${NEW_LOG#\"}"
            
            # 创建目录并转绝对路径
            mkdir -p "$NEW_LOG"
            NEW_LOG=$(cd "$NEW_LOG" && pwd)

            if [[ "$OSTYPE" == "darwin"* ]]; then
                 sed -i '' "s|LOG_DIR=\".*\"|LOG_DIR=\"$NEW_LOG\"|g" "$CONFIG_FILE"
            else
                 sed -i "s|LOG_DIR=\".*\"|LOG_DIR=\"$NEW_LOG\"|g" "$CONFIG_FILE"
            fi
            echo "✅ 日志目录已更新为: $NEW_LOG"
            ;;
        c|C)
            echo "已取消。"
            ;; 
        *)
            echo "无效选项。"
            ;; 
    esac
}

# 3. 查看日志
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

# 4. 卸载项目
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

    echo " 2. 更改 Git 仓库或日志路径"

    echo " 3. 查看实时同步日志"

    echo " 4. 卸载"

    echo " q. 退出"

    echo "-------------------------------------------"

    read -p "请输入选项 [1-4, q]: " choice



    case "$choice" in

        1)

            do_setup

            ;;

        2)

            do_change_paths

            ;;

        3)

            do_view_logs

            ;;

        4)

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

    # 查看日志 (3) 和退出 (q) 不需要暂停

    if [[ "$choice" =~ ^[124]$ ]]; then

        echo ""

        read -n 1 -s -r -p "按任意键返回主菜单..."

    fi

done
