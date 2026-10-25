@echo off
echo Close RoboCop Rogue City before continuing.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-Mod.ps1" -Action Update
if errorlevel 1 echo See README.txt or include this error in a support report.
pause
