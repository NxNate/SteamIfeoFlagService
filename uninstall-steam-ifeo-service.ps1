$ErrorActionPreference = "Stop"

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window."
}

$ifeoKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\steam.exe"

if (Get-Service -Name "SteamIfeoFlagService" -ErrorAction SilentlyContinue) {
    Stop-Service -Name "SteamIfeoFlagService" -ErrorAction SilentlyContinue
    sc.exe delete "SteamIfeoFlagService" | Out-Null
}

if (Test-Path -LiteralPath $ifeoKey) {
    Remove-ItemProperty -LiteralPath $ifeoKey -Name "Debugger" -ErrorAction SilentlyContinue
}

Write-Host "Uninstalled Steam IFEO service hook."
