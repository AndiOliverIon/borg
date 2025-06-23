@echo off
set "APPDATA=%USERPROFILE%\AppData\Roaming"
set "BORG_ROOT=C:\borg"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BORG_ROOT%\borg.ps1" %*
