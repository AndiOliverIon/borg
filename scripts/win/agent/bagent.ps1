# bagent.ps1 — Borg Agent MVP (tray + clipboard SQL detector, one-toast-per-clipboard-change)
# Works on PowerShell 7+. Runs a WPF Dispatcher loop inside an STA runspace.

# --- Script that runs inside the STA runspace ---
$agentScript = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

# ---------- Tray UI ----------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = "Borg Agent — SQL Clipboard Watcher"
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$pauseItem = New-Object System.Windows.Forms.ToolStripMenuItem "Pause detection"
$pauseItem.CheckOnClick = $true
$menu.Items.Add($pauseItem) | Out-Null

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem "Exit"
$exitItem.add_Click({
    try { [System.Windows.Threading.Dispatcher]::ExitAllFrames() } catch { }
})
$menu.Items.Add($exitItem) | Out-Null

$tray.ContextMenuStrip = $menu

# ---------- Detection settings ----------
[int]   $PollMs          = 400      # how often we check the clipboard
[int]   $ToastMs         = 3000     # toast duration
[double]$MinLen          = 24       # minimal text length to consider
[bool]  $RequirePunct    = $false   # if $true, require ; or newline

# Remember last clipboard content (hash). We only notify once per NEW clipboard content.
$script:lastClipboardHash = $null

# ---------- Helpers ----------
function Test-IsSqlLike([string]$t) {
    if ([string]::IsNullOrWhiteSpace($t)) { return $false }
    $t = $t.Trim()

    # Ignore obvious non-SQL/code comments / our own scripty text
    if ($t.StartsWith("#") -or $t.StartsWith("//") -or $t -match '^\s*(using|class|public|private|function)\b') { return $false }
    if ($t -match 'PowerShell 7|bagent\.ps1|Create STA runspace') { return $false }

    if ($t.Length -lt $MinLen) { return $false }
    if ($RequirePunct -and ($t -notmatch '[;`\n]')) { return $false }

    $U = $t.ToUpperInvariant()

    # Require at least one core SQL verb + one structural token
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
    } catch {
        return $null
    }
}

function Get-Hash([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))
    } finally {
        $sha.Dispose()
    }
}

function Show-SqlToast([string]$text) {
    $first = ($text -split "`r?`n",2)[0]
    if ($first.Length -gt 120) { $first = $first.Substring(0,120) + "…" }
    $tray.BalloonTipTitle = "SQL detected in clipboard"
    $tray.BalloonTipText  = $first
    $tray.ShowBalloonTip($ToastMs)
}

# Optional: double-click tray to toggle pause
$tray.add_DoubleClick({ $pauseItem.Checked = -not $pauseItem.Checked })

# ---------- Poll the clipboard ----------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds($PollMs)
$timer.Add_Tick({
    if ($pauseItem.Checked) { return }

    $txt = Get-ClipboardTextSafe
    $hash = Get-Hash $txt

    # Only act when the clipboard CONTENT CHANGES
    if ($hash -and $hash -ne $script:lastClipboardHash) {
        $script:lastClipboardHash = $hash

        if (Test-IsSqlLike $txt) {
            Show-SqlToast $txt
            # NOTE: because we only notify on *new* clipboard content, the same text won't re-toast again
            # unless the clipboard changes first.
        }
    }
})
$timer.Start()

# Run the WPF dispatcher loop
[System.Windows.Threading.Dispatcher]::Run()

# Cleanup when exiting
$timer.Stop()
$tray.Visible = $false
$tray.Dispose()
'@

# --- Host it in an STA runspace (PS7+ safe) ---
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
