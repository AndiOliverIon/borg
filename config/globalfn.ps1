# Define entry points
if (-not $env:BORG_ROOT) {
    throw "BORG_ROOT is not defined. Cannot proceed."
}

$dataRoot = Join-Path $env:BORG_ROOT 'data'
function Global:GetBorgStoreValue {
    param(
        [Parameter(Mandatory)]
        [string]$Chapter,

        [Parameter(Mandatory)]
        [string]$Key
    )
    
    $storePath = Join-Path $env:BORG_ROOT "data\store.json"
    if (-not (Test-Path $storePath)) {
        Write-Error "store.json not found at $storePath"
        return $null
    }

    $json = Get-Content $storePath -Raw | ConvertFrom-Json
    $section = $json.$Chapter    

    if (-not $section) {
        Write-Error "Chapter '$Chapter' not found"
        return $null
    }

    $value = $section.PSObject.Properties[$Key].Value
    if ($null -eq $value) {
        Write-Error "Key '$Key' not found in chapter '$Chapter'"
        return $null
    }

    return $value
}

# Fixed entry points
$borgRoot = $env:BORG_ROOT
$storePath = Join-Path $dataRoot "store.json"
$scriptsRoot = Join-Path $borgRoot "scripts\win"
$dataRoot = Join-Path $borgRoot "data"

# Host entry points
$HostBackupFolder = GetBorgStoreValue -Chapter General -Key HostBackupFolder
$dockerFolder = Join-Path $scriptsRoot "docker"
$jumpFolder = Join-Path $scriptsRoot "jump"
$dockerSqlFilesFolder = Join-Path $dockerFolder "sql"

# Docker entry points
$dockerSqlPath = "/var/opt/mssql"
$dockerBackupPath = "$dockerSqlPath/backup"
$ContainerName = GetBorgStoreValue -Chapter Docker -Key SqlContainer
$SqlInstance = GetBorgStoreValue -Chapter Docker -Key SqlInstance
$HostPort = GetBorgStoreValue -Chapter Docker -Key SqlPort
$ImageTag = GetBorgStoreValue -Chapter Docker -Key SqlImageTag
$SqlUser = GetBorgStoreValue -Chapter Docker -Key SqlUser
$SqlPassword = GetBorgStoreValue -Chapter Docker -Key SqlPassword