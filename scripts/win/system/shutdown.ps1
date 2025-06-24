# shutdown-station.ps1

Write-Host "📦 Preparing to shut down the station gracefully..."

# List of applications to close (based on your usage)
$appsToClose = @(
    "ssms", # SQL Server Management Studio
    "devenv", # Visual Studio
    "code", # Visual Studio Code
    "notepad++", # Notepad++
    "notepad", # Windows Notepad
    "explorer", # Windows File Explorer
    "chrome", # Chrome browser (optional)
    "steam", # Steam (optional)
    "vlc", # VLC media player (optional)
    "excel", # Excel (optional)
    "word"          # Word (optional)
)

foreach ($app in $appsToClose) {
    $procs = Get-Process -Name $app -ErrorAction SilentlyContinue
    foreach ($proc in $procs) {
        Write-Host "Stopping $($proc.ProcessName)..."
        $proc.CloseMainWindow() | Out-Null
        Start-Sleep -Milliseconds 300
    }
}

# Optional: Give apps a few seconds to close
Start-Sleep -Seconds 5

# Shutdown the machine
Write-Host "⚠️ Initiating system shutdown..."
Stop-Computer -Force
