param()

. "$env:BORG_ROOT\config\globalfn.ps1"

Write-Host "Starting Docker container: $ContainerName..." -ForegroundColor Cyan

try {
    docker start $ContainerName | Out-Null

    Write-Host "Container '$ContainerName' started successfully." -ForegroundColor Green
}
catch {
    Write-Host "Failed to start container '$ContainerName'. Error: $_" -ForegroundColor Red
}
