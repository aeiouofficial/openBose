namespace OpenBose.Protocol;

/// <summary>Incremental stream decoder; keeps partial frames across RFCOMM reads.</summary>
public sealed class BmapFrameDecoder
{
    public const int MaxBufferedBytes = 4096;
    private readonly List<byte> _pending = new();
    public int PendingBytes => _pending.Count;

    public IReadOnlyList<BmapPacket> Feed(ReadOnlySpan<byte> chunk)
    {
        if (chunk.Length > MaxBufferedBytes - _pending.Count)
        {
            _pending.Clear();
            throw new FormatException("BMAP receive buffer limit exceeded.");
        }

        _pending.AddRange(chunk.ToArray());
        var packets = new List<BmapPacket>();
        while (_pending.Count >= 4)
        {
            int frameLength = 4 + _pending[3];
            if (_pending.Count < frameLength) break;
            byte[] frame = _pending.GetRange(0, frameLength).ToArray();
            packets.Add(BmapPacket.ParseExact(frame));
            _pending.RemoveRange(0, frameLength);
        }
        return packets;
    }

    public void Reset() => _pending.Clear();
}
