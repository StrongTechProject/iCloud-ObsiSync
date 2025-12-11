# Obsidian AutoSync

[English README](README.md) | [详细文档](docs/Doc.md)

一个用于将 iCloud 中的 Obsidian 笔记库自动同步到本地 Git 仓库并推送到 GitHub 的工具。

## ✨ 特性
- **自动同步**: 使用 `rsync` 将 iCloud 文件夹镜像备份到本地 Git 仓库。
- **版本控制**: 自动提交变更 (Commit) 并推送到远程 GitHub 仓库。
- **安全设计**: 敏感配置（路径、SSH Key）与代码分离，默认被 Git 忽略。
- **Cron 友好**: 专为定时任务设计，支持自动日志轮转和绝对路径处理。

## 🚀 快速开始

1. **初始化配置**:
   ```bash
   chmod +x src/setup.sh
   ./src/setup.sh
   ```
   按照提示输入 iCloud 路径、Git 仓库路径和 SSH Key 路径。

2. **手动运行**:
   ```bash
   ./src/sync_and_push.sh
   ```

3. **设置定时任务**:
   使用 `crontab -e` 添加定时任务，实现全自动备份。

详细说明请参考 [详细文档](docs/Doc.md)。
