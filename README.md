# 🧠 BORG — Bash Orchestrator for Reliable GitOps

BORG is a modular automation shell designed to manage SQL Server Docker containers and automate backup/restore workflows using robust scripting practices.

---

## 🚀 Features

- 🔄 **Restore any `.bak` file** to any database name
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

## 🧪 Getting Started

> Windows PowerShell, Docker Desktop, and Git are required.

```bash
# Clone the repo
git clone https://github.com/your-org/borg.git

# Setup environment
$env:BORG_ROOT = "C:\path\to\borg"

# Run the restore utility
.\scripts\win\docker\restore.ps1
```

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
  - SQL Server 2017–2022
  - PowerShell 5.1+
  - Docker (Windows, Linux)
  - ODBC Driver 18+ (auto handled)

---

## 🧭 Roadmap

- [x] Restore any `.bak` file reliably
- [ ] Add backup support
- [ ] Add compare/diff tools
- [ ] Borg AI integration via local LLM

---

## 📄 License

MIT — see `LICENSE` for details.
