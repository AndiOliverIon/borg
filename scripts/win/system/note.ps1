# note.ps1 — BORG Notes (simple, title=filename, fzf picker)
# Storage: %APPDATA%\Borg\notes
# Commands:
#   borg note add   "<title>" "<description>"
#   borg note search "<query>"      # fzf picker; Enter -> print description
#   borg note show                   # fzf picker; Enter -> print description
#   borg note show "<title>"         # direct by title; prints description
#   borg note edit "<title>"         # open in editor
#   borg note rm   "<title>"         # delete note

param(
  [Parameter(Mandatory, Position=0)]
  [ValidateSet('add','search','show','edit','rm')]
  [string]$Action,

  [Parameter(Position=1)] [string]$Arg1,  # title | query
  [Parameter(Position=2)] [string]$Arg2   # description for add
)

# ---------------- Paths & init ----------------
$NotesRoot = Join-Path $env:APPDATA "Borg\notes"

function Initialize-Notes {
  if (-not (Test-Path $NotesRoot)) { New-Item -ItemType Directory -Path $NotesRoot -Force | Out-Null }
}

# ---------------- Utilities ----------------
function Sanitize-Title([string]$Title) {
  if ([string]::IsNullOrWhiteSpace($Title)) { return $null }
  $clean = $Title.Trim()
  # Replace invalid filename chars with underscore
  [char[]]$bad = [IO.Path]::GetInvalidFileNameChars()
  foreach ($c in $bad) { $clean = $clean.Replace($c, '_') }
  # Collapse whitespace
  $clean = ($clean -replace '\s+', ' ').Trim()
  return $clean
}
function Title-ToPath([string]$Title) {
  $clean = Sanitize-Title $Title
  if (-not $clean) { return $null }
  Join-Path $NotesRoot "$clean.md"
}

