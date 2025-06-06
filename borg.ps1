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
    'jump' {
        switch ($command) {
            'store' { & "$jumpFolder\store.ps1" @extraArgs }
            default {
                if (-not (Test-Path $storePath)) {
                    Write-Host "❌ Config not found at $storePath"
                    return
                }

                $config = Get-Content $storePath -Raw | ConvertFrom-Json
                $match = $config.Bookmarks | Where-Object { $_.alias -eq $command }

                if (-not $match) {
                    Write-Host "❌ Bookmark alias '$command' not found."
                    return
                }

                $targetPath = $match.path
                if (-not (Test-Path $targetPath)) {
                    Write-Host "⚠️ Bookmark path '$targetPath' does not exist."
                    return
                }

                Set-Location $targetPath
                Write-Host "📂 Jumped to '$command': $targetPath"
            }
        }

    }

    'docker' {        
        switch ($command) {
            'clean' { & "$dockerFolder\clean.ps1" }
            'restore' { & "$dockerFolder\restore.ps1" }
            'snapshot' { & "$dockerFolder\snapshot.ps1" @extraArgs }
        }        
    }
    default {
        Write-Error "Unknown module command."
    }
}

