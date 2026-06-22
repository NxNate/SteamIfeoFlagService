# Steam IFEO Flag Service

Steam IFEO Flag Service forces Windows Steam launches to include:

```text
-dev -cef-enable-debugging
```

It is intended for setups that need Steam CEF debugging available at `127.0.0.1:8080`, including Decky Loader style tooling on Windows.

## What It Does

Windows Image File Execution Options can redirect every launch of `steam.exe` to a debugger program. This project uses that hook without modifying, renaming, or copying Steam's executable.

Launch flow:

1. Something starts `C:\Program Files (x86)\Steam\steam.exe`.
2. Windows IFEO runs `SteamIfeoShim.exe` instead.
3. The shim asks `SteamIfeoService` for a short disable window.
4. The service temporarily removes the IFEO `Debugger` value.
5. The shim starts the real `steam.exe` with `-dev -cef-enable-debugging`.
6. The service restores the IFEO hook.

## Files

- `SteamIfeoShim/` - user-mode IFEO shim.
- `SteamIfeoService/` - Windows service that edits the IFEO registry key.
- `build.ps1` - publishes both executables and optionally copies them to a service directory.
- `install-steam-ifeo-service.ps1` - installs the Windows service and IFEO hook.
- `uninstall-steam-ifeo-service.ps1` - removes the Windows service and IFEO hook.

## Build

Requires the .NET SDK on Windows.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

By default, the build copies the runtime executables to:

```text
C:\Users\Nate\homebrew\services
```

Use a different service directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 -ServiceDir "C:\Tools\SteamIfeoFlagService"
```

## Install

Run PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-steam-ifeo-service.ps1
```

With a custom service directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-steam-ifeo-service.ps1 -ServiceDir "C:\Tools\SteamIfeoFlagService"
```

## Verify

Start Steam normally, then check:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/json
```

You can also inspect the process command line:

```powershell
Get-CimInstance Win32_Process -Filter "name = 'steam.exe'" |
    Select-Object ProcessId,CommandLine
```

Expected command line includes:

```text
-dev -cef-enable-debugging
```

## Uninstall

Run PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall-steam-ifeo-service.ps1
```

This removes the Windows service and the IFEO `Debugger` value. It does not delete built executables.

## Logs

Shim log:

```text
%LOCALAPPDATA%\SteamIfeoShim.log
```

Service log:

```text
C:\ProgramData\SteamIfeoFlagService.log
```

## Notes

- Steam's install directory is not modified.
- `steam.exe` is not renamed, replaced, or copied.
- The IFEO hook requires administrator rights to install and uninstall.
- The service stores the intended `Debugger` value under its own service registry parameters and restores that value after each launch.
