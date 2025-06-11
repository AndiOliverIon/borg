# 🧠 BORG — Backup Orchestrator for Reliable Groundwork ![PowerShell 7.5.1+](https://img.shields.io/badge/PowerShell-7.5.1%2B-blue)

BORG is a modular automation shell designed to manage SQL Server Docker containers and automate backup/restore workflows using robust scripting practices.

---

## 🚀 Features

- 🔄 Restore a `.bak` file using either its default name or a proposed alias
- 📦 Docker SQL Server orchestration with automatic upload & provisioning
- 🔐 Handles `sqlcmd` ODBC TLS issues (ODBC Driver 18+ safe)
- 🧩 Modular architecture: scripts organized into `central`, `docker`, `database`
- 💬 Clean terminal UI with emoji-enhanced logging

---

## 📁 Project Structure

```
borg/
├── config/               # Shared functions and configuration
├── data/                 # Data store (e.g. for values, presets)
├── logs/                 # Optional runtime logs
├── scripts/              # Main execution logic
│   └── win/
│       ├── central/      # Main entry points / menu scripts
│       ├── docker/       # Docker SQL helper logic
│       └── database/     # Placeholder for future DB tooling
├── resources/            # Optional assets
├── temp/                 # Temporary working folder
└── README.md             # You're reading this
```

---

## 🛠️ Requirements

Borg relies on a few modern terminal utilities to provide an interactive and user-friendly experience.

