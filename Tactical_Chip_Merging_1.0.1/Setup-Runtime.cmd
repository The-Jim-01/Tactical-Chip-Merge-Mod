@echo off
echo Close RoboCop Rogue City before continuing.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-Runtime.ps1" -Action Install
if errorlevel 1 echo See README.txt or include this error in a support report.
pause
