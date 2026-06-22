param(
    [string]$Version = "v0.1.0",
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$artifacts = Join-Path $root "artifacts"
$packageRoot = Join-Path $artifacts "SteamIfeoFlagService-$Version"
$zipPath = Join-Path $artifacts "SteamIfeoFlagService-$Version-win-x64.zip"

Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

powershell -ExecutionPolicy Bypass -File (Join-Path $root "build.ps1") -Configuration $Configuration -NoCopy

Copy-Item -LiteralPath (Join-Path $root "publish\shim\SteamIfeoShim.exe") -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root "publish\service\SteamIfeoService.exe") -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root "install-steam-ifeo-service.ps1") -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root "uninstall-steam-ifeo-service.ps1") -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root "Install.bat") -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root "Uninstall.bat") -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root "README.md") -Destination $packageRoot -Force

$installHere = @'
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window."
}

if ($Uninstall) {
    powershell -ExecutionPolicy Bypass -File (Join-Path $here "uninstall-steam-ifeo-service.ps1")
    return
}

powershell -ExecutionPolicy Bypass -File (Join-Path $here "install-steam-ifeo-service.ps1") -ServiceDir $here
'@

Set-Content -LiteralPath (Join-Path $packageRoot "install-here.ps1") -Value $installHere -Encoding UTF8

$quickStart = @"
# Steam IFEO Flag Service $Version

1. Extract this zip somewhere permanent, for example:
   C:\Tools\SteamIfeoFlagService

2. Double-click Install.bat.

3. Approve the UAC prompt.

4. Start Steam normally.

5. Verify:
   Invoke-RestMethod http://127.0.0.1:8080/json

Uninstall from the same extracted folder:
   Double-click Uninstall.bat.
"@

Set-Content -LiteralPath (Join-Path $packageRoot "QUICKSTART.md") -Value $quickStart -Encoding UTF8

Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force

Write-Host $zipPath
