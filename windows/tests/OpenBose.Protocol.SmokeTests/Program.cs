using System.Text.Json;
using OpenBose.Protocol;

static byte[] Hex(string s) =>
    s.Split(' ', StringSplitOptions.RemoveEmptyEntries)
     .Select(x => Convert.ToByte(x, 16)).ToArray();

static void Assert(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}

string fixturePath = Path.Combine(AppContext.BaseDirectory, "spec", "synthetic-fixtures.json");
using JsonDocument doc = JsonDocument.Parse(File.ReadAllText(fixturePath));

foreach (JsonElement frame in doc.RootElement.GetProperty("fullFrames").EnumerateArray())
{
    byte[] wire = Hex(frame.GetProperty("hex").GetString()!);
    BmapPacket packet = BmapPacket.ParseExact(wire);
    Assert(packet.Block == frame.GetProperty("block").GetByte(), "block mismatch");
    Assert(packet.Function == frame.GetProperty("function").GetByte(), "function mismatch");
    Assert(packet.Operator == frame.GetProperty("operator").GetByte(), "operator mismatch");
    Assert(packet.ToWire().SequenceEqual(wire), "round trip mismatch");
}

JsonElement fragmented = doc.RootElement.GetProperty("fragmented");
var decoder = new BmapFrameDecoder();
var received = new List<BmapPacket>();
foreach (JsonElement chunk in fragmented.GetProperty("chunksHex").EnumerateArray())
    received.AddRange(decoder.Feed(Hex(chunk.GetString()!)));
Assert(received.Count == 2, "fragment decoder must return two frames");
Assert(decoder.PendingBytes == 0, "fragment decoder left trailing data");

foreach (JsonElement invalid in doc.RootElement.GetProperty("invalidSingleFrames").EnumerateArray())
{
    bool threw = false;
    try { _ = BmapPacket.ParseExact(Hex(invalid.GetProperty("hex").GetString()!)); }
    catch (FormatException) { threw = true; }
    Assert(threw, $"invalid frame was accepted: {invalid.GetProperty("name").GetString()}");
}

foreach (string name in ReadOnlyCommands.Names)
{
    byte[] request = ReadOnlyCommands.BuildGet(name);
    ReadOnlyCommands.RequireAllowed(request);
    Assert(request[2] == BmapPacket.GetOperator && request[3] == 0, "GET contract violated");
}

foreach (JsonElement blocked in doc.RootElement.GetProperty("blockedOutbound").EnumerateArray())
{
    bool blockedOk = false;
    try { ReadOnlyCommands.RequireAllowed(Hex(blocked.GetString()!)); }
    catch (UnauthorizedAccessException) { blockedOk = true; }
    Assert(blockedOk, $"unsafe outbound request accepted: {blocked.GetString()}");
}

// Require strict framing, defensive copies and bounded receive memory.
var overflowDecoder = new BmapFrameDecoder();
overflowDecoder.Feed(new byte[] { 0x02, 0x02 });
bool overflowRejected = false;
try { overflowDecoder.Feed(new byte[BmapFrameDecoder.MaxBufferedBytes]); }
catch (FormatException) { overflowRejected = true; }
Assert(overflowRejected && overflowDecoder.PendingBytes == 0, "receive overflow must reset");
var originalPayload = new byte[] { 0x50 };
var ownedPacket = new BmapPacket(2, 2, 3, originalPayload);
originalPayload[0] = 0;
Assert(ownedPacket.Payload.Span[0] == 0x50, "packet must copy supplied payload");
Assert(received[0].ToWire().SequenceEqual(Hex("02 02 03 01 50")), "first stream frame mismatch");
Assert(received[1].ToWire().SequenceEqual(Hex("00 05 03 05 31 2e 38 2e 32")), "second stream frame mismatch");
var duplex = new ScriptedDuplexStream(Hex("00 05 03 05 31 2e 38 2e 32 02 02 03 01 50"), chunkSize: 2);
using (var exchange = new BmapReadOnlyExchange(duplex))
{
    int unmatched = 0;
    exchange.UnsolicitedPacket += _ => unmatched++;
    BmapPacket batteryReply = await exchange.QueryAsync("battery", TimeSpan.FromSeconds(2));
    Assert(batteryReply.Payload.Span[0] == 0x50, "wrong status returned from fragmented duplex stream");
    Assert(unmatched == 1, "unrelated firmware-status packet should be routed as unsolicited");
    Assert(duplex.Written.SequenceEqual(ReadOnlyCommands.BuildGet("battery")), "duplex wrote an unexpected command");
    bool rejectedBadCommand = false;
    try { await exchange.QueryAsync("firmware_update", TimeSpan.FromSeconds(1)); }
    catch (UnauthorizedAccessException) { rejectedBadCommand = true; }
    Assert(rejectedBadCommand && duplex.Written.Length == 4, "unsupported read must perform zero writes");
}

