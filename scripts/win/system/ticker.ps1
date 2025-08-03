# ticker.ps1
. "$env:BORG_ROOT\config\globalfn.ps1"

# Enforce single instance of ticker
if (Test-Path $schedulePid) {
    $existingPid = Get-Content $schedulePid -Raw | ForEach-Object { $_.Trim() }

    if ($existingPid -match '^\d+$') {
        $pidValue = [int]$existingPid
        if (Get-Process -Id $pidValue -ErrorAction SilentlyContinue) {
            Write-Host "Ticker already running with PID $pidValue. Exiting."
            exit
        }
    }
}

# Write helper
function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $msg" | Out-File -Append -FilePath $loggerPath -Encoding utf8
}

# Store our PID
try {
    [System.IO.File]::WriteAllText($schedulePid, "$PID", [System.Text.Encoding]::ASCII)
}
catch {
    Log "$($_.Exception.Message)"
}

Log "Ticker started (PID=$PID)"
function IsWithinWindow($item) {
    $now = Get-Date
    $from = [datetime]::ParseExact($item.from, 'HH:mm', $null).Date.AddHours($item.from.Split(':')[0]).AddMinutes($item.from.Split(':')[1])
    $to = [datetime]::ParseExact($item.to, 'HH:mm', $null).Date.AddHours($item.to.Split(':')[0]).AddMinutes($item.to.Split(':')[1])

    $todayFrom = $now.Date.AddHours($from.Hour).AddMinutes($from.Minute)
    $todayTo = $now.Date.AddHours($to.Hour).AddMinutes($to.Minute)

    return ($now -ge $todayFrom -and $now -le $todayTo)
}
function GetTimeSpanFromInterval($interval) {
    if ($interval -match '(\d+)([smhd])') {
        $value = [int]$matches[1]
        switch ($matches[2]) {
            's' { return [timespan]::FromSeconds($value) }
            'm' { return [timespan]::FromMinutes($value) }
            'h' { return [timespan]::FromHours($value) }
            'd' { return [timespan]::FromDays($value) }
        }
    }
    throw "Invalid interval format: $interval"
}
function IsDue($item) {
    try {
        $interval = GetTimeSpanFromInterval $item.interval
        $last = [datetime]::Parse($item.lastexecution)
        $now = Get-Date
        return ($now - $last -ge $interval)
    }
    catch {
        Log "Failed to evaluate interval for $($item.name): $($_.Exception.Message)"
        return $false
    }
}

while ($true) {
    $loopStart = Get-Date
    try {
        $json = Get-Content $storePath -Raw | ConvertFrom-Json
        $scheduleItems = $json.Scheduler | Where-Object { $_.enabled }

        foreach ($item in $scheduleItems) {
            $name = $item.name

            if (-not (IsWithinWindow $item)) {
                Log "Skipped '$name' — outside allowed time window"
                continue
            }

            if (-not (IsDue $item)) {
                Log "Skipped '$name' — not due yet"
                continue
            }

            # Expand and log command
            $command = $ExecutionContext.InvokeCommand.ExpandString($item.action)
            #Log "Running action: $name with command: $command"

            try {
                # Use pwsh with -Wait to avoid runaway process spawns
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "pwsh"
                $psi.Arguments = "-NoLogo -NoProfile -NonInteractive -Command `$ErrorActionPreference='Stop'; $command"
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true

                $proc = [System.Diagnostics.Process]::Start($psi)
                $output = $proc.StandardOutput.ReadToEnd()
                $errorOutput = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()

                Log "Output for $($name):`n$output"
                if ($errorOutput) {
                    Log "Error output for $($name):`n$errorOutput"
                }

                # Update execution time
                $item.lastexecution = (Get-Date).ToString("s")
                foreach ($sched in $json.Scheduler) {
                    if ($sched.name -eq $name) {
                        $sched.lastexecution = $item.lastexecution
                        break
                    }
                }

                $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $storePath
            }
            catch {
                Log "Failed to execute : $($_.Exception.Message)"
            }
        }
    }
    catch {
        Log "Fatal scheduler error: $($_.Exception.Message)"
    }

    $loopEnd = Get-Date
    $elapsed = ($loopEnd - $loopStart).TotalSeconds
    $delay = [Math]::Max(60 - [Math]::Floor($elapsed), 1)
    Start-Sleep -Seconds $delay
}


