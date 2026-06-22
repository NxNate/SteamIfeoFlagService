$ErrorActionPreference = "Stop"

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window."
}

$ifeoKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\steam.exe"
$serviceName = "SteamIfeoFlagService"
$serviceParamsKey = "HKLM:\SYSTEM\CurrentControlSet\Services\SteamIfeoFlagService\Parameters"

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Stop-Service -Name $serviceName -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
}

if (Test-Path -LiteralPath $ifeoKey) {
    Remove-ItemProperty -LiteralPath $ifeoKey -Name "Debugger" -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $serviceParamsKey) {
    Remove-Item -LiteralPath $serviceParamsKey -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Uninstalled Steam IFEO service hook."
