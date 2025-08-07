param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

$logFile = Join-Path $env:APPDATA "Borg\idea.log"

if (-not (Test-Path $logFile)) {
    New-Item -ItemType File -Path $logFile -Force | Out-Null
}

function Add-Idea {
    $text = $inputArgs -join " "
    if (-not $text) {
        Write-Host "⚠️  No idea text provided." -ForegroundColor Yellow
        exit 1
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    Add-Content -Path $logFile -Value "[${timestamp}] todo | $text"
    Write-Host "✅ Idea added." -ForegroundColor Green
}

function List-Ideas {
    # Write-Host "`n📌 [DEBUG] Starting List-Ideas" -ForegroundColor Cyan

    $linesRaw = Get-Content $logFile -Encoding UTF8
    $lines = @($linesRaw)  # Force to array

    # Write-Host "  ➤ Lines loaded: $($lines.Count)" -ForegroundColor Cyan

    if (-not $lines -or $lines.Count -eq 0) {
        Write-Host "📭 No ideas logged yet." -ForegroundColor DarkGray
        return
    }

    $selectedRaw = $lines | fzf --prompt "📌 Ideas > " --header "Enter to toggle todo/done"
    if (-not $selectedRaw) {
        # Write-Host "  ⚠ No selection made. Exiting." -ForegroundColor Yellow
        return
    }

    $selected = ($selectedRaw -join "") -as [string]
    $normalizedSelected = $selected.Trim() -replace '\s+', ' '

    # Write-Host "  🔹 Selected (raw): [$selectedRaw]"
    # Write-Host "  🔹 Selected (normalized): [$normalizedSelected]"

    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $current = $lines[$i]
        $normalizedCurrent = $current.Trim() -replace '\s+', ' '

        # Write-Host "    ↪ Comparing line :"
        # Write-Host "       original  = [$current]"
        # Write-Host "       normalized = [$normalizedCurrent]"

        if ($normalizedCurrent -eq $normalizedSelected) {
            $index = $i
            # Write-Host "  ✅ Match found at index $i"
            break
        }
    }

    if ($index -ge 0) {
        $original = $lines[$index]
        $updated = if ($original -match "\btodo\b") {
            $original -replace "\btodo\b", "done"
        }
        elseif ($original -match "\bdone\b") {
            $original -replace "\bdone\b", "todo"
        }
        else {
            $original
        }

        # Write-Host "  🛠 Updating line:"
        # Write-Host "     OLD: $original"
        # Write-Host "     NEW: $updated"

        $lines[$index] = $updated
        Set-Content -Path $logFile -Value $lines -Encoding UTF8

        $statusPart = ($updated -split '\|')[0].Trim()
        Write-Host "🔁 Status toggled → $statusPart" -ForegroundColor Cyan
    }
    else {
        Write-Host "❌ Could not find selected line in original list." -ForegroundColor Red
    }
}



function Reset-Ideas {
    $remaining = Get-Content $logFile | Where-Object { $_ -notmatch "\bdone\b" }
    Set-Content -Path $logFile -Value $remaining
    Write-Host "🧹 Done ideas cleared." -ForegroundColor Green
}

# Entry point
switch -regex ($inputArgs[0]) {
    "^list$" { List-Ideas; return }
    "^reset$" { Reset-Ideas; return }
    default { Add-Idea; return }
}
