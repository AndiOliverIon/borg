# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 📌 Store current folder as a bookmark
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$currentFolder = Get-Location
$defaultAlias = Split-Path $currentFolder -Leaf

$alias = Read-Host "📛 Enter alias for bookmark [$defaultAlias]"
if (-not $alias) { $alias = $defaultAlias }

$config = Get-Content $storePath -Raw | ConvertFrom-Json

# Check if alias already exists
if ($config.Bookmarks | Where-Object { $_.alias -eq $alias }) {
    Write-Host "  Alias '$alias' already exists. Aborting."
    return
}

# Add the new bookmark
$config.Bookmarks += [pscustomobject]@{
    alias = $alias
    path  = $currentFolder.Path
}

# Save changes
$config | ConvertTo-Json -Depth 3 | Set-Content $storePath -Encoding UTF8
Write-Host "  Bookmark '$alias' → '$($currentFolder.Path)' added."
