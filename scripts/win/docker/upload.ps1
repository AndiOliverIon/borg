# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   File Upload to Docker Container — Interactive 🎯
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$dockerSqlPath = "/var/opt/mssql"
$backupPath = "$dockerSqlPath/backup"

#   Scan for folders/files to upload
Write-Host "`n  Scanning current folder for upload candidates..." -ForegroundColor Yellow

# First gather uploadable files only
$uploadableExtensions = ".bak", ".zip", ".mdf", ".ldf", ".bacpac"
$fileItems = Get-ChildItem -File | Where-Object { $_.Extension -in $uploadableExtensions }

# If none found, fallback to default
if (-not $fileItems -or $fileItems.Count -eq 0) {
    Write-Host "  No uploadable files found in current folder. Trying fallback: $SqlBackupDefaultFolder" -ForegroundColor Yellow
    Push-Location $SqlBackupDefaultFolder

    $fileItems = Get-ChildItem -File | Where-Object { $_.Extension -in $uploadableExtensions }

    if (-not $fileItems -or $fileItems.Count -eq 0) {
        Write-Host "  No suitable files found in any location. Aborting." -ForegroundColor Red
        Pop-Location
        exit 1
    }

    $items = @(Get-ChildItem -Directory) + $fileItems
    Write-Host "  Using fallback folder contents." -ForegroundColor Green

    # Build mapping
    $cleanToPath = @{}
    $displayList = @()

    foreach ($item in $items) {
        $name = $item.Name
        $icon = if ($item.PSIsContainer) { " " }
        elseif ($item.Extension -eq ".zip") { " " }
        else { " " }

        $display = "$icon $name"
        $displayList += $display
        $cleanToPath[$name] = $item.FullName
    }

    Pop-Location
}
else {
    # If we have files in current folder, combine with directories here
    $items = @(Get-ChildItem -Directory) + $fileItems

    $cleanToPath = @{}
    $displayList = @()

    foreach ($item in $items) {
        $name = $item.Name
        $icon = if ($item.PSIsContainer) { " " }
        elseif ($item.Extension -eq ".zip") { " " }
        else { " " }

        $display = "$icon $name"
        $displayList += $display
        $cleanToPath[$name] = $item.FullName
    }
}


if (-not $items) {
    Write-Host "  No suitable folders or files found in current directory." -ForegroundColor Red
    exit 1
}

# 🎯 Build map: cleanName → fullPath
$cleanToPath = @{ }
$displayList = @()

foreach ($item in $items) {
    $name = $item.Name
    $icon = if ($item.PSIsContainer) { " " }
    elseif ($item.Extension -eq ".zip") { " " }
    else { " " }

    $display = "$icon $name"
    $displayList += $display
    $cleanToPath[$name] = $item.FullName
}

#   fzf shows pretty Display
$selectedDisplay = $displayList | fzf --ansi --prompt "  Select a file/folder to upload: " --height 40% --reverse | ForEach-Object { $_.Trim() }

if (-not $selectedDisplay) {
    Write-Host "  No selection made. Aborting." -ForegroundColor Red
    exit 1
}

# 🧼 Strip emoji to get clean name
$cleanName = $selectedDisplay -replace '^[^\s]+\s+', ''

if (-not $cleanToPath.ContainsKey($cleanName)) {
    Write-Host "  Could not find the selected item. Aborting." -ForegroundColor Red
    exit 1
}

$FilePath = $cleanToPath[$cleanName]
$OriginalFileName = [System.IO.Path]::GetFileName($FilePath)

# Determine file type, if bacpac return from upload, this will suffice here.
$ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
$isBacPac = 0;
$proposedExtension = ".bak"
if ($ext -eq ".bacpac") {
    $isBacPac = 1;
    $proposedExtension = ".bacpac"
}


#   Auto-propose based on filename (first word before `_` or `-`)
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($OriginalFileName)
$proposedName = ($baseName -split '[-_]')[0] + $proposedExtension

# 🎯 Rename choices (emoji + label) → key map
$renameLabelToKey = @{}
$renameLabels = @()

$renameLabels += "📛 Use proposed: $proposedName"
$renameLabelToKey["Use proposed: $proposedName"] = "proposed"

$renameLabels += "  Keep original: $OriginalFileName"
$renameLabelToKey["Keep original: $OriginalFileName"] = "original"

$renameLabels += "✏️ Propose new name..."
$renameLabelToKey["Propose new name..."] = "custom"

#   fzf for rename decision
$renameOptions = $renameLabels | ForEach-Object {
    $label = $_
    $emoji = $label.Substring(0, 2).Trim()
    $text = $label.Substring(2).Trim()
    "$emoji $text"
}

$selectedRename = $renameOptions | fzf --ansi --prompt "✏️ Rename before upload? " --height 10 --reverse | ForEach-Object { $_.Trim() }

if (-not $selectedRename) {
    Write-Host "  Rename option not selected. Aborting." -ForegroundColor Red
    exit 1
}

# 🧼 Clean selected label (remove emoji and spaces)
$cleanRenameKey = $selectedRename -replace '^[^\s]+\s+', ''

if (-not $renameLabelToKey.ContainsKey($cleanRenameKey)) {
    Write-Host "  Unknown rename option. Aborting." -ForegroundColor Red
    exit 1
}

switch ($renameLabelToKey[$cleanRenameKey]) {
    "proposed" {
        $FileName = $proposedName
    }
    "original" {
        $FileName = $OriginalFileName
    }
    "custom" {
        $inputPrompt = "  Enter new name to use inside container [`default: $OriginalFileName`]"
        $entered = Read-Host -Prompt $inputPrompt
        $FileName = if ([string]::IsNullOrWhiteSpace($entered)) { $OriginalFileName } else { $entered }
    }
}

$TargetFilePath = "$backupPath/$FileName"

if ($isBacPac -eq 0) {
    Write-Host "`n  Uploading to container '$dockerContainerName' → $TargetFilePath..." -ForegroundColor Cyan
    try {
        Write-Host("Target: $backupPath")
        Write-Host("FilePath: $TargetFilePath")
        Write-Host("FileName: $FileName")
        docker exec $dockerContainerName mkdir -p $dockerSqlPath | Out-Null
        docker cp "$FilePath" "$($dockerContainerName):$TargetFilePath"
        Write-Host "  Upload successful: $FileName → $TargetFilePath" -ForegroundColor Green
    }
    catch {
        Write-Host "  Upload failed. Error: $_" -ForegroundColor Red
    }
}

return @{
    Type = if ($isBacPac) { "bacpac" } else { "bak" }
    Path = if ($isBacPac) { $FilePath } else { $TargetFilePath }
}
