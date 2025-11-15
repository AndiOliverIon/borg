param()

. "$env:BORG_ROOT\config\globalfn.ps1"

Write-Host "Stopping Docker container: $ContainerName..." -ForegroundColor Cyan

try {
    docker stop $ContainerName | Out-Null

    Write-Host "Container '$ContainerName' stopped successfully." -ForegroundColor Green
}
catch {
    Write-Host "Failed to stop container '$ContainerName'. Error: $_" -ForegroundColor Red
}
