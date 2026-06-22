param(
    [string]$Configuration = "Release",
    [string]$ServiceDir = "C:\Users\Nate\homebrew\services",
    [switch]$NoCopy
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$publishRoot = Join-Path $root "publish"
$shimProject = Join-Path $root "SteamIfeoShim\SteamIfeoShim.csproj"
$serviceProject = Join-Path $root "SteamIfeoService\SteamIfeoService.csproj"
$shimPublish = Join-Path $publishRoot "shim"
$servicePublish = Join-Path $publishRoot "service"

dotnet publish $shimProject -c $Configuration -o $shimPublish
dotnet publish $serviceProject -c $Configuration -o $servicePublish

if (-not $NoCopy) {
    if (-not (Test-Path -LiteralPath $ServiceDir)) {
        New-Item -ItemType Directory -Path $ServiceDir -Force | Out-Null
    }

    Copy-Item -LiteralPath (Join-Path $shimPublish "SteamIfeoShim.exe") -Destination (Join-Path $ServiceDir "SteamIfeoShim.exe") -Force
    Copy-Item -LiteralPath (Join-Path $servicePublish "SteamIfeoService.exe") -Destination (Join-Path $ServiceDir "SteamIfeoService.exe") -Force

    Write-Host "Copied runtime executables to $ServiceDir"
}

Write-Host "Build complete."
