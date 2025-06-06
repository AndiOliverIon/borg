
# 🧠 BORG — Bash Orchestrator for Reliable GitOps

BORG is a modular automation shell designed to manage SQL Server Docker containers and automate backup/restore workflows using robust scripting practices.

---

## 🚀 Features

- 🔄 **Restore a `.bak` file with new proposal name or default of the file.
- 📦 **Docker SQL Server orchestration** with automatic upload & provisioning
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

| Tool   | Purpose                          | Install Command                |
|--------|----------------------------------|--------------------------------|
| `fzf`  | Fuzzy finder for file selection  | `winget install fzf`           |
| `micro`| Terminal-based text editor       | `winget install micro`         |

You can install both with:

```powershell
winget install fzf
winget install micro
```

These tools are used for interactive prompts and editing operations. If not installed, Borg scripts may fall back to simpler prompts or raise an error.

---

## 🧪 Getting Started

> Windows PowerShell, and Docker Desktop are required.

```bash
# Optional, clone the repo
git clone https://github.com/your-org/borg.git
```
> In terminal profile inject at the end the following:
```bash
# Setup environment
# >>> BORG INITIALIZATION START <<<
Import-Module Borg
# <<< BORG INITIALIZATION END >>>
```
> Establish a configuration file instructing how should work with docker
{
    "General": {
        "HostBackupFolder": "SomePathOnHostWhereBackupsAreKept"
    },
    "Docker": {
        "SqlContainer": "sqlserver-2022",
        "SqlInstance": "localhost,2022",
        "SqlImageTag": "mcr.microsoft.com/mssql/server:2022-latest",
        "SqlPort": 1433,
        "SqlUser": "sa",
        "SqlPassword": "SomePwd"
    }
}
---

## 🛠️ How It Works

1. Starts SQL Server container (2022 by default)
2. Prompts for `.bak` file and target name
3. Uploads `.bak` to the container
4. Executes an **internal `.sh` restore script**
   - Dynamically builds `RESTORE DATABASE ... WITH MOVE`
   - Handles all logical name mapping
5. Done.

---

## 🔒 Compatibility

- Works with:
  - SQL Server 2022
  - PowerShell 5.1+
  - Docker (Windows, Linux)
  - ODBC Driver 18+ (auto handled)

---

## 🧭 Roadmap

- [x] Restore any `.bak` file
- [x] Add backup/snapshot support
- [x] Jump between stored aliases folders
- [ ] Jump between snapshots on container
- [ ] Clean docker
---

## Usage
> Configure credentials for borg
```bash
borg store
```
> To create a docker container with provided bak file. Navigate where the bak file is with terminal then:
```bash
borg docker restore
```
> To create a snapshot of a chosen database existing in container, optionally with a suffix (v1 in example)
```bash
borg docker snapshot v1
```

## 📄 License

MIT — see `LICENSE` for details.
