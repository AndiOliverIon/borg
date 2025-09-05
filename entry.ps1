# entry.ps1 — Safe launcher, compatible with Windows PowerShell 5.1

param(
    [string]  $module,
    [string]  $command,
    [string[]]$extraArgs
)

if (-not $env:BORG_ROOT) {
    $env:BORG_ROOT = 'C:\borg'
}

if (-not $env:APPDATA -or -not (Test-Path $env:APPDATA)) {
    $env:APPDATA = "C:\Users\$env:USERNAME\AppData\Roaming"
}

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
    'agent' {
        pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass `
            -File "$scriptsRoot\agent\bagent.ps1" $command
    }
    'bookmark' {
        & "$env:BORG_ROOT\bookmark.ps1"
    }
    'clean' {
        switch ($command) {
            'versions' { & "$configRoot\clean-versions.ps1" }
        }
    }
    'doctor' {
        & "$configRoot\doctor.ps1"
    }
    'docker' {        
        switch ($command) {
            'bash' { & "$dockerFolder\bash.ps1" }
            'clean' { & "$dockerFolder\clean.ps1" }
            'restore' { & "$dockerFolder\restore.ps1" }
            'snapshot' { & "$dockerFolder\snapshot.ps1" @extraArgs }
            'switch' { & "$dockerFolder\switch.ps1" }
            'download' { & "$dockerFolder\download.ps1" }
            'upload' { & "$dockerFolder\upload.ps1" }
            'query' { & "$dockerFolder\query.ps1" }
        }        
    }
    'gdrive' {
        switch ($command) {
            'upload' { & "$networkRoot\gdrive-upload.ps1" }
        }
    }
    'git' {
        switch ($command) {
            'status' { & "$gitFolder\status.ps1" }
            'log' { & "$gitFolder\log.ps1" @extraArgs }
        }
    }
    'help' {
        & "$env:BORG_ROOT\help.ps1"
    }
    'idea' {
        & "$sysFolder\idea.ps1" $command
    }
    'io' {
        switch ($command) {
            'folder-clean' { & "$ioFolder\folder-clean.ps1" $extraArgs }
        }
    }
    'jira' {
        switch ($command) {
            'today' { & "$jiraRoot\workflow-today.ps1" $extraArgs }
            'latest' { & "$jiraRoot\latest.ps1" $extraArgs }
            'week' { & "$jiraRoot\workflow-week.ps1" $extraArgs }
        }
    }
    'jump' {
        switch ($command) {
            'store' { & "$jumpFolder\store.ps1" @extraArgs }
            default {
                if (-not (Test-Path $storePath)) {
                    Write-Host "  Config not found at $storePath"
                    return
                }

                $config = Get-Content $storePath -Raw | ConvertFrom-Json
                $match = $config.Bookmarks | Where-Object { $_.alias -eq $command }

                if (-not $match) {
                    Write-Host "  Bookmark alias '$command' not found."
                    return
                }

                $targetPath = $match.path
                if (-not (Test-Path $targetPath)) {
                    Write-Host "  Bookmark path '$targetPath' does not exist."
                    return
                }

                Set-Location $targetPath
                Write-Host "  Jumped to '$command': $targetPath"
            }
        }
    }
    'network' {
        switch ($command) {
            'kill' { & "$networkRoot\kill.ps1" $extraArgs }
            'bacpac' { & "$networkRoot\database\export-bacpac.ps1" }
            'wifi' { & "$networkRoot\wifi.ps1" $extraArgs }
        }
    }
    'note' {
        if (-not $command) {
            Write-Host "Usage: borg note <add|search|show|edit|rm> [...args]"
            return
        }

        $arg1 = $null
        $arg2 = $null
        if ($extraArgs.Count -ge 1) { $arg1 = $extraArgs[0] }  # title, or query/id
        if ($extraArgs.Count -ge 2) { $arg2 = $extraArgs[1] }  # description (for add)

        & "$sysFolder\note.ps1" -Action $command -Arg1 $arg1 -Arg2 $arg2
    }
    'q' {
        & "$env:BORG_ROOT\q.ps1"
    }
    'process' {
        switch ($command) {
            'get' { & "$sysFolder\process-get.ps1" $extraArgs }
            'kill' { & "$sysFolder\process-kill.ps1" $extraArgs }
        }        
    }
    'run' {
        & "$env:BORG_ROOT\run.ps1" $command
    }
    'store' {
        micro $storePath
    }
    'sys' {
        switch ($command) {
            'shutdown' { & "$sysFolder\shutdown.ps1" $extraArgs }
            'restart' { & "$sysFolder\restart.ps1" $extraArgs }
        }
    }
    'web' {
        if (-not $command) {
            & "$jumpFolder\web.ps1" -Action 'help'
            return
        }

        $alias = $null
        $url = $null
        if ($extraArgs.Count -ge 1) { $alias = $extraArgs[0] }
        if ($extraArgs.Count -ge 2) { $url = $extraArgs[1] }

        & "$jumpFolder\web.ps1" -Action $command -Alias $alias -Url $url
    }
    default {
        Write-Host ""
        Write-Host "Unknown module or command: '$module $command'" -ForegroundColor Red
        Write-Host "Run 'borg help' for usage info."
        exit 1
    }
}