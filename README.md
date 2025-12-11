# iCloud-ObsiSync

[中文文档](README.zh.md) | [Documentation](docs/Doc.md)

An automated tool to sync your Obsidian Vault from iCloud to a local Git repository and push changes to GitHub.

## Features
- **Auto-Sync**: Mirrors iCloud folder to a local Git repo using `rsync`.
- **Version Control**: Automatically commits and pushes changes to GitHub.
- **Secure**: Sensitive configuration (paths, SSH keys) is separated and ignored by Git.
- **Cron-Ready**: Optimized for running as a background cron job.

## Installation

**One-click Installation:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/StrongTechProject/iCloud-ObsiSync/main/src/install.sh)"
```

## Prerequisites
- **Git & GitHub Account**: You need a GitHub account to store your vault remotely.
- **SSH Key**: This tool uses SSH to push changes securely without passwords.
  > 🆕 **New to Git?** Check out our [Beginner's Guide to SSH Key Configuration](docs/Git_SSH_Config_Guide.md) for step-by-step instructions.

## Quick Start

1. **Management Menu** (Recommended):
   ```bash
   ./src/menu.sh
   ```
   Select **Option 1 (Quick Start)** to configure your environment. You can also use this menu to view logs or change settings later.

2. **Manual Run**:
   ```bash
   ./src/sync_and_push.sh
   ```

3. **Schedule**:
   Add to `crontab -e` for automatic background syncing.
