# 📁 Jump to Bookmark Script

# Load the store
$storePath = Join-Path $env:BORG_ROOT "data\store.json"
if (-not (Test-Path $storePath)) {
    Write-Error "❌ store.json not found at $storePath"
    exit 1
}

# Parse JSON
$json = Get-Content $storePath -Raw | ConvertFrom-Json
$bookmarks = $json.Bookmarks

if (-not $bookmarks -or $bookmarks.Count -eq 0) {
    Write-Error "❌ No bookmarks found in store.json"
    exit 1
}

# Build display list for fzf: "alias : path"
$displayList = $bookmarks | ForEach-Object {
    "{0,-10} : {1}" -f $_.alias, $_.path
}

# Let user pick
$selection = $displayList | fzf --prompt "📌 Choose a bookmark: " --height 40% --border
if (-not $selection) {
    Write-Host "❌ No selection. Aborting."
    exit 1
}

# Extract path from selection
$parts = $selection -split ' : '
if ($parts.Count -lt 2) {
    Write-Error "❌ Could not parse selected line: $selection"
    exit 1
}

$selectedPath = $parts[1].Trim()

# Jump
if (Test-Path $selectedPath) {
    Set-Location $selectedPath
    Write-Host "`n📂 Jumped to: $selectedPath" -ForegroundColor Green
}
else {
    Write-Error "❌ Path not found: $selectedPath"
}
