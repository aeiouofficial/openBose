namespace OpenBose.CodecProbe;

public readonly record struct A2dpCodecInfo(
    byte StandardCodecId,
    uint VendorId,
    uint VendorCodecId)
{
    public bool IsVendorSpecific => StandardCodecId == 0xFF;

    public string Name => ResolveName(StandardCodecId, VendorId, VendorCodecId);

    public static string ResolveName(byte standardCodecId, uint vendorId, uint vendorCodecId)
    {
        return standardCodecId switch
        {
            0x00 => "SBC",
            0x01 => "MPEG-1/2 Audio",
            0x02 => "AAC",
            0x03 => "MPEG-D USAC",
            0x04 => "ATRAC family",
            0xFF => ResolveVendor(vendorId, vendorCodecId),
            _ => $"Reserved/unknown standard codec 0x{standardCodecId:X2}",
        };
    }

    private static string ResolveVendor(uint vendorId, uint vendorCodecId)
    {
        return (vendorId, vendorCodecId) switch
        {
            (0x004F, 0x0001) => "aptX Classic",
            (0x000A, 0x0001) => "FastStream",
            (0x000A, 0x0002) => "aptX Low Latency",
            (0x00D7, 0x0002) => "aptX Low Latency",
            (0x00D7, 0x0024) => "aptX HD",
            (0x00D7, 0x0025) => "aptX TWS+",
            (0x00D7, 0x00AD) => "aptX Adaptive / Lossless mode family",
            (0x012D, 0x00AA) => "LDAC",
            (0x0075, 0x0102) => "Samsung HD",
            (0x0075, 0x0103) => "Samsung Scalable",
            (0x053A, 0x484C) => "LHDC",
            _ => $"Unknown vendor codec vendor=0x{vendorId:X8} codec=0x{vendorCodecId:X4}",
        };
    }

    public override string ToString()
    {
        if (!IsVendorSpecific)
            return $"{Name} (standard=0x{StandardCodecId:X2})";

        return $"{Name} (standard=0xFF, vendor=0x{VendorId:X8}, codec=0x{VendorCodecId:X4})";
    }
}
