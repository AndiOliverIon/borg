param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$ContainerName
)

Clear-Host

# ╭──────────────────────────────────────────────────────────╮
# │ 💣 Docker SQL Container Cleanup — Precision Strike Mode │
# ╰──────────────────────────────────────────────────────────╯
$separator = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
Write-Host $separator -ForegroundColor DarkRed
Write-Host "💣  Docker SQL Container Cleanup — Precision Strike Mode" -ForegroundColor Red
Write-Host $separator -ForegroundColor DarkRed
Write-Host ""

# 🔧 Function: Remove a container gracefully
function Remove-ContainerByName {
    param([string]$Name)

    Write-Host "🗑️ Attempting to remove container: $Name" -ForegroundColor Yellow

    try {
        docker stop $Name | Out-Null
        docker rm $Name | Out-Null
        Write-Host "✅ Container '$Name' removed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error removing container '$Name': $_" -ForegroundColor Red
    }
}

# 🧠 Normalize SQL shorthand names
if ($ContainerName -in @('2017', '2019', '2022')) {
    Write-Host "🔄 Interpreting version shortcut → sqlserver-$ContainerName"
    $ContainerName = "sqlserver-$ContainerName"
}

# 🔍 Main logic
if ($ContainerName) {
    Write-Host "🔎 Checking for container: '$ContainerName'" -ForegroundColor Cyan
    $containerExists = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}"

    if ($containerExists -eq $ContainerName) {
        Remove-ContainerByName -Name $ContainerName
    }
    else {
        Write-Host "🚫 Container '$ContainerName' not found." -ForegroundColor Red
    }
}
else {
    Write-Host "🧹 No specific container passed. Targeting **all** containers..." -ForegroundColor Yellow
    $allContainers = docker ps -a --format "{{.Names}}"

    if ($allContainers) {
        foreach ($container in $allContainers) {
            Remove-ContainerByName -Name $container
        }
    }
    else {
        Write-Host "✅ No containers found to remove. Clean slate!" -ForegroundColor Green
    }
}

# 🏁 Outro
Write-Host ""
Write-Host "🎯 Cleanup routine complete. System standing by." -ForegroundColor Cyan
Write-Host $separator -ForegroundColor DarkRed
