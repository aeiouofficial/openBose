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
Console.WriteLine("OpenBose.Protocol smoke tests PASS: fixtures, fragmentation, strict allowlist and overflow");
