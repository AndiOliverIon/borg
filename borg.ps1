# borg.ps1
# Entrypoint for Borg CLI
param (
    [string]$module,
    [string]$command,
    [string[]]$extraArgs
)

. "$env:BORG_ROOT\config\globalfn.ps1"

# Assure files
if (-not (Test-Path $storePath)) {
    New-Item -ItemType File -Path $storePath -Force | Out-Null
    '{}' | Set-Content $storePath -Encoding UTF8
}

# No args = show help
if (-not $module) {
    Write-Host "Usage: borg <module> <command> [...args]"
    Write-Host "Built-in modules: store"
    exit 0
}

switch ($module) {
    'store' {
        micro $storePath
    }
    'docker' {        
        switch ($command) {
            'clean' { & "$dockerFolder\clean.ps1" }
            'restore' { & "$dockerFolder\restore.ps1" }
        }        
    }
    default {
        Write-Error "Unknown module command."
    }
}

