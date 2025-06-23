param (
    [string[]]$extraArgs
)

. "$env:BORG_ROOT\config\globalfn.ps1"

# Auth header
$authHeader = @{
    Authorization = "Basic " + [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes("${jiraEmail}:${jiraAPIToken}")
    )
    Accept        = "application/json"
}

# How many days to scan
[int]$Days = 7
if ($extraArgs.Count -gt 0 -and $extraArgs[0] -as [int]) {
    $Days = [int]$extraArgs[0]
}

#Write-Host "`n  Debug: jiraEmail = $jiraEmail"
#Write-Host "`n  Debug: jiraDisplayName = $jiraDisplayName"
Write-Host "  Scanning updated issues for mentions or assignments in the last $Days days..." -ForegroundColor Cyan

# Get current user's accountId
$meUrl = "$jiraDomain/rest/api/2/myself"
$me = Invoke-RestMethod -Uri $meUrl -Headers $authHeader
$accountId = $me.accountId

# JQL query & fetch
$jql = "updated >= -${Days}d"
$url = "$jiraDomain/rest/api/2/search?jql=$([uri]::EscapeDataString($jql))&maxResults=100&fields=key,summary,status,assignee,updated"
$response = Invoke-RestMethod -Uri $url -Headers $authHeader

# Store relevant issues
$allIssues = @{}

foreach ($issue in $response.issues) {
    $key = $issue.key
    $summary = $issue.fields.summary
    $reason = @()
    $assignedToMe = $issue.fields.assignee?.accountId -eq $accountId

    if ($assignedToMe) {
        $reason += "👤 Assigned"
    }

    # Check for comment mentions
    $commentUrl = "$jiraDomain/rest/api/2/issue/$key/comment"
    try {
        $comments = (Invoke-RestMethod -Uri $commentUrl -Headers $authHeader).comments
        foreach ($comment in $comments) {
            if ($comment.body -match [regex]::Escape($jiraDisplayName)) {
                $reason += "💬 Mentioned"
                break
            }
        }
    }
    catch {
        Write-Warning "  Failed to fetch comments for ${key}: $_"
    }

    if ($reason.Count -gt 0) {
        $allIssues[$key] = @{
            issue  = $issue
            reason = ($reason -join " + ")
        }
    }
}

# Display results
Write-Host "`n  Total relevant issues: $($allIssues.Count)" -ForegroundColor Green

$sorted = $allIssues.Values | Sort-Object { $_.issue.fields.updated } -Descending

Write-Host ""
Write-Host "  Assigned or Mentioned Issues — Sorted by Last Update" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════════════════"

Write-Host ""
Write-Host "  Assigned or Mentioned Issues — Sorted by Last Update" -ForegroundColor Yellow
Write-Host "═════════════════════════════════════════════════════════════════════"

$rendered = $sorted | ForEach-Object {
    $i = $_.issue
    $reason = $_.reason
    $updated = (Get-Date $i.fields.updated).ToString("yyyy-MM-dd HH:mm")
    $status = $i.fields.status.name
    $summary = $i.fields.summary
    $key = $i.key

    @"
🔹 $key — $summary
      Updated: $updated
    🏷️ Status : $status
      Reason : $reason
─────────────────────────────────────────────────────────────────────
"@
}

# Join all as one text block
$finalText = $rendered -join "`n"

# Page the output with full keyboard support
$finalText | less