using (var stalled = new BmapReadOnlyExchange(new ScriptedDuplexStream(Array.Empty<byte>(), stallOnEnd: true)))
{
    bool didTimeout = false;
    try { await stalled.QueryAsync("battery", TimeSpan.FromMilliseconds(60)); }
    catch (TimeoutException) { didTimeout = true; }
    Assert(didTimeout, "a stalled RFCOMM receive must time out");
}
// SDP fixtures are derived from redacted, read-only NC700 service discovery.
foreach ((string descriptor, int channel) in new[]
{
    ("350C35031901003505190003080B", 11),
    ("350C350319010035051900030819", 25),
    ("350C350319010035051900030814", 20),
    ("350C350319010035051900030815", 21),
    ("350C35031901003505190003081B", 27),
    ("350C35031901003505190003081D", 29),
    ("350C35031901003505190003080E", 14),
    ("350C35031901003505190003080A", 10)
})
    Assert(SdpRfcommChannel.Parse(Convert.FromHexString(descriptor)) == channel,
        $"SDP channel {channel} not decoded correctly");
Assert(SdpRfcommChannel.Parse(Array.Empty<byte>()) is null, "empty SDP must not guess a channel");
Assert(SdpRfcommChannel.Parse(Convert.FromHexString("350C350319010035051900030808FF")) is null,
    "unexpected trailing SDP bytes must fail closed");
Assert(SdpRfcommChannel.Parse(Convert.FromHexString("350C350319010035051900030800")) is null,
    "invalid RFCOMM channel 0 accepted");
Console.WriteLine("OpenBose.Protocol smoke tests PASS: frames, GET-only exchange, bounded I/O and real SDP fixtures");

sealed class ScriptedDuplexStream : Stream
{
    private readonly byte[] _response;
    private readonly MemoryStream _writes = new();
    private readonly int _chunkSize;
    private readonly bool _stallOnEnd;
    private int _offset;

    public ScriptedDuplexStream(byte[] response, int chunkSize = 512, bool stallOnEnd = false)
    {
        _response = response;
        _chunkSize = chunkSize;
        _stallOnEnd = stallOnEnd;
    }

    public byte[] Written => _writes.ToArray();
    public override bool CanRead => true;
    public override bool CanWrite => true;
    public override bool CanSeek => false;
    public override long Length => throw new NotSupportedException();
    public override long Position
    {
        get => throw new NotSupportedException();
        set => throw new NotSupportedException();
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        int n = Math.Min(Math.Min(count, _chunkSize), _response.Length - _offset);
        if (n == 0) return 0;
        Array.Copy(_response, _offset, buffer, offset, n);
        _offset += n;
        return n;
    }

    public override async ValueTask<int> ReadAsync(
        Memory<byte> buffer, CancellationToken cancellationToken = default)
    {
        if (_offset >= _response.Length && _stallOnEnd)
            await Task.Delay(Timeout.Infinite, cancellationToken);
        cancellationToken.ThrowIfCancellationRequested();
        int n = Math.Min(Math.Min(buffer.Length, _chunkSize), _response.Length - _offset);
        _response.AsMemory(_offset, n).CopyTo(buffer);
        _offset += n;
        return n;
    }

    public override void Write(byte[] buffer, int offset, int count) =>
        _writes.Write(buffer, offset, count);
    public override ValueTask WriteAsync(
        ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _writes.Write(buffer.Span);
        return ValueTask.CompletedTask;
    }

    public override void Flush() { }
    public override Task FlushAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
}
