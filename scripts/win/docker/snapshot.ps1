param (
    [string]$suffix
)

. "$env:BORG_ROOT\config\globalfn.ps1"

# Validate config values
if (-not $ContainerName -or -not $SqlUser -or -not $SqlPassword -or -not $dockerBackupPath -or -not $SqlInstance) {
    Write-Error "Missing required docker config values in store. Please check chapter 'docker'."
    exit 1
}

# Query list of user databases from host
$dbList = & sqlcmd -S $SqlInstance -U $SqlUser -P $SqlPassword -Q "SELECT name FROM sys.databases WHERE database_id > 4" -h -1 -W

if (-not $dbList) {
    Write-Error "Could not retrieve database list."
    exit 1
}

# Let user choose with fzf
$db = $dbList | fzf
if (-not $db) {
    Write-Host "❌ No database selected. Aborting."
    exit 1
}

# Ask for suffix
if (-not $suffix) {
    $suffix = Read-Host "Enter snapshot suffix (e.g. Prep)"
}
if ($suffix -ne "") {
    $suffix = "_$suffix"
}

# Construct container-local backup path
$backupName = "$db$suffix.bak"
$backupPath = "$dockerBackupPath/$backupName"

# Compose SQL command
$backupSql = @"
BACKUP DATABASE [$db]
TO DISK = N'$backupPath'
WITH NOFORMAT, NOINIT, NAME = 'Snapshot Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
"@

# Execute the command inside container using bash
sqlcmd -S $SqlInstance -U $SqlUser -P $SqlPassword -Q $backupSql

# Final log
Write-Host "`n✅ Snapshot created:"
Write-Host "   Server:   $ContainerName"
Write-Host "   Database: $db"
Write-Host "   File (inside container): $backupPath"
