<#
.SYNOPSIS
  Simple, read-only Git status for Borg.
.DESCRIPTION
  Prints a friendly snapshot of the current repository:
  - Repo root, branch, upstream, ahead/behind
  - Staged / Unstaged / Untracked groups
  - Conflict detection + guidance
  No interactivity, no actions.
#>

# helpers
function W-Info($m){ Write-Host "🧭 $m" }
function W-Ok($m){ Write-Host "✅ $m" }
function W-Warn($m){ Write-Host "⚠️ $m" }
function W-Err($m){ Write-Host "❌ $m" }

# git available?
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  W-Err "git not found in PATH."
  exit 1
}

# ensure inside a git repo
$top = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($top)) {
  W-Err "Not inside a git repository."
  exit 2
}
Set-Location $top | Out-Null

# branch + upstream + ahead/behind
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$upstream = (git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
$ahead = 0; $behind = 0
if ($LASTEXITCODE -eq 0 -and $upstream) {
  $lr = (git rev-list --left-right --count "$upstream...HEAD").Trim().Split(" ")
  if ($lr.Count -eq 2) { $behind = [int]$lr[0]; $ahead = [int]$lr[1] }
}

# parse porcelain v2
$status = git status --porcelain=v2
$staged = New-Object System.Collections.Generic.List[string]
$unstaged = New-Object System.Collections.Generic.List[string]
$untracked = New-Object System.Collections.Generic.List[string]
$conflicts = New-Object System.Collections.Generic.HashSet[string]

foreach ($line in $status) {

  if ($line -match '^\?{2}\s+(.+)$') {
    [void]$untracked.Add($Matches[1])
    continue
  }

  if ($line -match '^u\s+.+\s(.+)$') {
    $p = $Matches[1]
    [void]$unstaged.Add($p)
    [void]$conflicts.Add($p)
    continue
  }

  if ($line -match '^\d+\s+([MADRCU\.])([MADRCU\.])\s+.+\s+(.+)$') {
    $x = $Matches[1]; $y = $Matches[2]; $path = $Matches[3]
    if ($x -ne '.') { [void]$staged.Add($path) }
    if ($y -ne '.') { [void]$unstaged.Add($path) }
    continue
  }
}

# de-dup + sort
$staged    = $staged    | Sort-Object -Unique
$unstaged  = $unstaged  | Sort-Object -Unique
$untracked = $untracked | Sort-Object -Unique

# header
Write-Host ""
W-Info ("Repo    : {0}" -f $top)
W-Info ("Branch  : {0}{1}" -f $branch, ($(if ($upstream) { " (upstream: $upstream, ↑$ahead ↓$behind)" } else { "" })))
Write-Host ""

function Show-Group([string]$title, $items, [string]$prefix, [bool]$markConflicts = $false) {
  if ($items -and $items.Count -gt 0) {
    Write-Host "• $title ($($items.Count))"
    foreach ($i in $items) {
      if ($markConflicts -and $conflicts.Contains($i)) {
        Write-Host ("  {0} <<CONFLICT>> {1}" -f $prefix, $i)
      } else {
        Write-Host ("  {0} {1}" -f $prefix, $i)
      }
    }
    Write-Host ""
  }
}

Show-Group "Staged changes"   $staged   "+" $false
Show-Group "Unstaged changes" $unstaged "~" $true
Show-Group "Untracked files"  $untracked "?" $false

# hints
if ($behind -gt 0) {
  W-Warn ("Branch is behind upstream by {0} commit(s). Consider: git pull --rebase" -f $behind)
}
if ($conflicts.Count -gt 0) {
  W-Warn "Unmerged changes detected. Resolve conflicts, then:"
  Write-Host "   git add <files> && git rebase --continue   (or)   git commit"
}

if ($staged.Count -eq 0 -and $unstaged.Count -eq 0 -and $untracked.Count -eq 0) {
  W-Ok "Working tree clean."
}