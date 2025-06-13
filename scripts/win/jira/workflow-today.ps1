# Assume these are already set by Borg
# $jiraDomain, $jiraEmail, $jiraAPIToken

# ---- Auth header ----
$authHeader = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${jiraEmail}:${jiraAPIToken}"))
    Accept        = "application/json"
}

# ---- Get your Jira accountId ----
$meUrl = "$jiraDomain/rest/api/2/myself"
$me = Invoke-RestMethod -Uri $meUrl -Headers $authHeader
$accountId = $me.accountId

Write-Host ""
Write-Host "📅 Jira Worklog Summary — Today ($(Get-Date -Format 'yyyy-MM-dd'))" -ForegroundColor Magenta
Write-Host ""

# ---- Build JQL: assigned to me ----
$jql = "assignee = $accountId ORDER BY updated DESC"
$encodedJql = [uri]::EscapeDataString($jql)
$searchUrl = "$jiraDomain/rest/api/2/search?jql=$encodedJql&fields=key,summary&maxResults=50"
$response = Invoke-RestMethod -Uri $searchUrl -Headers $authHeader -Method Get

Write-Host "✅ Request succeeded. Issues returned: $($response.issues.Count)" -ForegroundColor Cyan

# ---- Define today's date ----
$today = (Get-Date).ToString("yyyy-MM-dd")
$results = @()

# ---- Check each issue's worklog ----
foreach ($issue in $response.issues) {
    $issueKey = $issue.key
    $summary = $issue.fields.summary
    $worklogUrl = "$jiraDomain/rest/api/2/issue/$issueKey/worklog"

    try {
        $worklogs = Invoke-RestMethod -Uri $worklogUrl -Headers $authHeader -Method Get
    }
    catch {
        Write-Warning "⚠️ Skipped $issueKey (no access or failed)."
        continue
    }

    foreach ($log in $worklogs.worklogs) {
        $logDate = ([datetime]::Parse($log.started)).ToString("yyyy-MM-dd")
        if ($log.author.accountId -eq $accountId -and $logDate -eq $today) {
            $results += [PSCustomObject]@{
                Issue   = $issueKey
                Time    = $log.timeSpent
                Seconds = $log.timeSpentSeconds
                Logged  = $log.started
                Summary = $summary
            }
        }
    }
}

# ---- Output results ----
if ($results.Count -eq 0) {
    Write-Host "⛔ No worklogs found for today." -ForegroundColor Yellow
}
else {
    $results | Sort-Object Logged | Format-Table -AutoSize

    $totalMinutes = ($results | Measure-Object -Property Seconds -Sum).Sum / 60
    Write-Host "`n🕒 Total logged today: $([math]::Round($totalMinutes)) minutes" -ForegroundColor Green
}
