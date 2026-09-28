using System.Globalization;
using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.Session;

namespace OpenBose.CodecProbe;

public sealed record A2dpObservation(
    A2dpCodecInfo Codec,
    DateTimeOffset ObservedAtUtc,
    int EventId,
    string EventName);

public sealed class EtwA2dpProbe
{
    public static readonly Guid ProviderGuid =
        new("8776ad1e-5022-4451-a566-f47e708b9075");

    public const string ProviderName = "Microsoft.Windows.Bluetooth.BthA2dp";
    public const string StreamingEventName = "A2dpStreaming";

    public static bool IsElevated => TraceEventSession.IsElevated() == true;

    public A2dpObservation? Listen(TimeSpan timeout, Action<string>? debug = null)
    {
        if (!OperatingSystem.IsWindows())
            throw new PlatformNotSupportedException("Windows is required.");
        if (timeout < TimeSpan.FromSeconds(1) || timeout > TimeSpan.FromMinutes(5))
            throw new ArgumentOutOfRangeException(nameof(timeout));
        if (!IsElevated)
            throw new UnauthorizedAccessException(
                "Windows Bluetooth A2DP ETW requires an elevated process.");

        A2dpObservation? observation = null;
        string sessionName = $"OpenBose-A2dp-{Environment.ProcessId}";

        using var session = new TraceEventSession(
            sessionName,
            TraceEventSessionOptions.Create)
        {
            StopOnDispose = true,
        };

        session.Source.Dynamic.AddCallbackForProviderEvent(
            ProviderName,
            StreamingEventName,
            traceEvent =>
            {
                try
                {
                    A2dpCodecInfo codec = ParseCodec(traceEvent);
                    observation = new A2dpObservation(
                        codec,
                        traceEvent.TimeStamp.ToUniversalTime(),
                        (int)traceEvent.ID,
                        traceEvent.EventName);
                    debug?.Invoke($"Observed {codec}.");
                    session.Source.StopProcessing();
                }
                catch (Exception ex)
                {
                    debug?.Invoke(
                        $"Ignored malformed {traceEvent.EventName} event: {ex.Message}");
                }
            });

        session.EnableProvider(
            ProviderGuid,
            TraceEventLevel.Verbose,
            matchAnyKeywords: 0);

        using var timeoutSignal = new CancellationTokenSource();
        Task timer = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(timeout, timeoutSignal.Token);
                session.Source.StopProcessing();
            }
            catch (OperationCanceledException)
            {
                // Normal when a codec event stops the trace first.
            }
        });

        try
        {
            session.Source.Process();
        }
        finally
        {
            timeoutSignal.Cancel();
            try { timer.GetAwaiter().GetResult(); }
            catch (OperationCanceledException) { }
        }

        return observation;
    }

    public static A2dpCodecInfo ParseCodec(TraceEvent traceEvent)
    {
        ArgumentNullException.ThrowIfNull(traceEvent);

        byte standard = checked((byte)ReadUnsigned(
            traceEvent,
            "A2dpStandardCodecId",
            fallbackIndex: 3));

        if (standard != 0xFF)
            return new A2dpCodecInfo(standard, 0, 0);

        uint vendor = checked((uint)ReadUnsigned(
            traceEvent,
            "A2dpVendorId",
            fallbackIndex: 4));
        uint vendorCodec = checked((uint)ReadUnsigned(
            traceEvent,
            "A2dpVendorCodecId",
            fallbackIndex: 5));

        return new A2dpCodecInfo(standard, vendor, vendorCodec);
    }

    public static ulong ConvertUnsigned(object value)
    {
        ArgumentNullException.ThrowIfNull(value);

        return value switch
        {
            byte v => v,
            sbyte v when v >= 0 => (ulong)v,
            ushort v => v,
            short v when v >= 0 => (ulong)v,
            uint v => v,
            int v when v >= 0 => (ulong)v,
            ulong v => v,
            long v when v >= 0 => (ulong)v,
            _ => Convert.ToUInt64(value, CultureInfo.InvariantCulture),
        };
    }

    private static ulong ReadUnsigned(
        TraceEvent traceEvent,
        string fieldName,
        int fallbackIndex)
    {
        string[] names = traceEvent.PayloadNames;
        int index = Array.FindIndex(
            names,
            n => string.Equals(n, fieldName, StringComparison.OrdinalIgnoreCase));

        if (index < 0)
            index = fallbackIndex;

        if (index < 0 || index >= names.Length)
        {
            throw new InvalidDataException(
                $"Missing {fieldName}; payload fields: {string.Join(", ", names)}");
        }

        object? value = traceEvent.PayloadValue(index);
        if (value is null)
            throw new InvalidDataException($"{fieldName} is null.");

        return ConvertUnsigned(value);
    }
}
