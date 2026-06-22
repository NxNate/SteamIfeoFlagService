using System.Diagnostics;
using System.IO.Pipes;

internal static class Program
{
    private const string PipeName = "SteamIfeoFlagService";
    private const string SteamPath = @"C:\Program Files (x86)\Steam\steam.exe";
    private static readonly string[] RequiredFlags = ["-dev", "-cef-enable-debugging"];
    private const int DisableWindowMilliseconds = 4000;

    public static int Main(string[] args)
    {
        try
        {
            RequestTemporaryDisable();
            StartSteam(args);
            return 0;
        }
        catch (Exception ex)
        {
            Log(ex.ToString());
            return 1;
        }
    }

    private static void RequestTemporaryDisable()
    {
        using var pipe = new NamedPipeClientStream(".", PipeName, PipeDirection.InOut);
        ConnectWithRetry(pipe, TimeSpan.FromSeconds(10));

        using var reader = new StreamReader(pipe, leaveOpen: true);
        using var writer = new StreamWriter(pipe, leaveOpen: true) { AutoFlush = true };

        writer.WriteLine($"TEMP_DISABLE {DisableWindowMilliseconds}");
        var response = reader.ReadLine();
        if (!string.Equals(response, "OK", StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Service rejected TEMP_DISABLE request: {response}");
        }
    }

    private static void ConnectWithRetry(NamedPipeClientStream pipe, TimeSpan timeout)
    {
        var deadline = DateTimeOffset.UtcNow + timeout;
        Exception? lastError = null;

        while (DateTimeOffset.UtcNow < deadline)
        {
            try
            {
                pipe.Connect(500);
                return;
            }
            catch (TimeoutException ex)
            {
                lastError = ex;
            }
            catch (IOException ex)
            {
                lastError = ex;
                Thread.Sleep(100);
            }
            catch (UnauthorizedAccessException ex)
            {
                lastError = ex;
                Thread.Sleep(100);
            }
        }

        throw new TimeoutException("Timed out connecting to SteamIfeoFlagService.", lastError);
    }

    private static void StartSteam(string[] originalArgs)
    {
        if (!File.Exists(SteamPath))
        {
            throw new FileNotFoundException("Steam was not found at the expected path.", SteamPath);
        }

        var launchArgs = new List<string>();
        foreach (var arg in originalArgs)
        {
            if (LooksLikeSteamExePath(arg))
            {
                continue;
            }

            launchArgs.Add(arg);
        }

        foreach (var flag in RequiredFlags)
        {
            if (!launchArgs.Any(arg => string.Equals(arg, flag, StringComparison.OrdinalIgnoreCase)))
            {
                launchArgs.Add(flag);
            }
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = SteamPath,
            WorkingDirectory = Path.GetDirectoryName(SteamPath) ?? Environment.CurrentDirectory,
            UseShellExecute = false
        };

        foreach (var arg in launchArgs)
        {
            startInfo.ArgumentList.Add(arg);
        }

        Process.Start(startInfo);
    }

    private static bool LooksLikeSteamExePath(string arg)
    {
        try
        {
            return string.Equals(Path.GetFileName(arg.Trim('"')), "steam.exe", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static void Log(string message)
    {
        var logPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SteamIfeoShim.log");

        File.AppendAllText(logPath, $"[{DateTimeOffset.Now:O}] {message}{Environment.NewLine}");
    }
}
