# upload.ps1 — Select local file/folder and upload to a cloud destination (Docker-style logic)

$rclone = Join-Path $rclonePath "rclone.exe"
$config = Join-Path $rclonePath "rclone.conf"
$remoteBase = "gdrive:"
$startPath = ""

function Browse-CloudDestination {
    param (
        [string]$currentPath = ""
    )

    $stack = @($currentPath)

    while ($true) {
        $currentPath = $stack[-1]
        $fullPath = "$remoteBase$currentPath"

        $items = & $rclone --config $config lsf "$fullPath" --dirs-only --format=p | Sort-Object

        $displayMap = @{}
        foreach ($entry in $items) {
            $displayMap[$entry] = "$currentPath$entry"
        }

        $selected = $displayMap.Keys | fzf --prompt "Cloud: /$currentPath > " --reverse | ForEach-Object { $_.Trim() }

        if (-not $selected -or -not $displayMap.ContainsKey($selected)) {
            return $null
        }

        $selectedPath = $displayMap[$selected]
        $isFolder = $selected -like "*/"

        if ($isFolder) {
            $choice = @("Enter folder", "Upload here") | fzf --prompt "Folder action: $selected > " --reverse

            if ($choice -eq "Enter folder") {
                $stack += $selectedPath
                continue
            }
            elseif ($choice -eq "Upload here") {
                return @{ Path = $selectedPath }
            }
            else {
                return $null
            }
        }
    }
}

function Select-LocalItem {
    $entries = Get-ChildItem -Force | Sort-Object { if ($_.PSIsContainer) { 0 } else { 1 } }, Name

    $displayMap = @{}
    foreach ($entry in $entries) {
        if ($entry.PSIsContainer) {
            $display = "$($entry.Name)/"
        }
        else {
            $display = $entry.Name
        }

        $displayMap[$display] = $entry.FullName
    }

    $selected = $displayMap.Keys | fzf --prompt "Select local file/folder to upload > " --reverse | ForEach-Object { $_.Trim() }

    if (-not $selected -or -not $displayMap.ContainsKey($selected)) {
        return $null
    }

    return $displayMap[$selected]
}

#   Step 1: Select local file or folder
$localItem = Select-LocalItem
if (-not $localItem) {
    Write-Host "  No local file or folder selected." -ForegroundColor Yellow
    exit 1
}

# ☁️ Step 2: Browse cloud destination
$cloudTarget = Browse-CloudDestination
if (-not $cloudTarget) {
    Write-Host "  No cloud destination selected." -ForegroundColor Yellow
    exit 1
}

# 🎯 Final upload
$destination = "$remoteBase$($cloudTarget.Path)"
Write-Host "`n  Uploading '$localItem' to '$destination'..." -ForegroundColor Cyan

& $rclone --config $config copy "$localItem" "$destination" --progress
