namespace OpenBose.Protocol;

/// <summary>One unframed Bluetooth BMAP packet: block, function, operator, length, payload.</summary>
public sealed class BmapPacket
{
    public const byte GetOperator = 0x01;
    public const byte SetGetOperator = 0x02;
    public const byte StatusOperator = 0x03;
    public const byte ErrorOperator = 0x04;
    public const byte StartOperator = 0x05;

    public byte Block { get; }
    public byte Function { get; }
    public byte Operator { get; }
    private readonly byte[] _payload;
    public ReadOnlyMemory<byte> Payload => _payload;

    public BmapPacket(byte block, byte function, byte op, ReadOnlySpan<byte> payload)
    {
        if (payload.Length > byte.MaxValue) throw new ArgumentOutOfRangeException(nameof(payload));
        Block = block;
        Function = function;
        Operator = op;
        _payload = payload.ToArray();
    }

    public byte[] ToWire()
    {
        byte[] wire = new byte[4 + _payload.Length];
        wire[0] = Block;
        wire[1] = Function;
        wire[2] = Operator;
        wire[3] = (byte)_payload.Length;
        _payload.CopyTo(wire, 4);
        return wire;
    }

    public static BmapPacket ParseExact(ReadOnlySpan<byte> wire)
    {
        if (wire.Length < 4) throw new FormatException("Incomplete BMAP header.");
        int expected = 4 + wire[3];
        if (wire.Length != expected)
            throw new FormatException($"BMAP frame length mismatch: expected {expected}, got {wire.Length}.");
        return new BmapPacket(wire[0], wire[1], wire[2], wire[4..]);
    }
}
