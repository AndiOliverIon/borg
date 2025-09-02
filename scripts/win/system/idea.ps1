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
    $linesRaw = Get-Content $logFile -Encoding UTF8
    $lines = @($linesRaw)
    if (-not $lines -or $lines.Count -eq 0) {
        Write-Host "📭 No ideas logged yet." -ForegroundColor DarkGray
        return
    }

    # Build display: color by STATUS only (not by words in the text)
    $display = for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '^\[(?<ts>[^\]]+)\]\s+(?<status>todo|done)\s*\|\s*(?<text>.*)$') {
            $colored = if ($matches['status'] -eq 'done') { "`e[32m$l`e[0m" } else { $l }
            "{0}`t{1}" -f $colored, $i
        } else {
            # Fallback: unparsed line, no color
            "{0}`t{1}" -f $l, $i
        }
    }

    $selectedRaw = $display | fzf --ansi --delimiter "`t" --with-nth=1 `
        --prompt "📌 Ideas > " --header "Enter to toggle todo/done"
    if (-not $selectedRaw) { return }

    $parts = $selectedRaw -split "`t", 2
    if ($parts.Count -lt 2) {
        Write-Host "❌ Could not parse selection." -ForegroundColor Red
        return
    }
    $index = [int]$parts[1]

    $original = $lines[$index]

    # Toggle only the STATUS token after the timestamp, before the '|'
    if ($original -match '^\[[^\]]+\]\s+(?<status>todo|done)(\s*\|.*)$') {
        $updated = if ($matches['status'] -eq 'todo') {
            $original -replace '(^\[[^\]]+\]\s*)todo(\s*\|)', '${1}done${2}'
        } else {
            $original -replace '(^\[[^\]]+\]\s*)done(\s*\|)', '${1}todo${2}'
        }
    } else {
        $updated = $original
    }

    $lines[$index] = $updated
    Set-Content -Path $logFile -Value $lines -Encoding UTF8

    $statusPart = ($updated -split '\|')[0].Trim()
    Write-Host "🔁 Status toggled → $statusPart" -ForegroundColor Cyan
}

function Reset-Ideas {
    $remaining = Get-Content $logFile | Where-Object { $_ -notmatch '^\[[^\]]+\]\s+done\s*\|' }
    Set-Content -Path $logFile -Value $remaining
    Write-Host "🧹 Done ideas cleared." -ForegroundColor Green
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
