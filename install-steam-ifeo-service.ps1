param(
    [string]$ServiceDir = "C:\Users\Nate\homebrew\services"
)

$ErrorActionPreference = "Stop"

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window."
}

$shimPath = Join-Path $ServiceDir "SteamIfeoShim.exe"
$servicePath = Join-Path $ServiceDir "SteamIfeoService.exe"
$ifeoKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\steam.exe"
$serviceParamsKey = "HKLM:\SYSTEM\CurrentControlSet\Services\SteamIfeoFlagService\Parameters"
$debuggerValue = "`"$shimPath`""

if (-not (Test-Path -LiteralPath $shimPath)) {
    throw "Shim was not found: $shimPath"
}

if (-not (Test-Path -LiteralPath $servicePath)) {
    throw "Service executable was not found: $servicePath"
}

if (-not (Test-Path -LiteralPath $ifeoKey)) {
    New-Item -Path $ifeoKey -Force | Out-Null
}

$existing = Get-Service -Name "SteamIfeoFlagService" -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name "SteamIfeoFlagService" -ErrorAction SilentlyContinue
    sc.exe delete "SteamIfeoFlagService" | Out-Null
    Start-Sleep -Seconds 2
}

sc.exe create "SteamIfeoFlagService" binPath= "`"$servicePath`"" start= auto DisplayName= "Steam IFEO Flag Service" | Out-Null
sc.exe description "SteamIfeoFlagService" "Temporarily disables Steam IFEO while launching Steam with CEF debugging flags." | Out-Null

if (-not (Test-Path -LiteralPath $serviceParamsKey)) {
    New-Item -Path $serviceParamsKey -Force | Out-Null
}

New-ItemProperty -LiteralPath $serviceParamsKey -Name "DebuggerValue" -Value $debuggerValue -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $ifeoKey -Name "Debugger" -Value $debuggerValue -PropertyType String -Force | Out-Null

Start-Service -Name "SteamIfeoFlagService"

Write-Host "Installed Steam IFEO service hook."
Write-Host "Debugger=$debuggerValue"
