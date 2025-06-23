Write-Host "`n🧪 Checking Borg system requirements..." -ForegroundColor Cyan

$missing = @()

# Check tools
$tools = @(
    @{ Name = "fzf"; Command = "fzf"; Url = "https://github.com/junegunn/fzf/releases/download/0.49.0/fzf-0.49.0-windows_amd64.zip"; Exe = "fzf.exe" },
    @{ Name = "micro"; Command = "micro"; Url = "https://github.com/zyedidia/micro/releases/download/v2.0.11/micro-2.0.11-win64.zip"; Exe = "micro.exe" }
)

foreach ($tool in $tools) {
    if (-not (Get-Command $tool.Command -ErrorAction SilentlyContinue)) {
        Write-Host "  Missing: $($tool.Name)" -ForegroundColor Red
        $missing += $tool
    }
    else {
        Write-Host "  Found: $($tool.Name)" -ForegroundColor Green
    }
}

# Check for Cascadia Code font presence
$fontInstalled = $false
$fontRegistry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" 2>$null

foreach ($key in $fontRegistry.PSObject.Properties.Name) {
    if ($key -match "Cascadia Code") {
        Write-Host "  Compatible font found: $key" -ForegroundColor Green
        $fontInstalled = $true
        break
    }
}

if (-not $fontInstalled) {
    Write-Host "   Cascadia Code font not found in registry." -ForegroundColor Yellow
    Write-Host "🤔 But if icons display correctly, you may already be using a patched font or Nerd Font." -ForegroundColor DarkGray
    Write-Host "💡 Proceeding with optional font install just in case..." -ForegroundColor Cyan
    $missing += @{ Name = "Cascadia Code"; Font = $true }
}

# If everything is fine
if ($missing.Count -eq 0) {
    Write-Host "`n🎉 All requirements met. You're Borg-ready!" -ForegroundColor Green
    exit 0
}

# Prompt to install
Write-Host "`n⚙️  The following components are missing and can be installed:" -ForegroundColor Yellow
$missing | ForEach-Object { Write-Host " - $($_.Name)" }

$confirm = Read-Host "`n   Do you want to install them now? (Y/n)"
if ($confirm -ne "" -and $confirm.ToLower() -ne "y") {
    Write-Host "  Skipping installation."
    exit 1
}

# Install tools
$temp = "$env:TEMP\borg-install"
New-Item -ItemType Directory -Path $temp -Force | Out-Null

foreach ($item in $missing) {
    if ($item.Font) {
        Write-Host "⬇️  Installing bundled font: Cascadia Code" -ForegroundColor Cyan
        $localFontPath = Resolve-Path "$PSScriptRoot\..\..\..\resources\fonts\CASCADIACODE.TTF"

        if (Test-Path $localFontPath) {
            try {
                $shellApp = New-Object -ComObject Shell.Application
                $fontDir = $shellApp.Namespace((Split-Path $localFontPath -Parent))
                $fontItem = $fontDir.ParseName((Split-Path $localFontPath -Leaf))

                if ($null -eq $fontItem) {
                    throw "Font file could not be resolved by Shell.Application. Install failed."
                }

                $fontItem.InvokeVerb("Install")
                Write-Host "  Font installation triggered. Please restart your terminal to apply changes." -ForegroundColor Green
            }
            catch {
                Write-Host "  Failed to trigger font install: $_" -ForegroundColor Red
                $global:borgInstallFailed = $true
            }
        }
        else {
            Write-Host "  Font file not found at $localFontPath. Skipping font install." -ForegroundColor Red
            $global:borgInstallFailed = $true
        }
    }
    elseif ($item.Exe) {
        Write-Host "⬇️  Installing tool: $($item.Name)" -ForegroundColor Cyan
        $zipPath = "$temp\$($item.Name).zip"
        $extractPath = "C:\Program Files\$($item.Name)"

        Invoke-WebRequest $item.Url -OutFile $zipPath -UseBasicParsing
        Expand-Archive $zipPath -DestinationPath $extractPath -Force

        # Add to PATH if not already present
        $envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($envPath -notlike "*$extractPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$envPath;$extractPath", "Machine")
            Write-Host "🔧 PATH updated for $($item.Name)" -ForegroundColor Green
        }
    }
}

if ($global:borgInstallFailed) {
    Write-Host "`n   Some components failed to install. Please check logs or try again." -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "`n  All selected components were installed successfully." -ForegroundColor Green
    Write-Host "🔁 You may need to restart your terminal session to see all changes." -ForegroundColor Cyan
    exit 0
}
