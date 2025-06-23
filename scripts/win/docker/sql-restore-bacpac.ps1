param(
    [Parameter(Mandatory)]
    [string]$BacpacPath
)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   SQL BACPAC Restore — Host-based using sqlpackage  
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Write-Host ""
Write-Host "  BACPAC File: $BacpacPath" -ForegroundColor Yellow

# 🧪 Ensure sqlpackage is available
$sqlPackageCmd = "sqlpackage"
if (-not (Get-Command $sqlPackageCmd -ErrorAction SilentlyContinue)) {
    Write-Host "  'sqlpackage' not found in PATH. Please ensure it is installed and accessible." -ForegroundColor Red
    exit 1
}

#   Determine base names
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($BacpacPath)
$proposedName = ($baseName -split '[-_]')[0]

#   Prompt for database name
$renameOptions = @(
    "Use proposed: $proposedName"
    "Keep original: $baseName"
    "Propose new name..."
)

$selected = $renameOptions | fzf --prompt "  Choose database name for import: " --height 10 --reverse | ForEach-Object { $_.Trim() }

if (-not $selected) {
    Write-Host "  No name selected. Aborting." -ForegroundColor Red
    exit 1
}

switch -Regex ($selected) {
    "^Use proposed:" {
        $dbName = $proposedName
    }
    "^Keep original:" {
        $dbName = $baseName
    }
    "^Propose new name" {
        $entered = Read-Host -Prompt "  Enter custom database name"
        $dbName = if ([string]::IsNullOrWhiteSpace($entered)) { $baseName } else { $entered }
    }
    default {
        Write-Host "  Invalid selection. Aborting." -ForegroundColor Red
        exit 1
    }
}

#   Load connection info from store
. "$env:BORG_ROOT\config\globalfn.ps1"

$server = GetBorgStoreValue -Chapter docker -Key sqlinstance
$username = GetBorgStoreValue -Chapter docker -Key sqluser
$password = GetBorgStoreValue -Chapter docker -Key sqlpassword

if (-not $server -or -not $username -or -not $password) {
    Write-Host "  Missing SQL connection configuration in store. Please check chapter 'docker'." -ForegroundColor Red
    exit 1
}

$connectionString = "Server=$server;Database=$dbName;User Id=$username;Password=$password;TrustServerCertificate=True"

#   Execute import
Write-Host ""
Write-Host "  Importing '$dbName' using sqlpackage.exe..." -ForegroundColor Cyan

& $sqlPackageCmd /Action:Import /SourceFile:"$BacpacPath" /TargetConnectionString:"$connectionString"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Import failed. Please check the output above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Database '$dbName' imported successfully!" -ForegroundColor Green
