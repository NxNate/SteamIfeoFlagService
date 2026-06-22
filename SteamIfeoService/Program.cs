using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.ServiceProcess;
using Microsoft.Win32;

internal static class Program
{
    public static void Main()
    {
        if (Environment.UserInteractive)
        {
            using var service = new SteamIfeoService();
            service.RunConsole();
            return;
        }

        ServiceBase.Run(new SteamIfeoService());
    }
}

internal sealed class SteamIfeoService : ServiceBase
{
    private const string ServiceNameValue = "SteamIfeoFlagService";
    private const string PipeName = "SteamIfeoFlagService";
    private const string IfeoSubKey = @"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\steam.exe";
    private const string ServiceParamsSubKey = @"SYSTEM\CurrentControlSet\Services\SteamIfeoFlagService\Parameters";

    private CancellationTokenSource? cancellation;
    private readonly object restoreLock = new();
    private Timer? restoreTimer;

    public SteamIfeoService()
    {
        ServiceName = ServiceNameValue;
        CanStop = true;
    }

    public void RunConsole()
    {
        OnStart([]);
        Console.WriteLine("SteamIfeoFlagService console mode. Press Enter to stop.");
        Console.ReadLine();
        OnStop();
    }

    protected override void OnStart(string[] args)
    {
        cancellation = new CancellationTokenSource();
        _ = Task.Run(() => PipeLoop(cancellation.Token));
    }

    protected override void OnStop()
    {
        cancellation?.Cancel();
        restoreTimer?.Dispose();
        RestoreDebugger();
    }

    private async Task PipeLoop(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                using var pipe = CreatePipe();
                await pipe.WaitForConnectionAsync(token);

                using var reader = new StreamReader(pipe, leaveOpen: true);
                using var writer = new StreamWriter(pipe, leaveOpen: true) { AutoFlush = true };

                var line = await reader.ReadLineAsync(token);
                var response = HandleCommand(line);
                await writer.WriteLineAsync(response.AsMemory(), token);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                Log(ex.ToString());
            }
        }
    }

    private static NamedPipeServerStream CreatePipe()
    {
        var pipeSecurity = new PipeSecurity();
        pipeSecurity.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null),
            PipeAccessRights.FullControl,
            AccessControlType.Allow));
        pipeSecurity.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
            PipeAccessRights.FullControl,
            AccessControlType.Allow));
        pipeSecurity.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null),
            PipeAccessRights.ReadWrite,
            AccessControlType.Allow));

        return NamedPipeServerStreamAcl.Create(
            PipeName,
            PipeDirection.InOut,
            1,
            PipeTransmissionMode.Byte,
            PipeOptions.Asynchronous,
            0,
            0,
            pipeSecurity);
    }

    private string HandleCommand(string? line)
    {
        if (line is null)
        {
            return "ERR empty command";
        }

        var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length != 2 || !string.Equals(parts[0], "TEMP_DISABLE", StringComparison.Ordinal))
        {
            return "ERR unknown command";
        }

        if (!int.TryParse(parts[1], out var milliseconds))
        {
            return "ERR invalid duration";
        }

        milliseconds = Math.Clamp(milliseconds, 1000, 15000);
        TemporarilyDisableDebugger(milliseconds);
        return "OK";
    }

    private void TemporarilyDisableDebugger(int milliseconds)
    {
        lock (restoreLock)
        {
            using var key = Registry.LocalMachine.CreateSubKey(IfeoSubKey, writable: true);
            key.DeleteValue("Debugger", throwOnMissingValue: false);

            restoreTimer?.Dispose();
            restoreTimer = new Timer(_ => RestoreDebugger(), null, milliseconds, Timeout.Infinite);
            Log($"Debugger disabled for {milliseconds}ms.");
        }
    }

    private void RestoreDebugger()
    {
        lock (restoreLock)
        {
            try
            {
                var debuggerValue = ReadConfiguredDebuggerValue();
                if (string.IsNullOrWhiteSpace(debuggerValue))
                {
                    Log("Configured debugger value is empty; not restoring.");
                    return;
                }

                using var key = Registry.LocalMachine.CreateSubKey(IfeoSubKey, writable: true);
                key.SetValue("Debugger", debuggerValue, RegistryValueKind.String);
                Log($"Debugger restored: {debuggerValue}");
            }
            catch (Exception ex)
            {
                Log(ex.ToString());
            }
        }
    }

    private static string? ReadConfiguredDebuggerValue()
    {
        using var key = Registry.LocalMachine.OpenSubKey(ServiceParamsSubKey, writable: false);
        return key?.GetValue("DebuggerValue") as string;
    }

    private static void Log(string message)
    {
        var logPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "SteamIfeoFlagService.log");

        File.AppendAllText(logPath, $"[{DateTimeOffset.Now:O}] {message}{Environment.NewLine}");
    }
}
