# Define entry points
if (-not $env:BORG_ROOT) {
    throw "BORG_ROOT is not defined. Cannot proceed."
}

# If runnind is in demo mode (some things has to not be displayed)
$demoMode = $false

#   Main entry points
$borgRoot = $env:BORG_ROOT
$dataRoot = Join-Path $borgRoot "data"

#   External user store location
$userStoreFolder = Join-Path $env:APPDATA 'borg'
$storePath = Join-Path $userStoreFolder 'store.json'
$loggerPath = Join-Path $userStoreFolder 'log.txt'

# 🔧 Initialize store.json if missing
if (-not (Test-Path $storePath)) {
    New-Item -ItemType Directory -Path $userStoreFolder -Force | Out-Null
    $examplePath = Join-Path $dataRoot 'store.example.json'
    if (-not (Test-Path $examplePath)) {
        throw "Missing default store.example.json at $examplePath"
    }
    Copy-Item $examplePath $storePath -Force
    Write-Host "  Initialized user store at $storePath" -ForegroundColor Green
    Write-Host "  Configure it before continuing $storePath" -ForegroundColor Green
}

$dataRoot = Join-Path $env:BORG_ROOT 'data'
function Global:GetBorgStoreValue {
    param(
        [Parameter(Mandatory)]
        [string]$Chapter,

        [Parameter(Mandatory)]
        [string]$Key
    )

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

function CopyToClipboard([string]$Text) {
  try {
    $Text | Set-Clipboard
    return $true
  } catch {
    try {
      $Text | clip
      return $true
    } catch {
      return $false
    }
  }
}

# Fixed entry points

$scriptsRoot = Join-Path $borgRoot "scripts\win"
$dataRoot = Join-Path $borgRoot "data"
$configRoot = Join-Path $borgRoot "config"
$releaseNotesFolder = Join-Path $borgRoot "release-notes"

# Host entry points
$dockerFolder = Join-Path $scriptsRoot "docker"
$jumpFolder = Join-Path $scriptsRoot "jump"
$dockerSqlFilesFolder = Join-Path $dockerFolder "sql"
$ioFolder = Join-Path $scriptsRoot "io"
$sysFolder = Join-Path $scriptsRoot "system"
$gitFolder = Join-Path $scriptsRoot "git"

# Docker entry points
$dockerSqlPath = "/var/opt/mssql"
$dockerBackupPath = "$dockerSqlPath/backup"
$ContainerName = GetBorgStoreValue -Chapter Docker -Key SqlContainer
$SqlInstance = GetBorgStoreValue -Chapter Docker -Key SqlInstance
$HostPort = GetBorgStoreValue -Chapter Docker -Key SqlPort
$ImageTag = GetBorgStoreValue -Chapter Docker -Key SqlImageTag
$SqlUser = GetBorgStoreValue -Chapter Docker -Key SqlUser
$SqlPassword = GetBorgStoreValue -Chapter Docker -Key SqlPassword
$SqlUseDatabase = GetBorgStoreValue -Chapter Docker -Key UseDatabase

# Custom mappings folders
$SqlBackupDefaultFolder = GetBorgStoreValue -Chapter CustomFolders -Key SqlBackupDefault
$CustomScriptsFolder = GetBorgStoreValue -Chapter CustomFolders -Key CustomScripts

# Network entry points
$networkRoot = Join-Path $scriptsRoot "network"
$rclonePath = GetBorgStoreValue -Chapter Network -Key rclone

# Jira entry points
$jiraRoot = Join-Path $scriptsRoot "jira"
$jiraDomain = GetBorgStoreValue -Chapter Jira -Key Domain
$jiraEmail = GetBorgStoreValue -Chapter Jira -Key Email
$jiraAPIToken = GetBorgStoreValue -Chapter Jira -Key APIToken
$jiraDisplayName = GetBorgStoreValue -Chapter Jira -Key DisplayName