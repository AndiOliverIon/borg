# ticker.ps1
. "$env:BORG_ROOT\config\globalfn.ps1"

# Constants
$timeFolder = Join-Path $env:APPDATA "Borg\ticker"

# Ensure ticker folder exists
New-Item -ItemType Directory -Force -Path $timeFolder | Out-Null

# Rest of constants
$logFile = Join-Path $timeFolder "ticker.log"
$logArchive = Join-Path $timeFolder "ticker.archive.log"
$logLimitBytes = 1MB
$schedulePid = Join-Path $timeFolder 'schedule.pid'
$loopStart = Get-Date

# Logging
function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $msg" | Out-File -Append -FilePath $logFile -Encoding utf8
    RotateLogIfNecessary
}

# Output info for debug
Write-Host("Time folder: $($timeFolder)");
Write-Host("Log file: $($logFile)");
Write-Host("Log archive file: $($logArchive)");

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

# Store our PID
try {
    [System.IO.File]::WriteAllText($schedulePid, "$PID", [System.Text.Encoding]::ASCII)
}
catch {
    Log "$($_.Exception.Message)"
}

# Define the last time of the execution
$existingTimeFile = Get-ChildItem -Path $timeFolder -Filter '*.time' | Sort-Object Name | Select-Object -Last 1
if ($existingTimeFile) {
    $lastExecution = [datetime]::ParseExact($existingTimeFile.BaseName, 'yyyyMMddHHmmss', $null)
    Remove-Item -Force $existingTimeFile.FullName -ErrorAction SilentlyContinue
}
else {
    $lastExecution = [datetime]::MinValue
}

# Cleanup only on process exit (e.g., Ctrl+C)
Register-EngineEvent PowerShell.Exiting -Action {
    Remove-Item -Force $schedulePid -ErrorAction SilentlyContinue
} | Out-Null

function RotateLogIfNecessary {
    if (Test-Path $logFile) {
        $logSize = (Get-Item $logFile).Length
        if ($logSize -gt $logLimitBytes) {
            Remove-Item -Force $logArchive -ErrorAction SilentlyContinue
            Move-Item -Force $logFile $logArchive
        }
    }
}
function ParseInterval($text) {
    if ($text -match '^(\d+)([smhd])$') {
        $v = [int]$matches[1]
        switch ($matches[2]) {
            's' { return [timespan]::FromSeconds($v) }
            'm' { return [timespan]::FromMinutes($v) }
            'h' { return [timespan]::FromHours($v) }
            'd' { return [timespan]::FromDays($v) }
        }
    }
    throw "Invalid interval: $text"
}

# Log "Bulshit"
# Read-Host "DEBUG: Press Enter to continue, or Ctrl+C to exit"
# Main loop
while ($true) {
    $loopStart = Get-Date
    try {
        $json = Get-Content $storePath -Raw | ConvertFrom-Json
        $scheduleItems = $json.Scheduler | Where-Object { $_.enabled }
        foreach ($item in $scheduleItems) {
            $name = $item.name            
            $now = Get-Date
            
            # Time window
            $from = $now.Date.Add([timespan]::Parse($item.from))
            $to = $now.Date.Add([timespan]::Parse($item.to))

            Write-Host("now: $now")
            Write-Host("from: $from")
            Write-Host("to: $to")
            if ($now -lt $from -or $now -gt $to) {
                Log "Skipped $name, outside of time window."
                continue
            }
            
            # Due?
            try {
                $interval = ParseInterval $item.interval
                if (($now - $lastExecution) -lt $interval) {
                    Log "Skipped not due"
                    continue
                }
                
            }
            catch {
                Log "Interval error for $($name): $($_.Exception.Message)"
                continue
            }
            
            # Read-Host "DEBUG: Press Enter to continue, or Ctrl+C to exit"
            # Run action
            $command = $ExecutionContext.InvokeCommand.ExpandString($item.action)
            Log "Running '$name': $command"
            try {
                $psi = [System.Diagnostics.ProcessStartInfo]::new()
                $psi.FileName = "pwsh"
    
                # Detect if it's a script execution (starts with pwsh -File ...)
                if ($command -match '^-File\s+"?(.+?\.ps1)"?\s*(.*)') {
                    $scriptPath = $matches[1]
                    $scriptArgs = $matches[2]

                    $psi.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" $scriptArgs"
                }
                else {
                    # Treat as raw command
                    $psi.Arguments = "-NoLogo -NoProfile -NonInteractive -Command `"& { $command }`""
                }

                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true

                $proc = [System.Diagnostics.Process]::Start($psi)
                $out = $proc.StandardOutput.ReadToEnd()
                $err = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()

                Log "Output for '$name':`n$out"
                if ($err) { Log "Error for '$name':`n$err" }

                $lastExecution = Get-Date
            }
            catch {
                Log "Execution failed for '$name': $($_.Exception.Message)"
            }
        }
    }
    catch {
        Log "Fatal scheduler error: $($_.Exception.Message)"
    }

    $loopEnd = Get-Date
    $elapsed = ($loopEnd - $loopStart).TotalSeconds
    $delay = [Math]::Max(60 - [Math]::Floor($elapsed), 1)

    # Rotate .time file
    Get-ChildItem -Path $timeFolder -Filter '*.time' | Remove-Item -Force -ErrorAction SilentlyContinue
    $timestamp = (Get-Date).ToString('yyyyMMddHHmmss')
    New-Item -ItemType File -Path (Join-Path $timeFolder "$timestamp.time") | Out-Null

    Start-Sleep -Seconds $delay
    #Start-Sleep -Seconds 5
}

