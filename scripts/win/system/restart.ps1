# restart.ps1 — gracefully close known apps, then restart

$appsToClose = @(
    "code", # VS Code
    "notepad", # Notepad
    "micro", # Micro terminal editor
    "sqlserver", # SQL Server Management Studio (if used)
    "docker", # Docker Desktop
    "chrome", # Browsers if needed
    "powershell", # Open PowerShell terminals
    "pwsh", # PowerShell Core
    "cmd"           # Old terminal windows
)

Write-Host "🔁 Attempting graceful shutdown of common applications..." -ForegroundColor Yellow

foreach ($app in $appsToClose) {
    Get-Process -Name $app -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "→ Closing $($_.ProcessName) (PID: $($_.Id))"
        $_.CloseMainWindow() | Out-Null
        Start-Sleep -Milliseconds 300
    }
}

Write-Host "⌛ Waiting 5 seconds before forced restart..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Restart-Computer -Force
