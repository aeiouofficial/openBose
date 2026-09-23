using System.Collections.ObjectModel;

namespace OpenBose.Protocol;

/// <summary>Only known GET requests are constructible by the diagnostics client.</summary>
public static class ReadOnlyCommands
{
    private static readonly IReadOnlyDictionary<string, (byte Block, byte Function)> ByName =
        new ReadOnlyDictionary<string, (byte Block, byte Function)>(
            new Dictionary<string, (byte, byte)>(StringComparer.Ordinal)
            {
                ["bmap_version"] = (0, 1),
                ["function_blocks"] = (0, 2),
                ["product_id"] = (0, 3),
                ["firmware_version"] = (0, 5),
                ["noise_control"] = (1, 5),
                ["equalizer"] = (1, 7),
                ["battery"] = (2, 2)
            });

    public static IReadOnlyCollection<string> Names => ByName.Keys.ToArray();

    public static byte[] BuildGet(string name)
    {
        if (!ByName.TryGetValue(name, out var address))
            throw new UnauthorizedAccessException($"Unsupported BMAP read: {name}.");
        return new BmapPacket(address.Block, address.Function, BmapPacket.GetOperator,
            ReadOnlySpan<byte>.Empty).ToWire();
    }

    /// <summary>Call this at the real transport boundary, not just in the UI.</summary>
    public static void RequireAllowed(ReadOnlySpan<byte> request)
    {
        BmapPacket packet = BmapPacket.ParseExact(request);
        if (packet.Operator != BmapPacket.GetOperator || packet.Payload.Length != 0 ||
            !ByName.Values.Contains((packet.Block, packet.Function)))
            throw new UnauthorizedAccessException("Only allowlisted zero-payload NC700 GETs are permitted.");
    }
}
