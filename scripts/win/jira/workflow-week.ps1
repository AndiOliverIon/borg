# Assume these are preloaded by Borg
# $jiraDomain, $jiraEmail, $jiraAPIToken

# ---- Build auth header ----
$authHeader = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${jiraEmail}:${jiraAPIToken}"))
    Accept        = "application/json"
}

# ---- Get your account ID ----
$me = Invoke-RestMethod "$jiraDomain/rest/api/2/myself" -Headers $authHeader
$accountId = $me.accountId

# ---- Build JQL to get assigned issues ----
$jql = "worklogAuthor = $accountId AND updated >= -7d ORDER BY updated DESC"
$searchUrl = "$jiraDomain/rest/api/2/search?jql=$([uri]::EscapeDataString($jql))&fields=key,summary&maxResults=50"
$response = Invoke-RestMethod -Uri $searchUrl -Headers $authHeader

Write-Host ""
Write-Host "📅 Jira Worklog Summary — This Week" -ForegroundColor Cyan
Write-Host ""

# ---- Build list of weekdays from Monday to today ----
$today = Get-Date
$startOfWeek = $today.AddDays( - (($_.DayOfWeek.value__ + 6) % 7)) # Always Monday
$datesOfWeek = @{}
for ($d = $startOfWeek; $d -le $today; $d = $d.AddDays(1)) {
    $key = $d.ToString("yyyy-MM-dd")
    $datesOfWeek[$key] = @()
}

# ---- Scan worklogs per issue ----
foreach ($issue in $response.issues) {
    $issueKey = $issue.key
    $summary = $issue.fields.summary
    $worklogUrl = "$jiraDomain/rest/api/2/issue/$issueKey/worklog"

    try {
        $worklogs = Invoke-RestMethod -Uri $worklogUrl -Headers $authHeader
    }
    catch {
        continue
    }

    foreach ($log in $worklogs.worklogs) {
        if ($log.author.accountId -ne $accountId) { continue }

        $logDate = ([datetime]::Parse($log.started)).ToString("yyyy-MM-dd")
        if ($datesOfWeek.ContainsKey($logDate)) {
            $datesOfWeek[$logDate] += @{
                Issue   = $issueKey
                Time    = $log.timeSpent
                Seconds = $log.timeSpentSeconds
                Summary = $summary
            }
        }
    }
}

# ---- Output summary per day ----
foreach ($day in $datesOfWeek.Keys | Sort-Object) {
    $entries = $datesOfWeek[$day]
    if ($entries.Count -eq 0) { continue }

    $total = ($entries | Measure-Object -Property Seconds -Sum).Sum / 60
    $hours = [math]::Floor($total / 60)
    $mins = [math]::Round($total % 60)

    Write-Host "📆 $day — $hours h $mins m" -ForegroundColor Yellow

    foreach ($entry in $entries) {
        Write-Host "   [$($entry.Issue)] $($entry.Time) — $($entry.Summary.Substring(0, [Math]::Min(60, $entry.Summary.Length)))"
    }

    Write-Host ""
}
