namespace OpenBose.Protocol;

// Conservative parser for the RFCOMM ProtocolDescriptorList observed in NC700 SDP.
// Returns null for unfamiliar encodings rather than guessing a channel.
public static class SdpRfcommChannel
{
    public static int? Parse(ReadOnlySpan<byte> bytes)
    {
        ReadOnlySpan<byte> canonical =
            new byte[] { 0x35, 0x0c, 0x35, 0x03, 0x19, 0x01, 0x00,
                         0x35, 0x05, 0x19, 0x00, 0x03, 0x08 };
        if (bytes.Length != 14 || !bytes[..13].SequenceEqual(canonical))
            return null;
        byte channel = bytes[13];
        return channel is >= 1 and <= 30 ? channel : null;
    }
}
