@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-here.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Install failed. Check the message above.
    pause
    exit /b %errorlevel%
)

echo.
echo Installed Steam IFEO Flag Service.
echo You can start Steam normally now.
pause
