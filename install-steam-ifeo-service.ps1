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
$serviceName = "SteamIfeoFlagService"

if (-not (Test-Path -LiteralPath $shimPath)) {
    throw "Shim was not found: $shimPath"
}

if (-not (Test-Path -LiteralPath $servicePath)) {
    throw "Service executable was not found: $servicePath"
}

if (-not (Test-Path -LiteralPath $ifeoKey)) {
    New-Item -Path $ifeoKey -Force | Out-Null
}

function Wait-ServiceDeleted {
    param([string]$Name)

    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Service -Name $Name -ErrorAction SilentlyContinue)) {
            return
        }

        Start-Sleep -Milliseconds 250
    }

    throw "Timed out waiting for service '$Name' to be deleted."
}

$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name $serviceName -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
    Wait-ServiceDeleted -Name $serviceName
}

sc.exe create $serviceName binPath= "`"$servicePath`"" start= auto DisplayName= "Steam IFEO Flag Service" | Out-Null
sc.exe description $serviceName "Temporarily disables Steam IFEO while launching Steam with CEF debugging flags." | Out-Null

if (-not (Test-Path -LiteralPath $serviceParamsKey)) {
    New-Item -Path $serviceParamsKey -Force | Out-Null
}

New-ItemProperty -LiteralPath $serviceParamsKey -Name "DebuggerValue" -Value $debuggerValue -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $ifeoKey -Name "Debugger" -Value $debuggerValue -PropertyType String -Force | Out-Null

Start-Service -Name $serviceName
$service = Get-Service -Name $serviceName
$service.WaitForStatus("Running", [TimeSpan]::FromSeconds(10))

$actualDebugger = (Get-ItemProperty -LiteralPath $ifeoKey -Name "Debugger" -ErrorAction Stop).Debugger
if ($actualDebugger -ne $debuggerValue) {
    throw "IFEO Debugger value did not install correctly. Expected '$debuggerValue', got '$actualDebugger'."
}

Write-Host "Installed Steam IFEO service hook."
Write-Host "Debugger=$debuggerValue"
