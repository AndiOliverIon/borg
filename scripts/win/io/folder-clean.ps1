. "$env:BORG_ROOT\config\globalfn.ps1"

Write-Host ""
Write-Host "🧹 Cleaning folders from CleanFolders chapter..." -ForegroundColor Cyan
Write-Host ""

$store = Get-Content $storePath | ConvertFrom-Json
$foldersToClean = $store.CleanFolders

foreach ($folder in $foldersToClean) {
    $alias = $folder.alias
    $path = $folder.path

    if (-not (Test-Path $path)) {
        Write-Warning "⚠️  Skipping '$alias' — path not found: $path"
        continue
    }

    $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
    $itemCount = $items.Count

    foreach ($item in $items) {
        try {
            if ($item.PSIsContainer) {
                Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop
            }
            else {
                Remove-Item $item.FullName -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Warning "❌ Could not delete: $($item.FullName) — $_"
        }
    }

    Write-Host "✅ Cleaned '$alias' → $path ($itemCount items removed)" -ForegroundColor Green
}
