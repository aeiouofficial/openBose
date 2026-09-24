using OpenBose.Audio;

static void Check(bool ok, string reason)
{
    if (!ok) throw new Exception(reason);
}

const int rate = 48000;
const int channels = 2;
const int frames = 48000;
static float[] Tone(int hz)
{
    var data = new float[frames * channels];
    for (int i = 0; i < frames; i++)
        data[i * channels] = (float)(0.1 * Math.Sin(
            2 * Math.PI * hz * i / rate)); // Right stays silent.
    return data;
}
static double LeftRms(float[] data)
{
    double sum = 0;
    int count = 0;
    for (int i = rate / 5 * channels; i < data.Length; i += channels)
    {
        sum += data[i] * data[i];
        count++;
    }
    return Math.Sqrt(sum / count);
}

var bypass = new HostEqualizer(rate, channels);
var untouched = Tone(1000);
var original = (float[])untouched.Clone();
bypass.SetGains(0, 8, 0);
bypass.Process(untouched, 0, untouched.Length);
Check(untouched.SequenceEqual(original), "Disabled host EQ must be bit-exact.");
bypass.SetEnabled(true);
bypass.SetEnabled(false);
bypass.Process(untouched, 0, untouched.Length);
Check(untouched.SequenceEqual(original), "Disabled EQ after toggling must be bit-exact.");

var eq = new HostEqualizer(rate, channels);
eq.SetGains(0, 6, 0);
eq.SetEnabled(true);
var bass = Tone(100);
eq.Process(bass, 0, bass.Length);
eq.SetEnabled(false);
eq.SetEnabled(true);
var mids = Tone(1000);
eq.Process(mids, 0, mids.Length);
double ratio = LeftRms(mids) / LeftRms(bass);
Check(ratio > 1.65 && ratio < 2.3, $"1 kHz boost not frequency-selective: {ratio:F3}.");
Check(mids.Where((_, i) => i % 2 == 1).All(x => x == 0),
    "Processing left must not leak into silent right channel.");
Check(mids.All(float.IsFinite), "Processing must not create NaN or infinity.");

var whole = Tone(1000);
var chunks = (float[])whole.Clone();
var first = new HostEqualizer(rate, channels);
var second = new HostEqualizer(rate, channels);
first.SetGains(2, 4, -3);
second.SetGains(2, 4, -3);
first.SetEnabled(true);
second.SetEnabled(true);
first.Process(whole, 0, whole.Length);
second.Process(chunks, 0, 101); // Deliberately split a stereo frame.
second.Process(chunks, 101, 903);
second.Process(chunks, 1004, chunks.Length - 1004);
Check(whole.SequenceEqual(chunks), "Stream fragment boundaries changed EQ output.");

var bad = new HostEqualizer(rate, channels);
foreach (double gain in new[] { double.NaN, double.PositiveInfinity, 10.01, -10.01 })
{
    bool rejected = false;
    try { bad.SetGains(gain, 0, 0); }
    catch (ArgumentOutOfRangeException) { rejected = true; }
    Check(rejected, "Unsafe gain was accepted.");
}
foreach (int invalidRate in new[] { 0, 7999, 192001 })
{
    bool rejected = false;
    try { _ = new HostEqualizer(invalidRate, channels); }
    catch (ArgumentOutOfRangeException) { rejected = true; }
    Check(rejected, "Unsafe sample rate was accepted.");
}
var clipped = new float[] { float.NaN, float.PositiveInfinity, 100f, -100f };
bad.SetEnabled(true);
bad.Process(clipped, 0, clipped.Length);
Check(clipped.All(x => float.IsFinite(x) && x >= -1 && x <= 1),
    "Nonfinite or unbounded PCM passed into output.");

Console.WriteLine("OpenBose.Audio PASS: bit-exact bypass, band response, stereo,");
Console.WriteLine("fragment invariance, range validation and bounded output.");
