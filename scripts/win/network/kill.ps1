# 📂 BORG Network — kill.ps1
param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

function Stop-ProcessById {
    param([int[]]$PIDs)

    foreach ($processId in $PIDs) {
        try {
            taskkill /PID $processId /F | Out-Null
            Write-Host "✅ Killed PID ${processId}" -ForegroundColor Green
        }
        catch {
            Write-Warning "⚠️ Could not kill PID ${processId}: $_"
        }
    }
}

if (-not $inputArgs -or $inputArgs.Count -lt 1) {
    Write-Host "Usage: borg network kill <port|processName> [--c]" -ForegroundColor Yellow
    exit 1
}

$target = $inputArgs[0]
$confirm = $inputArgs -contains '-c' -or $inputArgs -contains '--c'
$isPort = $null -ne ($target -as [int])

if ($isPort) {
    $netstatLines = netstat -aon | ForEach-Object { $_.TrimStart() } | Where-Object { $_ -match '^(TCP|UDP)' }

    $pids = @()
    $pattern = '^(?<Proto>\S+)\s+(?<Local>\S+)\s+(?<Remote>\S+)\s+(?<State>\S+)\s+(?<PID>\d+)$'

    foreach ($line in $netstatLines) {
        if ($line -match $pattern) {
            $localAddress = $Matches['Local']
            $netPid = $Matches['PID']
            $portPart = ($localAddress -split ':')[-1] -replace '\D', ''

            if ($portPart -eq "$target") {
                $pids += $netPid
            }
        }
    }

    $pids = $pids | Sort-Object -Unique
    Write-Host "[debug] Final matched PIDs: $($pids -join ', ')" -ForegroundColor DarkGray

    if (-not $pids -or $pids.Count -eq 0) {
        Write-Host "❌ No active connections found on port ${target}" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "🔍 Found PIDs using port ${target}:" -ForegroundColor Cyan
    foreach ($procId in $pids) {
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "• PID: ${procId} → $($proc.ProcessName)" -ForegroundColor DarkGray
        }
        else {
            Write-Host "• PID: ${procId} → <not found>" -ForegroundColor DarkGray
        }
    }

    if ($confirm) {
        $pids = $pids | ForEach-Object {
            $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
            if ($proc) { "PID: $_  →  $($proc.ProcessName)" } else { "PID: $_  →  <not found>" }
        } | fzf --multi --ansi | ForEach-Object {
            ($_ -split '\s+')[1]
        }
    }

    if ($pids) {
        Stop-ProcessById -PIDs $pids
    }
    else {
        Write-Host "❌ No PID selected. Aborting." -ForegroundColor Red
    }
}
else {
    Write-Host "[debug] Target is string, treating as process name" -ForegroundColor DarkGray
    $foundProcs = Get-Process | Where-Object { $_.Name -like "*${target}*" }
    if (-not $foundProcs) {
        Write-Host "❌ No processes found matching '${target}'" -ForegroundColor Red
        exit 1
    }

    Write-Host "🔍 Found processes matching '${target}':" -ForegroundColor Cyan
    foreach ($proc in $foundProcs) {
        Write-Host "• PID: $($proc.Id) → $($proc.Name)" -ForegroundColor DarkGray
    }

    if ($confirm) {
        $pids = $foundProcs | ForEach-Object {
            "PID: $($_.Id)  →  $($_.Name)"
        } | fzf --multi --ansi | ForEach-Object {
        ($_ -split '\s+')[1]
        }

        if (-not $pids) {
            Write-Host "❌ No PID selected. Aborting." -ForegroundColor Red
            exit 1
        }
    }
    else {
        $pids = $foundProcs.Id
    }

    Stop-ProcessById -PIDs $pids
}