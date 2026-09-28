using OpenBose.CodecProbe;

static void Check(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}

var cases = new[]
{
    (new A2dpCodecInfo(0x00, 0, 0), "SBC"),
    (new A2dpCodecInfo(0x02, 0, 0), "AAC"),
    (new A2dpCodecInfo(0xFF, 0x004F, 0x0001), "aptX Classic"),
    (new A2dpCodecInfo(0xFF, 0x00D7, 0x0024), "aptX HD"),
    (new A2dpCodecInfo(0xFF, 0x00D7, 0x00AD), "aptX Adaptive / Lossless mode family"),
    (new A2dpCodecInfo(0xFF, 0x012D, 0x00AA), "LDAC"),
};

foreach (var (codec, expected) in cases)
    Check(codec.Name == expected, $"{codec} resolved as {codec.Name}, expected {expected}.");

Check(
    new A2dpCodecInfo(0xFF, 0xDEAD, 0xBEEF).Name.Contains("Unknown vendor codec"),
    "Unknown vendor codec must remain explicit.");
Check(
    new A2dpCodecInfo(0x05, 0, 0).Name.Contains("Reserved/unknown"),
    "Reserved standard codec must not receive a made-up name.");

foreach (object value in new object[] { (byte)2, (ushort)2, (uint)2, (ulong)2, (int)2, (long)2 })
    Check(EtwA2dpProbe.ConvertUnsigned(value) == 2, $"Unsigned conversion failed for {value.GetType().Name}.");

foreach (object value in new object[] { (sbyte)-1, (short)-1, -1, -1L })
{
    bool rejected = false;
    try { _ = EtwA2dpProbe.ConvertUnsigned(value); }
    catch (OverflowException) { rejected = true; }
    Check(rejected, $"Negative ETW field {value.GetType().Name} was not rejected.");
}

Check(
    EtwA2dpProbe.ProviderGuid == new Guid("8776ad1e-5022-4451-a566-f47e708b9075"),
    "Unexpected Windows BthA2dp ETW provider GUID.");

Console.WriteLine("OpenBose.CodecProbe PASS: codec IDs, vendor IDs,");
Console.WriteLine("unknown-codec handling, ETW integer validation and provider identity.");
