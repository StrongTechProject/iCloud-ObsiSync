# 📚 iCloud-ObsiSync 自动同步流程文档

## 1. 流程概述

本流程旨在将存储在 **iCloud Drive** 中的 Obsidian Vault 笔记库自动同步（镜像备份）到本地指定目录，并利用 **Git** 工具将所有变动提交（Commit）并推送到 **GitHub** 远程仓库，实现 Obsidian 笔记的自动化版本管理和异地备份。

### ✨ 主要功能
- **一键安装**: 提供 `install.sh` 脚本，自动克隆并启动配置向导。
- **自动配置向导**: 提供 `setup.sh` 脚本，交互式完成环境配置。
- **安全配置分离**: 配置文件 `config.sh` 包含敏感路径，默认被 Git 忽略，防止泄露。
- **智能日志管理**: 按日期生成日志，自动清理过期日志，支持绝对路径（适配 Cron）。
- **自动化同步**: 集成 Rsync 镜像与 Git 提交/推送流程。

---

## 2. 快速开始 (Quick Start)

### 2.1 安装与配置

**推荐使用一键安装脚本：**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/StrongTechProject/iCloud-ObsiSync/main/src/install.sh)"
```
该脚本会自动克隆仓库并运行配置向导。

**管理与配置：**

推荐使用交互式菜单进行管理：
```bash
./src/menu.sh
```
*   **1. 快速开始**: 运行初始化配置向导。
*   **2. 更改路径**: 修改 Git 仓库或日志存储路径。
*   **3. 查看日志**: 实时查看最新同步日志。
*   **4. 卸载**: 清理项目文件。

**或者手动运行初始化脚本：**

1. 打开终端，进入项目目录：
   ```bash
   cd /path/to/iCloud-ObsiSync
   ```

2. 运行初始化脚本：
   ```bash
   ./src/setup.sh
   ```
   *脚本会引导你输入 iCloud 源路径、本地 Git 仓库路径、日志目录以及 SSH Key 路径。*
   *脚本会自动检查系统依赖 (Git, Rsync) 和目录权限。*

3. 生成结果：
   脚本会在 `src/` 目录下生成 `config.sh` 文件。请检查该文件内容是否正确。

### 2.2 手动运行测试
配置完成后，你可以尝试手动运行一次主脚本：
```bash
./src/sync_and_push.sh
```
观察终端输出或检查日志目录下的最新日志文件，确认同步成功。

---

## 3. 文件结构

| **文件/目录** | **路径示例** | **说明** |
| :--- | :--- | :--- |
| **管理菜单** | `src/menu.sh` | **推荐入口**。提供配置、日志查看、卸载等一站式管理功能。 |
| **安装脚本** | `src/install.sh` | **一键安装入口**。负责克隆仓库和启动配置。 |
| **初始化脚本** | `src/setup.sh` | **配置向导**。用于生成配置文件和检查环境。 |
| **核心脚本** | `src/sync_and_push.sh` | **定时任务调用的目标**。执行同步、提交和推送的核心逻辑。 |
| **配置文件** | `src/config.sh` | 由 `setup.sh` 生成。包含路径、SSH Key 等敏感配置。**已加入 .gitignore**。 |
| **日志目录** | `src/logs/` (默认) | 存放每日执行日志 (如 `backup-2025-12-11.log`)。路径可在配置中自定义。 |
| **文档** | `docs/Doc.md` | 本说明文档。 |

---

## 4. 自动化部署 (Cron Job)

使用 macOS/Linux 的 `crontab` 实现定时自动运行。

1. 编辑 Crontab：
   ```bash
   crontab -e
   ```

2. 添加定时任务 (示例：每 20 分钟执行一次)：
   ```cron
   */20 * * * * /path/to/iCloud-ObsiSync/src/sync_and_push.sh
   ```
   *> 注意：请确保填写脚本的**绝对路径**。*

---

## 5. 技术细节

### 5.1 脚本工作流程 (`sync_and_push.sh`)

1. **加载配置**: 自动查找并加载同目录下的 `config.sh`。
2. **环境准备**:
   - 设置全局 `GIT_SSH_COMMAND`，确保 Git 操作使用指定的 SSH Key。
   - 确保日志目录存在（自动处理绝对路径）。
3. **日志清理**: 检查日志目录，自动删除超过 `LOG_RETENTION_DAYS` (默认7天) 的旧日志文件。
4. **Git Pull**: 尝试拉取远程更新，防止本地提交冲突。
5. **Rsync 同步**: 将 iCloud 源目录镜像到本地 Git 仓库（带 `--delete` 标志，保持完全一致）。
6. **Git Push**: 检查变动，如果有变更则自动 Commit 并 Push 到远程 `main` 分支。

### 5.2 安全性

- **SSH Key**: 脚本不依赖 SSH Agent，而是通过 `GIT_SSH_COMMAND` 显式指定私钥路径，确保 Cron 环境下认证稳定。
- **Gitignore**: `config.sh` 和 `logs/` 目录默认被忽略，避免将个人路径和日志提交到公共仓库。

---

## 6. 故障排除 (Troubleshooting)

| **问题现象** | **可能原因** | **解决方案** |
| :--- | :--- | :--- |
| **配置脚本报错 "Permission denied"** | 脚本没有执行权限 | 运行 `chmod +x src/setup.sh` |
| **Cron 任务不执行或日志找不到** | 路径问题 | 1. 确保 Crontab 中使用了绝对路径。<br>2. 检查 `config.sh` 中的 `LOG_DIR` 是否为绝对路径 (`setup.sh` 会自动处理此项)。 |
| **Git Push 失败 (Permission denied)** | SSH Key 路径错误或权限不对 | 1. 检查 `config.sh` 中 `SSH_KEY_PATH` 是否正确。<br>2. 确保私钥权限为 600 (`chmod 600 ~/.ssh/id_rsa`)。 |
| **Rsync 报错 "Operation not permitted"** | 终端/Cron 无磁盘访问权限 | 在 macOS "系统设置 -> 隐私与安全性 -> 完全磁盘访问权限" 中添加 `Terminal`、`iTerm` 或 `cron` (如果是定时任务)。 |
