namespace OpenBose.Protocol;

/// <summary>
/// Single-request RFCOMM exchange. Only the audited NC700 zero-payload GET
/// allowlist can reach the supplied stream. No firmware or settings writes.
/// </summary>
public sealed class BmapReadOnlyExchange : IDisposable
{
    private readonly Stream _stream;
    private readonly SemaphoreSlim _requests = new(1, 1);
    private readonly BmapFrameDecoder _decoder = new();
    private bool _disposed;

    /// <summary>Frames that do not match the pending GET are diagnostic events.</summary>
    public event Action<BmapPacket>? UnsolicitedPacket;

    public BmapReadOnlyExchange(Stream stream)
    {
        ArgumentNullException.ThrowIfNull(stream);
        if (!stream.CanRead || !stream.CanWrite)
            throw new ArgumentException("BMAP requires a readable and writable stream.", nameof(stream));
        _stream = stream;
    }

    public async Task<BmapPacket> QueryAsync(
        string commandName, TimeSpan timeout, CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (timeout <= TimeSpan.Zero || timeout > TimeSpan.FromSeconds(30))
            throw new ArgumentOutOfRangeException(nameof(timeout), "Use 1 ms to 30 seconds.");

        // Validate before touching a Bluetooth stream, including when disconnected.
        byte[] wire = ReadOnlyCommands.BuildGet(commandName);
        ReadOnlyCommands.RequireAllowed(wire);
        using var timer = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timer.CancelAfter(timeout);
        bool entered = false;
        try
        {
            await _requests.WaitAsync(timer.Token).ConfigureAwait(false);
            entered = true;

            // Ignore incomplete frames left over after an interrupted earlier request.
            _decoder.Reset();
            await _stream.WriteAsync(wire, timer.Token).ConfigureAwait(false);
            await _stream.FlushAsync(timer.Token).ConfigureAwait(false);

            byte[] buffer = new byte[512];
            while (true)
            {
                int count = await _stream.ReadAsync(buffer, timer.Token).ConfigureAwait(false);
                if (count == 0) throw new EndOfStreamException("RFCOMM channel closed.");

                BmapPacket? answer = null;
                foreach (BmapPacket packet in _decoder.Feed(buffer.AsSpan(0, count)))
                {
                    if (answer is null && packet.Block == wire[0] &&
                        packet.Function == wire[1] &&
                        (packet.Operator == BmapPacket.StatusOperator ||
                         packet.Operator == BmapPacket.ErrorOperator))
                    {
                        answer = packet;
                    }
                    else
                    {
                        UnsolicitedPacket?.Invoke(packet);
                    }
                }
                if (answer is not null) return answer;
            }
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new TimeoutException($"Timed out waiting for {commandName} BMAP response.");
        }
        finally
        {
            if (entered) _requests.Release();
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _requests.Dispose();
        // The caller owns the Bluetooth stream and socket.
    }
}
