# 🧠 BORG — Backup Orchestrator for Reliable Groundwork

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
| `micro` | Terminal-based text editor       | `winget install micro`   |

These tools are used for interactive prompts and editing operations. If not installed, Borg scripts may fall back to simpler prompts or raise an error.

---

## 🧪 Getting Started

> Windows PowerShell and Docker Desktop are required.

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
# <<< BORG INITIALIZATION END >>>
```

### Initialize Configuration
Upon first run, a default `store.json` will be created from `store.example.json` if it does not exist.

Edit it with:
```powershell
# >>> USING BORG/Micro <<<
borg store
# >>> USING MICRO <<<
$env:BORG_ROOT = (Get-Location).Path
micro $env:BORG_ROOT\data\store.json
```

Example configuration:
```json
{
  "General": {
    "HostBackupFolder": "C:\backups"
  },
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
Solution: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

---

## 🧾 Common Commands

| Command                      | Description                                  |
|-----------------------------|----------------------------------------------|
| `borg store`                | Edit or review your configuration            |
| `borg jump store`           | Bookmark current folder with an alias        |
| `borg jump <alias>`         | Jump to a previously stored folder           |
| `borg docker restore`       | Restore a `.bak` file into Docker SQL        |
| `borg docker snapshot <v>`  | Create a snapshot from an active container   |
| `borg docker clean`         | Remove the SQL container and its volumes     |

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
- ✅ PowerShell 5.1+
- ✅ Docker (Windows, Linux)
- ✅ ODBC Driver 18+ (TLS-safe)

---

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
- [x] Jump between stored aliases folders
- [x] Clean docker
- [x] Jump between snapshots inside the container
- [ ] Download to host from container
- [ ] Upload snapshots to the container's backup folder
- [ ] Add `install.ps1` to configure execution policy and profile on first run
- [ ] Add shorthand aliases (e.g., `br`, `bdr`, `borg d r`) for faster command access (TBD)
- [ ] Add `borg help` to show available modules and commands
- [ ] Restore database from snapshots already in container
- [ ] Open bash shell in the container's backup folder
- [ ] Add `borg logs` to monitor last executions
- [ ] Restore from bacpac
- [ ] Integrate Google Drive as shared cloud storage between stations
- [ ] Schedule automatic shutdown of the working station
- [ ] Start Visual Studio with sln found at the current location
- [ ] Execute ad-hoc SQL queries directly against the containerized database
- [ ] Start/stop system or application services from the terminal
- [ ] Add version display and optional update hint on startup
- [ ] Add `borg reset` to regenerate store.json from example
- [ ] Add interactive `borg menu` powered by fzf
---

## 📄 License

MIT — see `LICENSE` for details.