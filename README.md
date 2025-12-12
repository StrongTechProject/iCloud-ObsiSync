# Obsidian-Timemachine ⏳

[中文文档](README.zh.md) | [Documentation](docs/Doc.md)

**A "Set and Forget" automated backup solution for your Obsidian Vault.**

Unlike internal plugins, **Obsidian-Timemachine** runs as a system-level background process. It automatically syncs your vault (from iCloud Drive or any local path) to a Git repository and pushes changes to GitHub, ensuring your data is safe even if you never open Obsidian.

## 🚀 Why Obsidian-Timemachine?

While plugins like *obsidian-git* are great, **Obsidian-Timemachine** offers distinct advantages for data safety:

| Feature | 🔌 Obsidian Plugins | 🛡️ Obsidian-Timemachine |
| :--- | :--- | :--- |
| **Dependency** | **Must open Obsidian** to trigger backup. | **Zero dependency.** Runs in background (cron) even if Obsidian is closed. |
| **Performance** | Uses JS-based Git (slower for large vaults). | Uses **Native Git & Rsync** (fast, efficient, stable). |
| **Safety** | Direct Git ops in sync folders (risk of conflicts). | **Separation mode**: Mirrors source to a clean Git repo via Rsync. |
| **Philosophy** | "Version Control Tool" | **"Automated Disaster Recovery"** |

## ✨ Features

- **Background Automation**: Runs silently via Cron. You focus on writing; we handle the saving.
- **Dual Modes**:
    1.  **Direct Mode**: Directly manages your local vault with Git.
    2.  **Mirror Mode (Best for iCloud)**: Uses `rsync` to mirror your iCloud vault to a separate local Git repo, preventing iCloud sync conflicts from corrupting your Git history.
- **Secure**: Sensitive configuration (paths, SSH keys) is completely separated from the code.
- **Smart Logging**: Auto-rotates logs and keeps your system clean.

## 📥 Installation

**One-click Installation:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/StrongTechProject/Obsidian-Timemachine/main/src/install.sh)"
```
*(Note: The repository URL will be updated once you rename the GitHub repo, currently pointing to the existing path)*

After installation, type `obsis` in your terminal to launch the **Time Machine Control Panel**.

## 🛠 Quick Start

1.  **Setup Wizard**:
    Run `obsis` and select **Option 1 (Quick Start)**.
    *   **Source**: Your Obsidian Vault path.
    *   **Destination**: Where you want the Git repository (can be the same as Source for Direct Mode).
    *   **SSH Key**: Auto-detects or generates a secure key for GitHub.

2.  **Schedule (The "Time Machine" part)**:
    Use **Option 3** in the menu to set a frequency (e.g., every 15 mins). Once set, you can forget about it.

3.  **Manual Run**:
    ```bash
    ./src/sync_and_push.sh
    ```

## Prerequisites
- **Git & GitHub Account**
- **SSH Key**: [Beginner's Guide to SSH Key Configuration](docs/Git_SSH_Config_Guide.md)