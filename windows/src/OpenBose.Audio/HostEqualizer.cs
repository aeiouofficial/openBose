namespace OpenBose.Audio;

/// <summary>
/// Three-band, app-owned float PCM preview. No Bose control commands, file writes,
/// system audio interception or permanent settings changes.
/// </summary>
public sealed class HostEqualizer
{
    private readonly object _sync = new();
    private readonly int _sampleRate;
    private readonly int _channels;
    private Biquad?[][] _filters = [];
    private double _bass;
    private double _mid;
    private double _treble;
    private bool _enabled;
    private int _nextChannel;
    private double _headroom = 1;

    public HostEqualizer(int sampleRate, int channels)
    {
        if (sampleRate is < 8000 or > 192000)
            throw new ArgumentOutOfRangeException(nameof(sampleRate));
        if (channels is < 1 or > 8)
            throw new ArgumentOutOfRangeException(nameof(channels));
        _sampleRate = sampleRate;
        _channels = channels;
        Rebuild();
    }

    public bool Enabled { get { lock (_sync) return _enabled; } }

    public void SetGains(double bassDb, double midDb, double trebleDb)
    {
        foreach (double gain in new[] { bassDb, midDb, trebleDb })
            if (!double.IsFinite(gain) || gain < -10 || gain > 10)
                throw new ArgumentOutOfRangeException(nameof(bassDb),
                    "Each host EQ band must be between -10 and +10 dB.");
        lock (_sync)
        {
            _bass = bassDb;
            _mid = midDb;
            _treble = trebleDb;
            // Leave at least the highest single-band boost as headroom.
            _headroom = Math.Pow(10, -Math.Max(0, Math.Max(bassDb,
                Math.Max(midDb, trebleDb))) / 20);
            Rebuild(); // A settings change starts a fresh, finite filter state.
        }
    }

    public void SetEnabled(bool enabled)
    {
        lock (_sync)
        {
            if (_enabled == enabled) return;
            _enabled = enabled;
            Rebuild(); // No stale filter tail when the player resumes.
        }
    }

    /// <summary>In-place interleaved float samples; bypass is bit-exact.</summary>
    public void Process(float[] samples, int offset, int count)
    {
        ArgumentNullException.ThrowIfNull(samples);
        if (offset < 0 || count < 0 || offset > samples.Length - count)
            throw new ArgumentOutOfRangeException(nameof(offset));
        lock (_sync)
        {
            if (!_enabled) return;
            for (int i = offset; i < offset + count; i++)
            {
                double x = float.IsFinite(samples[i]) ? samples[i] : 0;
                Biquad?[] channel = _filters[_nextChannel];
                foreach (Biquad? filter in channel)
                    if (filter is not null) x = filter.Tick(x);
                x *= _headroom;
                samples[i] = (float)Math.Clamp(
                    double.IsFinite(x) ? x : 0, -1, 1);
                _nextChannel = (_nextChannel + 1) % _channels;
            }
        }
    }

    private void Rebuild()
    {
        double[] gains = [_bass, _mid, _treble];
        double[] centerHz = [100, 1000, Math.Min(8000, _sampleRate * 0.4)];
        _filters = new Biquad?[_channels][];
        for (int channel = 0; channel < _channels; channel++)
        {
            _filters[channel] = new Biquad?[3];
            for (int band = 0; band < 3; band++)
                if (gains[band] != 0)
                    _filters[channel][band] =
                        new Biquad(centerHz[band], _sampleRate, gains[band]);
        }
        _nextChannel = 0;
    }

    private sealed class Biquad
    {
        private readonly double _b0, _b1, _b2, _a1, _a2;
        private double _z1, _z2;
        public Biquad(double frequency, int sampleRate, double gainDb)
        {
            // RBJ peaking EQ, bandwidth Q=1; separate state for each channel.
            double a = Math.Pow(10, gainDb / 40);
            double omega = 2 * Math.PI * frequency / sampleRate;
            double alpha = Math.Sin(omega) / 2;
            double cosine = Math.Cos(omega);
            double a0 = 1 + alpha / a;
            _b0 = (1 + alpha * a) / a0;
            _b1 = (-2 * cosine) / a0;
            _b2 = (1 - alpha * a) / a0;
            _a1 = (-2 * cosine) / a0;
            _a2 = (1 - alpha / a) / a0;
        }
        public double Tick(double input)
        {
            double output = _b0 * input + _z1;
            _z1 = _b1 * input - _a1 * output + _z2;
            _z2 = _b2 * input - _a2 * output;
            return output;
        }
    }
}
