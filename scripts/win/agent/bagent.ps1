<# 
 bagent.ps1 — Borg Agent (controller + runtime)
 PowerShell 7+ (.NET 8)
 - start : launches hidden background agent (tray + SQL clipboard detection)
 - stop  : stops the agent if running
 - status: prints Running/Stopped
 - serve : internal; runs the agent (don’t call directly)

 Storage: %APPDATA%\borg\data\queries
 PID file: %APPDATA%\borg\agent\bagent.pid
#>

param(
    [ValidateSet('start', 'stop', 'status', 'serve')]
    [string]$Command = 'start'
)

# --------- Common paths ---------
$AppData = [Environment]::GetFolderPath('ApplicationData')
$AgentHome = Join-Path $AppData 'borg\agent'
$PidFile = Join-Path $AgentHome 'bagent.pid'
$ScriptPath = $MyInvocation.MyCommand.Path

# --------- Helpers (controller) ---------
function Get-AgentProcess {
    $seen = @{}
    $result = @()

    # PID file lookup
    if (Test-Path $PidFile) {
        $savedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($savedPid) {
            $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
            if ($proc) { $result += $proc; $seen[$proc.Id] = $true }
        }
    }

    # Fallback search
    try {
        $escaped = [Regex]::Escape($ScriptPath)
        $foundProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match 'pwsh.exe' -and
            $_.CommandLine -match "$escaped.+serve"
        }
        foreach ($m in $foundProcs) {
            if (-not $seen[$m.ProcessId]) {
                $proc = Get-Process -Id $m.ProcessId -ErrorAction SilentlyContinue
                if ($proc) { $result += $proc; $seen[$proc.Id] = $true }
            }
        }
    }
    catch {}

    return $result
}

function Start-Agent {
    if (-not (Test-Path $ScriptPath)) { Write-Error "Script not found: $ScriptPath"; return }
    New-Item -ItemType Directory -Path $AgentHome -Force | Out-Null

    $existing = Get-AgentProcess
    if ($existing.Count -gt 0) {
        Write-Host "Borg Agent already running (PID(s): $($existing.Id -join ', '))."
        return
    }

    $agentCliArgs = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, 'serve')
    $p = Start-Process -FilePath 'pwsh' -WindowStyle Hidden -ArgumentList $agentCliArgs -PassThru
    $p.Id | Set-Content -Path $PidFile -Encoding ASCII
    Write-Host "Borg Agent started (PID $($p.Id))."
}

function Stop-Agent {
    $procs = Get-AgentProcess
    if (-not $procs -or $procs.Count -eq 0) {
        Write-Host "Borg Agent is not running."
        if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
        return
    }

    # Remove PID file first
    if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }

    foreach ($p in $procs) {
        Write-Host "Stopping Borg Agent (PID $($p.Id))..."
        try {
            Stop-Process -Id $p.Id -Force -ErrorAction Stop
            Write-Host "Stopped PID $($p.Id)"
        }
        catch {
            #Write-Warning "Could not stop PID $($p.Id): $_"
        }
    }
}


function Get-AgentStatus {
    $procs = Get-AgentProcess
    if ($procs -and $procs.Count -gt 0) {
        Write-Host "Running (PID(s): $($procs.Id -join ', '))"
    }
    else {
        Write-Host "Stopped"
    }
}

# --------- Agent runtime (serve) ---------
function Invoke-AgentRuntime {
    # Runs inside the hidden child pwsh process
    $agentScript = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic  # for Interaction::InputBox

# ---------- Tray UI ----------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = "Borg Agent — SQL Clipboard Watcher"
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$pauseItem = New-Object System.Windows.Forms.ToolStripMenuItem "Pause detection"
$pauseItem.CheckOnClick = $true
$menu.Items.Add($pauseItem) | Out-Null

$openFolderItem = New-Object System.Windows.Forms.ToolStripMenuItem "Open queries folder"
$menu.Items.Add($openFolderItem) | Out-Null

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem "Exit"
$exitItem.add_Click({
    try {
        $pidPath = [System.IO.Path]::Combine(
            [System.Environment]::GetFolderPath('ApplicationData'),
            'borg','agent','bagent.pid'
        )
        if (Test-Path $pidPath) { Remove-Item $pidPath -Force -ErrorAction SilentlyContinue }
    } catch {}
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()
})
$menu.Items.Add($exitItem) | Out-Null

$tray.ContextMenuStrip = $menu

# ---------- Settings ----------
[int]   $PollMs          = 400
[int]   $ToastMs         = 3000
[double]$MinLen          = 24
[bool]  $RequirePunct    = $false

# Storage root = roaming AppData\borg\data\queries
$storeDir = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('ApplicationData'), 'borg', 'data', 'queries')
[System.IO.Directory]::CreateDirectory($storeDir) | Out-Null

$openFolderItem.add_Click({ Start-Process explorer.exe $storeDir })

# One toast per NEW clipboard content
$script:lastClipboardHash = $null
$script:lastClipboardText = $null

