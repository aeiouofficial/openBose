// Combines WinRT RFCOMM read/write streams without exposing raw BMAP writes.
internal sealed class WinRtDuplexStream : Stream
{
    private readonly Stream _input;
    private readonly Stream _output;
    public WinRtDuplexStream(Stream input, Stream output)
    {
        _input = input ?? throw new ArgumentNullException(nameof(input));
        _output = output ?? throw new ArgumentNullException(nameof(output));
    }

    public override bool CanRead => _input.CanRead;
    public override bool CanWrite => _output.CanWrite;
    public override bool CanSeek => false;
    public override long Length => throw new NotSupportedException();
    public override long Position
    {
        get => throw new NotSupportedException();
        set => throw new NotSupportedException();
    }

    public override int Read(byte[] buffer, int offset, int count) =>
        _input.Read(buffer, offset, count);
    public override ValueTask<int> ReadAsync(
        Memory<byte> buffer, CancellationToken cancellationToken = default) =>
        _input.ReadAsync(buffer, cancellationToken);
    public override void Write(byte[] buffer, int offset, int count) =>
        _output.Write(buffer, offset, count);
    public override ValueTask WriteAsync(
        ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default) =>
        _output.WriteAsync(buffer, cancellationToken);
    public override Task FlushAsync(CancellationToken cancellationToken) =>
        _output.FlushAsync(cancellationToken);
    public override void Flush() => _output.Flush();
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    protected override void Dispose(bool disposing)
    {
        if (disposing) { _input.Dispose(); _output.Dispose(); }
        base.Dispose(disposing);
    }
}
