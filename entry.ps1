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
    'doctor' {
        & "$configRoot\doctor.ps1"
    }
    'help' {
        & "$env:BORG_ROOT\help.ps1"
    }
    'store' {
        micro $storePath
    }
    'bookmark' {
        & "$env:BORG_ROOT\bookmark.ps1"
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
    'run' {
        & "$env:BORG_ROOT\run.ps1"
    }

    'gdrive' {
        switch ($command) {
            'upload' { & "$networkRoot\gdrive-upload.ps1" }
        }

    }
    'clean' {
        switch ($command) {
            'versions' { & "$configRoot\clean-versions.ps1" }
        }
    }
    'network' {
        switch ($command) {
            'kill' { & "$networkRoot\kill.ps1" $extraArgs }
            'bacpac' { & "$networkRoot\database\export-bacpac.ps1" }
            'wifi' { & "$networkRoot\wifi.ps1" $extraArgs }
        }
    }
    'jira' {
        switch ($command) {
            'today' { & "$jiraRoot\workflow-today.ps1" $extraArgs }
            'latest' { & "$jiraRoot\latest.ps1" $extraArgs }
            'week' { & "$jiraRoot\workflow-week.ps1" $extraArgs }
        }
    }
    'io' {
        switch ($command) {
            'folder-clean' { & "$ioFolder\folder-clean.ps1" $extraArgs }
        }
    }
    'sys' {
        switch ($command) {
            'shutdown' { & "$sysFolder\shutdown.ps1" $extraArgs }
            'restart' { & "$sysFolder\restart.ps1" $extraArgs }
        }
    }
    'q' {
        & "$env:BORG_ROOT\q.ps1"
    }
    default {
        Write-Error "Unknown module command."
    }
}

