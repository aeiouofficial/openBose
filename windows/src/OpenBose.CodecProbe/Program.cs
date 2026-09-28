using System.Text.Json;
using OpenBose.CodecProbe;

return ProgramMain.Run(args);

internal static class ProgramMain
{
    public static int Run(string[] args)
    {
        if (args.Any(a => a is "-h" or "--help"))
        {
            PrintHelp();
            return 0;
        }

        if (args.Length == 1 && args[0] == "--check")
        {
            Console.WriteLine(JsonSerializer.Serialize(new
            {
                windows = OperatingSystem.IsWindows(),
                os = Environment.OSVersion.VersionString,
                process64Bit = Environment.Is64BitProcess,
                elevated = EtwA2dpProbe.IsElevated,
                providerGuid = EtwA2dpProbe.ProviderGuid,
                provider = EtwA2dpProbe.ProviderName,
                eventName = EtwA2dpProbe.StreamingEventName,
                note = "TraceLogging provider metadata may not appear in logman/Get-WinEvent until active."
            }, JsonOptions));
            return 0;
        }

        int seconds = 30;
        bool json = args.Contains("--json", StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--timeout")
            {
                if (++i >= args.Length ||
                    !int.TryParse(args[i], out seconds) ||
                    seconds is < 1 or > 300)
                {
                    Console.Error.WriteLine("--timeout must be 1 through 300 seconds.");
                    return 2;
                }
                continue;
            }

            if (args[i] is "--json")
                continue;

            Console.Error.WriteLine($"Unknown argument: {args[i]}");
            return 2;
        }

        if (!OperatingSystem.IsWindows())
        {
            Console.Error.WriteLine("Windows is required.");
            return 2;
        }

        if (!EtwA2dpProbe.IsElevated)
        {
            Console.Error.WriteLine(
                "A2DP codec tracing requires Administrator elevation. " +
                "No trace session was started.");
            return 5;
        }

        if (!json)
        {
            Console.WriteLine("OpenBose Windows A2DP negotiated-codec probe");
            Console.WriteLine($"Listening for {seconds} seconds.");
            Console.WriteLine(
                "Start/stop normal audio on the Bose NC 700 while this window listens.");
            Console.WriteLine(
                "Read-only observation: no Bluetooth setting, codec or firmware command is sent.");
        }

        try
        {
            var messages = new List<string>();
            var result = new EtwA2dpProbe().Listen(
                TimeSpan.FromSeconds(seconds),
                message =>
                {
                    messages.Add(message);
                    if (!json) Console.WriteLine(message);
                });

            if (result is null)
            {
                if (json)
                    Console.WriteLine(JsonSerializer.Serialize(new
                    {
                        success = false,
                        reason = "No A2dpStreaming event observed.",
                        messages
                    }, JsonOptions));
                else
                    Console.WriteLine(
                        "No A2DP event observed. Ensure NC 700 is the active media output, " +
                        "then reconnect or start/stop playback while listening.");
                return 3;
            }

            if (json)
                Console.WriteLine(JsonSerializer.Serialize(new
                {
                    success = true,
                    codec = result.Codec.Name,
                    standardCodecId = result.Codec.StandardCodecId,
                    vendorId = result.Codec.VendorId,
                    vendorCodecId = result.Codec.VendorCodecId,
                    observedAtUtc = result.ObservedAtUtc,
                    result.EventId,
                    result.EventName,
                    messages
                }, JsonOptions));
            else
            {
                Console.WriteLine($"NEGOTIATED_CODEC={result.Codec.Name}");
                Console.WriteLine($"STANDARD_ID=0x{result.Codec.StandardCodecId:X2}");
                if (result.Codec.IsVendorSpecific)
                {
                    Console.WriteLine($"VENDOR_ID=0x{result.Codec.VendorId:X8}");
                    Console.WriteLine($"VENDOR_CODEC_ID=0x{result.Codec.VendorCodecId:X4}");
                }
            }

            return 0;
        }
        catch (UnauthorizedAccessException ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 5;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(
                $"A2DP ETW probe failed ({ex.GetType().Name}): {ex.Message}");
            return 4;
        }
    }

    private static readonly JsonSerializerOptions JsonOptions =
        new() { WriteIndented = true };

    private static void PrintHelp()
    {
        Console.WriteLine("""
            OpenBose Windows A2DP negotiated-codec probe

            Usage:
              OpenBose.CodecProbe --check
              OpenBose.CodecProbe [--timeout 30] [--json]

            --check
              Reports OS/elevation/provider prerequisites. Does not create an ETW trace.

            Live probe
              Requires an elevated process because Windows restricts the Bluetooth
              A2DP ETW session. The probe only listens for A2dpStreaming events.
              It does not send Bluetooth packets, alter Bose settings, select a
              codec, install a driver, or touch headphone firmware.

            Interpretation
              A negotiated codec proves what Windows is currently using.
              SBC/AAC does NOT by itself prove the headphones can never support
              another codec; sink capability evidence is a separate gate.
            """);
    }
}
