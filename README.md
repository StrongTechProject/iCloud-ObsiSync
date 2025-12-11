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
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/StrongTechProject/iCloud-ObsiSync/main/install.sh)"
```

## Quick Start

1. **Setup**:
   ```bash
   ./src/setup.sh
   ```
   Follow the prompts to configure your source, destination, and SSH key.

2. **Run**:
   ```bash
   ./src/sync_and_push.sh
   ```

3. **Schedule**:
   Add to `crontab -e` for automatic background syncing.
