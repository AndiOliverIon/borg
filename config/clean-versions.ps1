# Remove all but the latest installed version of Borg
$all = Get-InstalledModule Borg -AllVersions
$latest = $all | Sort-Object Version -Descending | Select-Object -First 1

$toRemove = $all | Where-Object { $_.Version -ne $latest.Version }

if ($toRemove) {
    $toRemove | ForEach-Object {
        Write-Host "🗑️ Removing version $($_.Version)..." -ForegroundColor Yellow
        Uninstall-Module Borg -RequiredVersion $_.Version -Force
    }
    Write-Host "✅ Cleanup complete. Kept version $($latest.Version)." -ForegroundColor Green
}
else {
    Write-Host "✅ Only the latest version is installed. Nothing to remove." -ForegroundColor Green
}