function Read-FrontMatter([string[]]$Lines) {
  $meta = [ordered]@{}
  if ($Lines.Count -ge 3 -and $Lines[0].Trim() -eq '---') {
    $end = $null
    for ($i=1; $i -lt $Lines.Count; $i++) { if ($Lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end) {
      for ($j=1; $j -lt $end; $j++) {
        if ($Lines[$j] -match '^\s*([^:]+):\s*(.*)$') {
          $k = $matches[1].Trim(); $v = $matches[2].Trim()
          $meta[$k] = $v
        }
      }
    }
  }
  $meta
}
function Get-NoteBody([string[]]$Lines) {
  if ($Lines.Count -ge 3 -and $Lines[0].Trim() -eq '---') {
    $end = $null
    for ($i=1; $i -lt $Lines.Count; $i++) { if ($Lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -ne $null -and $end + 1 -lt $Lines.Count) { return ($Lines[($end+1)..($Lines.Count-1)] -join "`n").Trim() }
  }
  ($Lines -join "`n").Trim()
}
function Load-Note([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $lines = Get-Content -LiteralPath $Path
  $meta  = Read-FrontMatter $lines
  $body  = Get-NoteBody $lines
  [pscustomobject]@{
    Title    = if ($meta['Title']) { $meta['Title'] } else { [IO.Path]::GetFileNameWithoutExtension($Path) }
    Created  = $meta['CreatedUtc']
    Updated  = $meta['UpdatedUtc']
    Path     = $Path
    Body     = $body
  }
}
function Get-AllNotes {
  Initialize-Notes
  Get-ChildItem -LiteralPath $NotesRoot -Filter '*.md' -File |
    ForEach-Object { Load-Note $_.FullName } |
    Where-Object { $_ -ne $null }
}

function Require-Fzf {
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    throw "fzf is required for interactive selection. Install it (winget install fzf) or use direct commands."
  }
}

function Pick-NoteWithAction([pscustomobject[]]$Items, [string]$Prompt='notes> ') {
  Require-Fzf
  if (-not $Items -or $Items.Count -eq 0) { Write-Host 'No notes.'; return $null }

  # Title<TAB>Created<TAB>Path  (Path is field {3} for preview)
  $lines = $Items | ForEach-Object { "{0}`t{1}`t{2}" -f $_.Title, $_.Created, $_.Path }

  $previewCmd = 'powershell -NoProfile -Command "try { Get-Content -LiteralPath ''{3}'' -Raw } catch { Write-Output '''' }"'

$fzfArgs = @(
    '--delimiter', "`t",
    '--with-nth=1,2',
    '--prompt', $Prompt,
    '--height', '80%',
    '--layout', 'reverse',
    '--ansi',
    '--preview', $previewCmd,
    '--preview-window', 'hidden:border-rounded,wrap',  # keep preview available, but hidden
    '--bind', 'alt-p:toggle-preview,ctrl-p:toggle-preview', # toggle if you want it
    '--expect', 'enter,del,backspace'
  )

  $raw = $lines | & fzf @fzfArgs
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

  # When --expect is used, first line is the key; subsequent line(s) are selected items
  $parts = $raw -split "(`r`n|`n)"
  $key   = ($parts[0] ?? '').Trim().ToLower()
  $sel   = $parts | Where-Object { $_ -match "`t" } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($sel)) { return $null }

  $fields = $sel -split "`t", 3
  $selPath = $fields[2]
  $picked  = $Items | Where-Object { $_.Path -eq $selPath } | Select-Object -First 1

  # Return both the key and the picked note
  [pscustomobject]@{ Key = $key; Item = $picked }
}
function Pick-Note([pscustomobject[]]$Items, [string]$Prompt='notes> ') {
  $result = Pick-NoteWithAction $Items $Prompt
  if ($null -eq $result) { return $null }
  return $result.Item
}
# ---------------- Core ops ----------------
function Note-Add([string]$Title, [string]$Description) {
  $Title = Sanitize-Title $Title
  if (-not $Title) { throw 'Missing title. Usage: borg note add "<title>" "<description>"' }
  if ($null -eq $Description) { $Description = '' }

  Initialize-Notes

  $path = Title-ToPath $Title
  if (Test-Path -LiteralPath $path) {
    throw "A note with this title already exists: '$Title'"
  }

  $created = (Get-Date -AsUTC).ToString('o')

  $content = @(
    '---'
    "Title: $Title"
    "CreatedUtc: $created"
    "UpdatedUtc: $created"
    '---'
    ''
    $Description
  ) -join "`n"

  Set-Content -LiteralPath $path -Value $content -NoNewline -Encoding UTF8

  [pscustomobject]@{ Title=$Title; Path=$path }
}

function Note-Show([string]$TitleKey) {
  while ($true) {
    # ---- Resolve which note to show ----
    $note = $null

    if ([string]::IsNullOrWhiteSpace($TitleKey)) {
      # Interactive picker of all notes
      $picked = Pick-Note (Get-AllNotes) 'show> '
      if ($null -eq $picked) { return }

      # Support both: wrapper returns note; WithAction returns @{Item=...}
      $note = if ($picked.PSObject.Properties['Item']) { $picked.Item } else { $picked }
    }
    else {
      # Direct by title
      $path = Title-ToPath $TitleKey
      if (-not (Test-Path -LiteralPath $path)) {
        $matches = Get-AllNotes | Where-Object { $_.Title -ieq $TitleKey -or $_.Title -ilike "*$TitleKey*" }
        if ($matches.Count -gt 1) {
          $picked = Pick-Note $matches 'show> '
          if ($null -eq $picked) { return }
          $note = if ($picked.PSObject.Properties['Item']) { $picked.Item } else { $picked }
        } elseif ($matches.Count -eq 1) {
          $note = $matches[0]
        } else {
          throw "Note not found by title: '$TitleKey'"
        }
      } else {
        $note = Load-Note $path
        if ($null -eq $note) { throw "Note not found: '$TitleKey'" }
      }
    }

    # ---- Display the note and present actions ----
    Clear-Host
    Write-Host ("=== {0} ===" -f $note.Title) -ForegroundColor Cyan
    if ($note.Created) { Write-Host ("Created: {0}" -f $note.Created) -ForegroundColor DarkGray }
    if ($note.Updated) { Write-Host ("Updated: {0}" -f $note.Updated) -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host $note.Body
    Write-Host ''
    Write-Host "Options: [E]xit   [B]ack to list   [C]opy to clipboard"
    $choice = (Read-Host 'Choose').Trim().ToLowerInvariant()

    switch ($choice) {
      { $_ -in @('e','exit','q','quit') } { return }
      { $_ -in @('c','copy') } {
        if (CopyToClipboard $note.Body) {
          Write-Host 'Copied to clipboard.' -ForegroundColor Green
        } else {
          Write-Host 'Failed to copy to clipboard.' -ForegroundColor Red
        }
        # stay on the same note until user chooses B or E
        continue
      }
      { $_ -in @('b','back') } {
        # Go back to the list only makes sense when we came from a picker.
        # For direct title, also reopen the list for convenience.
        $TitleKey = $null
        continue
      }
      default {
        # Unknown input: re-prompt on same note
        continue
      }
    }
  }
}

function Open-NoteByPath([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Note file not found: $Path" }
  $editor =
    if     ($env:EDITOR)                                        { $env:EDITOR }
    elseif (Get-Command 'code'   -ErrorAction SilentlyContinue) { 'code' }
    elseif (Get-Command 'micro'  -ErrorAction SilentlyContinue) { 'micro' }
    else                                                        { 'notepad.exe' }

  $qpath = '"{0}"' -f $Path
  if ($editor -ieq 'code')       { Start-Process -FilePath 'code'       -ArgumentList @('-g', $qpath) | Out-Null }
  elseif ($editor -ieq 'micro')  { Start-Process -FilePath 'micro'      -ArgumentList @($qpath)       | Out-Null }
  elseif ($editor -ieq 'notepad.exe') { Start-Process -FilePath 'notepad.exe' -ArgumentList $qpath   | Out-Null }
  else                           { Start-Process -FilePath $editor      -ArgumentList $qpath          | Out-Null }
}
function Remove-NoteByPath([pscustomobject]$Note) {
  $title = $Note.Title
  $path  = $Note.Path
  $ans = Read-Host "Delete note '$title'? (y/N)"
  if ($ans -match '^(y|yes)$') {
    Remove-Item -LiteralPath $path -Force
    Write-Host "Removed note '$title'"
  } else {
    Write-Host "Cancelled."
  }
}
function Note-Edit([string]$TitleKey) {
  if ([string]::IsNullOrWhiteSpace($TitleKey)) { throw 'Usage: borg note edit "<title>"' }

  $path = Title-ToPath $TitleKey
  if (-not (Test-Path -LiteralPath $path)) { throw "Note not found by title: '$TitleKey'" }

  $editor =
    if     ($env:EDITOR)                                      { $env:EDITOR }
    elseif (Get-Command 'code'   -ErrorAction SilentlyContinue) { 'code' }
    elseif (Get-Command 'micro'  -ErrorAction SilentlyContinue) { 'micro' }
    else                                                        { 'notepad.exe' }

  # IMPORTANT: quote the path so spaces are preserved as a single argument
  $qpath = '"{0}"' -f $path

  if ($editor -ieq 'code') {
    Start-Process -FilePath 'code' -ArgumentList @('-g', $qpath) | Out-Null
  }
  elseif ($editor -ieq 'micro') {
    Start-Process -FilePath 'micro' -ArgumentList @($qpath) | Out-Null
  }
  elseif ($editor -ieq 'notepad.exe') {
    Start-Process -FilePath 'notepad.exe' -ArgumentList $qpath | Out-Null
  }
  else {
    # generic editor: still pass the quoted path as a single arg
    Start-Process -FilePath $editor -ArgumentList $qpath | Out-Null
  }
}

function Note-Rm([string]$TitleKey) {
  if ([string]::IsNullOrWhiteSpace($TitleKey)) { throw 'Usage: borg note rm "<title>"' }
  $path = Title-ToPath $TitleKey
  if (-not (Test-Path -LiteralPath $path)) { throw "Note not found by title: '$TitleKey'" }
  Remove-Item -LiteralPath $path -Force
  "Removed note '$TitleKey'"
}

function Note-Search([string]$Query) {
  Initialize-Notes
  $all = Get-AllNotes
  $matches = if ([string]::IsNullOrWhiteSpace($Query)) {
    $all
  } else {
    $all | Where-Object { $_.Title -match [regex]::Escape($Query) -or $_.Body -match $Query }
  }

  if (-not $matches -or $matches.Count -eq 0) { Write-Host "No matches."; return }

  $picked = Pick-NoteWithAction $matches 'search> '
  if ($null -eq $picked) { return }

  $key = $picked.Key
  $note = $picked.Item
  if ($null -eq $note) { return }

  switch ($key) {
    # Enter (or no key captured) -> open in editor
    ''       { Open-NoteByPath -Path $note.Path }
    'enter'  { Open-NoteByPath -Path $note.Path }

    # Delete or Backspace -> confirm & delete
    'del'        { Remove-NoteByPath -Note $note }
    'backspace'  { Remove-NoteByPath -Note $note }

    default { Open-NoteByPath -Path $note.Path }
  }
}

# ---------------- Dispatcher ----------------
switch ($Action) {
  'add'    { Note-Add   -Title $Arg1 -Description $Arg2 }
  'search' { Note-Search -Query $Arg1 }
  'show'   { Note-Show   -TitleKey $Arg1 }
  'edit'   { Note-Edit   -TitleKey $Arg1 }
  'rm'     { Note-Rm     -TitleKey $Arg1 }
}
