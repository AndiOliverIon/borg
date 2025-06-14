param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$ContainerName
)

Clear-Host

# ╭────────────────────────────────────────────────────────────╮
# │ 💣 Docker SQL Cleanup — BORG-Managed Containers Only      │
# ╰────────────────────────────────────────────────────────────╯
$separator = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host $separator -ForegroundColor DarkRed
Write-Host "💣  Docker SQL Cleanup — BORG-Managed Containers Only" -ForegroundColor Red
Write-Host $separator -ForegroundColor DarkRed
Write-Host ""

# 🔧 Function: Remove a container gracefully
function Remove-ContainerByName {
    param([string]$Name)

    Write-Host "🗑️ Attempting to remove container: $Name" -ForegroundColor Yellow

    try {
        docker stop $Name | Out-Null
        docker rm $Name | Out-Null
        Write-Host "  Container '$Name' removed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "  Error removing container '$Name': $_" -ForegroundColor Red
    }
}

#   Main logic
if ($ContainerName) {
    Write-Host "🔎 Checking for container: '$ContainerName'" -ForegroundColor Cyan
    $containerExists = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }

    if ($containerExists) {
        Remove-ContainerByName -Name $ContainerName
    }
    else {
        Write-Host "🚫 Container '$ContainerName' not found." -ForegroundColor Red
    }
}
else {
    Write-Host "🧹 No specific container passed. Targeting all **BORG-managed** SQL Server containers..." -ForegroundColor Yellow
    $allBorgSqlContainers = docker ps -a --format "{{.Names}}" | Where-Object { $_ -like "sqlserver-*" }

    if ($allBorgSqlContainers) {
        foreach ($container in $allBorgSqlContainers) {
            Remove-ContainerByName -Name $container
        }
    }
    else {
        Write-Host "  No BORG-managed containers found to remove. Clean slate!" -ForegroundColor Green
    }
}

#   Outro
Write-Host ""
Write-Host "🎯 Cleanup routine complete. System standing by." -ForegroundColor Cyan
Write-Host $separator -ForegroundColor DarkRed