| Tool    | Purpose                          | Install Command          |
|---------|----------------------------------|--------------------------|
| `fzf`   | Fuzzy finder for file selection  | `winget install fzf`     |
| `micro` | Terminal-based text editor       | `winget install zyedidia.micro`   |
| `rclone` | Google Drive integration    | Manual install from [rclone.org](https://rclone.org/downloads) |

These tools are used for interactive prompts and editing operations. If not installed, Borg scripts may fall back to simpler prompts or raise an error.

---

## 🧪 Getting Started

> PowerShell 7.5.1 and Docker Desktop are required.

### Install via Git Clone
```bash
git clone https://github.com/your-org/borg.git
```

### Install via PowerShell Gallery (if published)
```powershell
Install-Module Borg -Scope CurrentUser
```

### Inject into your PowerShell profile
```powershell
# >>> BORG INITIALIZATION START <<<
Import-Module Borg
# Optionally create a shortcut alias
Set-Alias b borg
# <<< BORG INITIALIZATION END >>>
```

### Initialize Configuration

When you run any BORG command for the first time, a default `store.json` file will be created in the `data/` folder using `store.example.json` as a template (if it doesn't already exist).

To edit your configuration, you can use:

```powershell
# Open the config file using Micro (or your preferred text editor):
borg store
```

Alternatively, you can open `data\store.json` in any text editor like Notepad, VS Code, or others.


Example configuration:
```json
{  
  "Docker": {
    "SqlContainer": "sqlserver-2022",
    "SqlInstance": "localhost,2022",
    "SqlImageTag": "mcr.microsoft.com/mssql/server:2022-latest",
    "SqlPort": 1433,
    "SqlUser": "sa",
    "SqlPassword": "yourStrong(!)Password"
  },
  "Bookmarks": [
    { "alias": "dtemp", "path": "D:\temp" },
    { "alias": "kit",   "path": "C:\Users\youruser\kits" }
  ]
}
```

## Known Issues
Error: Profile cannot be loaded because running scripts is disabled on this system.
Solution:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```
---

## 🧾 Common Commands

| Command                      | Alias(es)                | Description                                        |
|-----------------------------|---------------------------|----------------------------------------------------|
| `borg doctor`                | N/A                      | Checks system environment for required tools, PowerShell version, and config health            |
| `borg store`                | N/A                       | Opens your `store.json` config in Micro            |
| `borg bookmark`             | `b`                       | Jump to bookmark defined in the store.json under the `Bookmarks` chapter via interactive fzf selection.              |
| `borg jump store`           | N/A                       | Bookmark current folder with an alias              |
| `borg jump <alias>`         | `bj <alias>`              | Jump to a previously stored folder                 |
| `borg run`                  | N/A                       | Browse and execute a script from the custom scripts folder using fzf |
| `borg docker restore`       | `bdr`, `borg d r`         | Restore a `.bak` file into Docker SQL              |
| `borg docker snapshot <v>`  | `bds`, `borg d s`         | Create a snapshot from an active container         |
| `borg docker clean`         | `bdc`, `borg d c`         | Remove the SQL container and its volumes           |
| `borg docker switch`        | `bdsw`, `borg d sw`       | Restore one of the saved snapshots                 |
| `borg docker download`      | `bdd`, `borg d d`         | Download a snapshot from container to host         |
| `borg docker upload`        | `bdu`, `borg d u`         | Upload a backup file from host to container        |
| `borg docker query`         | `bdq`, `borg d q`         | Run SQL queries against a selected database        |
| `borg gdrive upload`        | N/A                       | fzf at current location you can choose a file to upload |
| `borg update`               | N/A                       | Update the BORG module from PowerShell Gallery     |
| `borg clean versions`       | N/A                       |  Cleans up older BORG versions, keeping only the latest|
| `borg --version`            | N/A                       | Show installed and latest version                  |
 


---

## 🔄 How It Works

1. Starts SQL Server container (2022 by default)
2. Prompts for `.bak` file and target name
3. Uploads `.bak` to the container
4. Executes an internal `.sh` restore script
5. Maps logical names automatically
6. Done.

---

## 🔒 Compatibility

- ✅ SQL Server 2022
- ✅ PowerShell 7.5.1+ (Windows Powershell is not supported)
- ✅ Docker (Windows, Linux)
- ✅ ODBC Driver 18+ (TLS-safe)

---

## ☁️ Google Drive Integration (via rclone)

To enable file uploads to Google Drive, BORG relies on [rclone](https://rclone.org), a powerful CLI tool for managing cloud storage.

### Setup Steps

1. Download `rclone.exe` from [rclone.org/downloads](https://rclone.org/downloads) and place it in a known location (e.g. `C:\utility-scripts\rclone.exe`).

2. Follow the [rclone Google Drive setup guide](https://rclone.org/drive/) to create a remote configuration and generate your `rclone.conf`.

3. In your `store.json`, specify:
   - The full path to `rclone.exe`
   - The remote name and optional working path (e.g. subfolder)

Example `store.json` snippet:
```json
"Rclone": {
  "ExecutablePath": "C:\\utility-scripts\\rclone.exe",
  "RemoteName": "gdrive",
  "RemotePath": "borg-backups"
}
```

Make sure your `rclone.conf` includes the credentials for the `gdrive` remote, and that you’ve granted it access to the intended Google Drive folder.

Once configured, use:

```powershell
borg gdrive upload
```

to upload files interactively using `fzf` from the current directory.

## 🧹 Uninstalling BORG

If you want to remove the BORG module:

```powershell
Uninstall-Module Borg -AllVersions -Force
```

To remove it manually:

```powershell
Remove-Item "$env:USERPROFILE\Documents\PowerShell\Modules\Borg" -Recurse -Force
```

To clean it from your profile:

```powershell
(Get-Content $PROFILE) | Where-Object { $_ -notmatch 'Import-Module Borg' } | Set-Content $PROFILE
```

---

## 🧭 Roadmap

- [x] Restore any `.bak` file
- [x] Add backup/snapshot support
- [x] Jump to bookmark defined in the store.json under the 'Bookmarks' chapter via interactive fzf selection.
- [x] Jump between stored aliases folders
- [x] Clean docker
- [x] Jump between snapshots inside the container
- [x] Download to host from container
- [x] Upload snapshots to the container's backup folder
- [x] Execute ad-hoc SQL queries directly against the containerized database
- [x] Add shorthand aliases (e.g., `br`, `bdr`, `borg d r`) for faster command access
- [x] Add `borg help` to show available modules and commands
- [x] Open bash shell in the container's backup folder
- [x] Restore database from snapshots already in container
- [x] Add version command and info into borg help
- [x] Add borg update command - for ease of use
- [x] Upload chosen file to gdrive
- [x] Fallback to predefined SQL backup folder when no valid backups are found in the current directory
- [x] Ensure clean restore: On borg docker switch, automatically terminate any existing connections to the target database to prevent restore failures.
- [x] Run user custom scripts
- [x] Choice to remove automatically older versions of BORG;
- [x] Borg doctor (will check for mandatory and optional third-party tools required for operation)
- [x] Restore from bacpac
- [ ] Add `install.ps1` to configure execution policy and profile on first run
---

## 📄 License

MIT — see `LICENSE` for details.