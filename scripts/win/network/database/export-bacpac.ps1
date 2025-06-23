# ╭─────────────────────────────────────────────╮
# │   Export SQL Server Database to .bacpac   │
# ╰─────────────────────────────────────────────╯
param()

Clear-Host

#   Load Borg store
$store = Get-Content $storePath | ConvertFrom-Json

#   Ensure backup folder exists
$backupFolder = $store.CustomFolders.SqlBackupDefault
if (-not (Test-Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder | Out-Null
}

#   FZF pick from SqlServers (just names)
$nameMap = @{}
$store.SqlServers | ForEach-Object {
    $nameMap[$_.Name] = $_.ConnectionString
}
$selectedName = $nameMap.Keys | fzf --prompt "Select SQL connection for BACPAC export: "

if (-not $selectedName) {
    Write-Host "  No selection made. Aborting." -ForegroundColor Red
    exit 1
}

#   Get connection string
$connString = $nameMap[$selectedName]
$builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($connString)
$dbName = $builder.InitialCatalog
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bacpacFile = "${dbName}-${timestamp}.bacpac"
$targetPath = Join-Path $backupFolder $bacpacFile

#   Locate SqlPackage
#   Locate SqlPackage.exe
$sqlPackage = Get-Command "sqlpackage.exe" -ErrorAction SilentlyContinue

if (-not $sqlPackage) {
    $possiblePaths = @(
        "$env:ProgramFiles\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe",
        "$env:ProgramFiles(x86)\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe",
        "C:\ProgramData\chocolatey\lib\sqlpackage\tools\sqlpackage.exe"
    )

    foreach ($path in $possiblePaths) {
        $resolved = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($resolved) {
            $sqlPackage = $resolved.FullName
            break
        }
    }
}

if (-not $sqlPackage) {
    Write-Error "  SqlPackage.exe not found. Please install SQL Server Data Tools (SSDT) or DacFx."
    exit 1
}

#   Execute export
Write-Host ""
Write-Host "  Exporting '$dbName' to '$targetPath'..." -ForegroundColor Cyan

& $sqlPackage `
    /Action:Export `
    /SourceConnectionString:$connString `
    /TargetFile:$targetPath `
    /Quiet

#   Report result
if (Test-Path $targetPath) {
    Write-Host "`n  Export complete:" -ForegroundColor Green
    Write-Host "   $targetPath" -ForegroundColor Yellow
}
else {
    Write-Host "`n  Export failed." -ForegroundColor Red
}