# ---------- Helpers ----------
function Test-IsSqlLike([string]$t) {
    if ([string]::IsNullOrWhiteSpace($t)) { return $false }
    $t = $t.Trim()

    # Ignore obvious non-SQL/code and self text
    if ($t.StartsWith("#") -or $t.StartsWith("//") -or $t -match '^\s*(using|class|public|private|function)\b') { return $false }
    if ($t -match 'PowerShell 7|bagent\.ps1|Create STA runspace') { return $false }

    if ($t.Length -lt $MinLen) { return $false }
    if ($RequirePunct -and ($t -notmatch '[;`\n]')) { return $false }

    $U = $t.ToUpperInvariant()
    $core   = @('SELECT','INSERT','UPDATE','DELETE','MERGE','CREATE','ALTER','DROP','TRUNCATE','WITH')
    $struct = @('FROM','INTO','WHERE','JOIN','VALUES','SET','ON','GROUP BY','ORDER BY','TOP','DECLARE','BEGIN','END','EXEC','TABLE','VIEW','PROC')
    $coreHits   = ($core   | Where-Object { $U.Contains($_) }).Count
    $structHits = ($struct | Where-Object { $U.Contains($_) }).Count
    return ($coreHits -ge 1 -and $structHits -ge 1)
}

function Get-ClipboardTextSafe {
    try {
        if ([System.Windows.Clipboard]::ContainsText()) { return [System.Windows.Clipboard]::GetText() }
        return $null
    } catch { return $null }
}

function Get-Hash([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) }
    finally { $sha.Dispose() }
}

function Show-SqlToast([string]$text) {
    $first = ($text -split "`r?`n",2)[0]
    if ($first.Length -gt 120) { $first = $first.Substring(0,120) + "…" }
    $tray.BalloonTipTitle = "SQL detected in clipboard"
    $tray.BalloonTipText  = $first + "`n(click to save)"
    $tray.ShowBalloonTip($ToastMs)
}

function Sanitize-FileName([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    $bad = [System.IO.Path]::GetInvalidFileNameChars()
    $clean = -join ($name.ToCharArray() | ForEach-Object { if ($bad -contains $_) { '_' } else { $_ } })
    return $clean.Trim()
}

function Save-Sql([string]$keyword, [string]$sqlText) {
    if ([string]::IsNullOrWhiteSpace($keyword)) { return $false }
    $base = (Sanitize-FileName $keyword)
    if ([string]::IsNullOrWhiteSpace($base)) { return $false }

    $path = [System.IO.Path]::Combine($storeDir, "$base.sql")
    $i = 1
    while (Test-Path $path) {
        $path = [System.IO.Path]::Combine($storeDir, "$base.$i.sql")
        $i++
    }

    [System.IO.File]::WriteAllText($path, $sqlText, [System.Text.Encoding]::UTF8)
    return $path
}

# Click toast -> prompt for keyword -> save
$tray.add_BalloonTipClicked({
    if ([string]::IsNullOrWhiteSpace($script:lastClipboardText)) { return }

    $defaultKey = ($script:lastClipboardText -split '\s+')[0]
    try {
        $keyword = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter a keyword to save this query as (will become the filename).",
            "Save SQL to Borg",
            $defaultKey
        )
    } catch { $keyword = $null }

    if (-not [string]::IsNullOrWhiteSpace($keyword)) {
        $saved = Save-Sql $keyword $script:lastClipboardText
        if ($saved) {
            $tray.BalloonTipTitle = "Saved"
            $tray.BalloonTipText  = "Stored as: " + [System.IO.Path]::GetFileName($saved)
            $tray.ShowBalloonTip(2000)
        } else {
            $tray.BalloonTipTitle = "Not saved"
            $tray.BalloonTipText  = "Invalid name or write error."
            $tray.ShowBalloonTip(2000)
        }
    }
})

# Poll the clipboard (one toast per new clipboard content)
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds($PollMs)
$timer.Add_Tick({
    if ($pauseItem.Checked) { return }
    $txt = Get-ClipboardTextSafe
    $hash = Get-Hash $txt

    if ($hash -and $hash -ne $script:lastClipboardHash) {
        $script:lastClipboardHash = $hash
        $script:lastClipboardText = $txt
        if (Test-IsSqlLike $txt) { Show-SqlToast $txt }
    }
})
$timer.Start()

[System.Windows.Threading.Dispatcher]::Run()

# Cleanup
$timer.Stop()
$tray.Visible = $false
$tray.Dispose()
'@

    # Host the agent in an STA runspace (PS7-safe)
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.ApartmentState = [System.Threading.ApartmentState]::STA
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $runspace.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    $null = $ps.AddScript($agentScript).Invoke()

    $ps.Dispose()
    $runspace.Close()
    $runspace.Dispose()
}

# --------- Command switch ---------
switch ($Command) {
    'start' { Start-Agent }
    'stop' { Stop-Agent }
    'status' { Get-AgentStatus }
    'serve' { Invoke-AgentRuntime }
}
