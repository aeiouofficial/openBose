using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using OpenBose.Audio;

namespace OpenBose.Desktop;

internal sealed class HostEqSampleProvider : ISampleProvider
{
    private readonly ISampleProvider _source;
    private readonly HostEqualizer _equalizer;

    public HostEqSampleProvider(ISampleProvider source, HostEqualizer equalizer)
    {
        _source = source ?? throw new ArgumentNullException(nameof(source));
        _equalizer = equalizer ?? throw new ArgumentNullException(nameof(equalizer));
    }

    public WaveFormat WaveFormat => _source.WaveFormat;

    public int Read(float[] buffer, int offset, int count)
    {
        int read = _source.Read(buffer, offset, count);
        _equalizer.Process(buffer, offset, read);
        return read;
    }
}
