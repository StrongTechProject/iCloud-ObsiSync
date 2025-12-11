# iCloud-ObsiSync

[中文文档](README.zh.md) | [Documentation](docs/Doc.md)

An automated tool to sync your Obsidian Vault from iCloud or any local directory to a local Git repository and push changes to GitHub.

## Features
- **Auto-Sync**: Conditionally mirrors your Obsidian vault to a local Git repo using `rsync`. Skips `rsync` if the vault is directly managed as a Git repository.
- **Version Control**: Automatically commits and pushes changes to GitHub.
- **Secure**: Sensitive configuration (paths, SSH keys) is separated and ignored by Git.
- **Cron-Ready**: Optimized for running as a background cron job.

## Installation

**One-click Installation:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/StrongTechProject/iCloud-ObsiSync/main/src/install.sh)"
```

After installation, you can type `obsis` in your terminal to launch the management menu.

## Prerequisites
- **Git & GitHub Account**: You need a GitHub account to store your vault remotely.
- **SSH Key**: This tool uses SSH to push changes securely without passwords.
  > 🆕 **New to Git?** Check out our [Beginner's Guide to SSH Key Configuration](docs/Git_SSH_Config_Guide.md) for step-by-step instructions.

## Quick Start

1. **Management Menu** (Recommended):
   Run the following command (created during installation) to launch the menu:
   ```bash
   obsis
   ```
   Or run the script directly:
   ```bash
   ./src/menu.sh
   ```
   Select **Option 1 (Quick Start)** to configure your environment. The wizard now allows you to specify any Obsidian vault path (iCloud or local) and a Git repository path. If these paths are identical, the script will directly manage your vault with Git. You can also use this menu to **manage cron jobs (auto-sync frequency)**, view logs, or change settings later.

2. **Manual Run**:
   ```bash
   ./src/sync_and_push.sh
   ```

3. **Schedule**:
   Use the **Management Menu (Option 2 -> 3)** to easily set up auto-sync, or manually add to `crontab -e`.
