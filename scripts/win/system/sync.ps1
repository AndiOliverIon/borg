# scripts/win/central/sync.ps1
# Mirrors configured folders between local station and the shared NetworkRoot.
# Usage:
#   borg config upload            # local -> hub (NetworkRoot)
#   borg config download          # hub   -> local
#   borg config upload <name>     # just one folder
#   borg config download <name>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet('upload','download')]
  [string]$Action,

  [string]$Name = 'all'
)

# Load borg helpers (expects: Get-BorgStore, GetBorgStoreValue, Resolve-EnvTokens)
. "$env:BORG_ROOT\config\globalfn.ps1"

function New-DirIfMissing([string]$Path) {
  if (-not [string]::IsNullOrWhiteSpace($Path) -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

# --- Read config (via new cached accessor) ---
$store  = Get-BorgStore
$sync   = $store.Sync
if (-not $sync) { throw "Missing 'Sync' section in store.json." }

$networkRoot = GetBorgStoreValue -Chapter Sync -Key 'General.NetworkRoot' -ExpandEnv
if ([string]::IsNullOrWhiteSpace($networkRoot)) {
  throw "Sync.General.NetworkRoot is required."
}

# Ensure robocopy exists
if (-not (Get-Command robocopy.exe -ErrorAction SilentlyContinue)) {
  throw "robocopy.exe not found in PATH. Please ensure it's available."
}

# Collect folders (optionally filtered)
$folders = @($sync.Folders)
if (-not $folders -or $folders.Count -eq 0) { throw "No Sync.Folders defined." }

if ($Name -ne 'all') {
  $folders = $folders | Where-Object { $_.Name -eq $Name }
  if (-not $folders -or $folders.Count -eq 0) { throw "Sync folder '$Name' not found." }
}

foreach ($f in $folders) {
  # Resolve local path using new env expander from globalfn
  $localPath = ($f.Local | Resolve-EnvTokens)
  if ([string]::IsNullOrWhiteSpace($localPath) -or -not (Test-Path -LiteralPath $localPath)) {
    Write-Warning "Skip '$($f.Name)': local path missing or not found: $localPath"
    continue
  }

  $remoteRel  = if ($f.Remote) { $f.Remote } else { $f.Name }
  $remotePath = Join-Path $networkRoot $remoteRel
  New-DirIfMissing $remotePath

  if ($Action -eq 'upload') { $src = $localPath;  $dst = $remotePath }
  else                      { $src = $remotePath; $dst = $localPath  }

  # Map excludes:
  #   '*.log'   -> /XF
  #   'logs\**' -> /XD logs
  $exFiles = @()
  $exDirs  = @()
  foreach ($pat in ($f.Exclude ?? @())) {
    if ($pat -like '*\**') {
      $exDirs += ($pat -replace '\\\*\*$','')
    } else {
      $exFiles += $pat
    }
  }

  Write-Host ""
  Write-Host ("🔁 {0}  [{1}]" -f $Action.ToUpper(), $f.Name) -ForegroundColor Cyan
  Write-Host "    From: $src"
  Write-Host "    To:   $dst"

  # Ensure destination exists
  New-DirIfMissing $dst

  # Build robocopy args (mirror; one retry; no wait)
  $args = @(
    $src, $dst,
    '/MIR',        # mirror (includes deletions)
    '/Z',          # restartable mode
    '/R:1',        # one retry
    '/W:0',        # no wait
    '/COPY:DAT',   # file data, attributes, timestamps
    '/DCOPY:DAT',  # dir data, attributes, timestamps
    '/NFL','/NDL','/NP'  # cleaner output
  )
  if ($exFiles.Count) { $args += @('/XF') + $exFiles }
  if ($exDirs.Count)  { $args += @('/XD') + $exDirs  }

  $proc = Start-Process -FilePath robocopy.exe -ArgumentList $args -PassThru -Wait
  $code = $proc.ExitCode

  # robocopy: 0–7 = success-ish; >=8 = failure
  if ($code -ge 8) {
    Write-Warning "robocopy failed with code $code for [$($f.Name)]."
  } else {
    Write-Host "✅ Done (code $code)." -ForegroundColor Green
  }
}
