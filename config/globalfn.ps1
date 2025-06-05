# Define entry points

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
    #Write-Host "Raw key list in [$Chapter]: $($section.PSObject.Properties.Name -join ', ')"

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
$dockerSqlFilesFolder = Join-Path $dockerFolder "sql"

# Docker entry points
$dockerSqlPath = "/var/opt/mssql"
$dockerBackupPath = "$dockerSqlPath/backup"
$ContainerName = GetBorgStoreValue -Chapter Docker -Key SqlContainer
$HostPort = GetBorgStoreValue -Chapter Docker -Key SqlPort
$imageTag = GetBorgStoreValue -Chapter Docker -Key SqlImageTag
$SqlUser = GetBorgStoreValue -Chapter Docker -Key SqlUser
$SqlPassword = GetBorgStoreValue -Chapter Docker -Key SqlPassword