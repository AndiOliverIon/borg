# 📘 BORG Help — Enriched, grouped, and user-friendly help output
Write-Host "`n  Available BORG modules and commands:`n" -ForegroundColor Cyan

Write-Host "  docker`n" -ForegroundColor Yellow

Write-Host "   • restore (alias: dr)"
Write-Host "     Restores a chosen .bak SQL Server backup file into the Docker SQL container."
Write-Host "     You can rename the database or overwrite an existing one interactively."
Write-Host "     Note: Support for .zip, .bacpac, or MDF+LDF is planned but not yet implemented.`n"

Write-Host "   • query (alias: dq)"
Write-Host "     Executes a custom SQL query inside the active Docker SQL container."
Write-Host "     Useful for quick inspection or manipulation of live data.`n"

Write-Host "   • clean (alias: dc)"
Write-Host "     Cleans up backup files and removes Docker SQL containers."
Write-Host "       WARNING: This removes all running containers, not just sqlserver-2022.`n"

Write-Host "   • download (alias: dl)"
Write-Host "     Downloads a file or folder from the Docker container's backup directory"
Write-Host "     to your local machine, interactively.`n"

Write-Host "   • upload (alias: du)"
Write-Host "     Uploads a .bak SQL Server backup file from your PC to the Docker container’s backup folder."
Write-Host "     Note: Support for .zip, .bacpac, or MDF+LDF is planned but not yet implemented.`n"

Write-Host "   • switch (alias: ds)"
Write-Host "     Switches the active Docker snapshot name used for upcoming restore operations."
Write-Host "     Useful when you maintain multiple named snapshots and want to restore a specific one.`n"

Write-Host "   • snapshot (alias: dsnap)"
Write-Host "     Creates a named snapshot of all user databases inside the Docker container."
Write-Host "     You will be prompted to enter a name. There is no automatic timestamping.`n"

Write-Host "  jump`n" -ForegroundColor Yellow

Write-Host "   • store (alias: js)"
Write-Host "     Jumps to a predefined folder (like a dev or data directory) using a memorable alias."
Write-Host "     Useful for quick terminal navigation.`n"

Write-Host "  network`n" -ForegroundColor Yellow
Write-Host "     gdrive`n"
Write-Host "     Offers choice by fzf to select one file at current location to be uploaded into gdrive.`n"

Write-Host "  jira`n" -ForegroundColor Yellow
Write-Host "     jira today`n"
Write-Host "     Shows your Jira worklogs for today, grouped by issue.`n"
Write-Host "     jira week`n"
Write-Host "     Shows your Jira worklogs for the current week .`n"

Write-Host "  help`n" -ForegroundColor Yellow

Write-Host "   • help"
Write-Host "     Shows this help screen."

$moduleName = 'Borg'
$installed = (Get-Module $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
$latest = (Find-Module $moduleName -ErrorAction SilentlyContinue).Version
Write-Host "BORG v$installed — Installed" -ForegroundColor Green
if ($latest -and $latest -ne $installed) {
    Write-Host "  New version available: v$latest — run 'borg update' to upgrade" -ForegroundColor Yellow
}
else {
    Write-Host "  Up to date with version v$latest" -ForegroundColor Green
}