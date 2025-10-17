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

# Cache (script scope)
$script:__BorgStore_Cache = $null
$script:__BorgStore_Mtime = $null

function Global:Get-BorgStore {
    [CmdletBinding()]
    param(
        [string]$Path = $storePath
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Borg store not found at: $Path"
    }

    $mtime = (Get-Item -LiteralPath $Path).LastWriteTimeUtc
    if ($null -eq $script:__BorgStore_Cache -or $mtime -ne $script:__BorgStore_Mtime) {
        $script:__BorgStore_Cache = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100
        $script:__BorgStore_Mtime = $mtime
    }
    return $script:__BorgStore_Cache
}

function Global:Clear-BorgStoreCache {
    $script:__BorgStore_Cache = $null
    $script:__BorgStore_Mtime = $null
}

function Resolve-EnvTokens {
    param([Parameter(ValueFromPipeline)][object]$Value)
    process {
        if ($Value -is [string]) {
            $s = $Value -replace '%(\w+)%', { [Environment]::GetEnvironmentVariable($args[0].Groups[1].Value) }
            if ($s.StartsWith('~')) { $s = $s -replace '^~', $env:USERPROFILE }
            return $s
        }
        return $Value
    }
}

# Simple JSON path resolver: supports dotted props and [index] on arrays
function Get-JsonPathValue {
    param(
        [Parameter(Mandatory)] [object]$Root,
        [Parameter(Mandatory)] [string]$Path
    )
    $current = $Root
    foreach ($segment in ($Path -split '\.')) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }

        # Match "Name" or "Name[0]" or just "[2]"
        if ($segment -match '^(?<prop>[^\[]*)(?<idx>\[\d+\])*$') {
            $prop = $matches['prop']
            $idxs = [System.Text.RegularExpressions.Regex]::Matches($segment, '\[(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value }

            if ($prop) {
                if ($current -is [System.Collections.IDictionary]) {
                    if (-not $current.Contains($prop)) { return $null }
                    $current = $current[$prop]
                } else {
                    # PSObject or normal object
                    $p = $current.PSObject.Properties[$prop]
                    if ($null -eq $p) { return $null }
                    $current = $p.Value
                }
            }

            foreach ($i in $idxs) {
                if ($current -is [System.Collections.IList]) {
                    if ($i -ge $current.Count) { return $null }
                    $current = $current[$i]
                } else {
                    return $null
                }
            }
        } else {
            return $null
        }
    }
    return $current
}

# === Enhanced (backward-compatible) accessor ===
function Global:GetBorgStoreValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Chapter,
        [Parameter(Mandatory)] [string]$Key,
        [object]$Default = $null,
        [switch]$ExpandEnv  # expands %APPDATA%, ~ on string results
    )

    $json = Get-BorgStore
    $section = $json.$Chapter

    if (-not $section) {
        if ($PSBoundParameters.ContainsKey('Default')) { return $Default }
        Write-Error "Chapter '$Chapter' not found"
        return $null
    }

    # Back-compat fast-path: plain property (no dot or bracket usage)
    $isSimple = ($Key -notmatch '[\.\[]')
    if ($isSimple) {
        $prop = $section.PSObject.Properties[$Key]
        if ($null -eq $prop) {
            if ($PSBoundParameters.ContainsKey('Default')) { return $Default }
            Write-Error "Key '$Key' not found in chapter '$Chapter'"
            return $null
        }
        $val = $prop.Value
    } else {
        # Nested path: e.g. "Folders[0].Local"
        $val = Get-JsonPathValue -Root $section -Path $Key
        if ($null -eq $val) {
            if ($PSBoundParameters.ContainsKey('Default')) { return $Default }
            Write-Error "Path '$Key' not found in chapter '$Chapter'"
            return $null
        }
    }

    if ($ExpandEnv) { $val = $val | Resolve-EnvTokens }
    return $val
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

# AI entry points
$aiFolder = Join-Path $scriptsRoot "ai"

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