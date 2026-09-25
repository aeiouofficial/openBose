using System.IO;
using System.Windows;
using Microsoft.Win32;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using OpenBose.Audio;

namespace OpenBose.Desktop;

public partial class MainWindow
{
    private string? _wavePath;
    private WaveFileReader? _audioReader;
    private WaveOutEvent? _audioOutput;
    private HostEqualizer? _hostEqualizer;

    private static bool IsWorkspacePath(string path)
    {
        string full = Path.GetFullPath(path);
        return full.StartsWith(@"D:\openBose\", StringComparison.OrdinalIgnoreCase);
    }

    private void BrowseWav_Click(object sender, RoutedEventArgs e)
    {
        var picker = new OpenFileDialog
        {
            Title = "Choose a WAV file inside D:\\openBose",
            InitialDirectory = @"D:\openBose",
            CheckFileExists = true,
            Multiselect = false,
            Filter = "WAV audio (*.wav)|*.wav"
        };
        if (picker.ShowDialog(this) != true) return;
        if (!IsWorkspacePath(picker.FileName) ||
            !string.Equals(Path.GetExtension(picker.FileName), ".wav",
                StringComparison.OrdinalIgnoreCase))
        {
            AudioStatus.Text = "Choose a .wav file inside D:\\openBose only.";
            return;
        }
        StopAudio();
        _wavePath = Path.GetFullPath(picker.FileName);
        AudioStatus.Text = "Ready: " + Path.GetFileName(_wavePath) +
            ". Output is your Windows default audio device.";
    }

    private void PlayWav_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (_audioOutput?.PlaybackState == PlaybackState.Paused)
            {
                _audioOutput.Play();
                AudioStatus.Text = "Playback resumed.";
                return;
            }
            if (_wavePath is null || !IsWorkspacePath(_wavePath))
                throw new InvalidOperationException("Choose a WAV file inside D:\\openBose first.");
            StopAudio();
            _audioReader = new WaveFileReader(_wavePath);
            ISampleProvider source = _audioReader.ToSampleProvider();
            _hostEqualizer = new HostEqualizer(
                source.WaveFormat.SampleRate, source.WaveFormat.Channels);
            ApplyCurrentEq();
            var filtered = new HostEqSampleProvider(source, _hostEqualizer);
            _audioOutput = new WaveOutEvent();
            _audioOutput.PlaybackStopped += AudioEnded;
            _audioOutput.Init(new SampleToWaveProvider(filtered));
            _audioOutput.Play();
            AudioStatus.Text = "Playing via Windows default device: " +
                Path.GetFileName(_wavePath) +
                ". OpenBose host EQ affects this file only.";
        }
        catch (Exception ex)
        {
            StopAudio();
            AudioStatus.Text = "Playback failed (" + ex.GetType().Name +
                "). Check WAV format and Windows default audio device.";
        }
    }

    private void PauseWav_Click(object sender, RoutedEventArgs e)
    {
        if (_audioOutput?.PlaybackState != PlaybackState.Playing) return;
        _audioOutput.Pause();
        AudioStatus.Text = "Playback paused.";
    }

    private void StopWav_Click(object sender, RoutedEventArgs e)
    {
        StopAudio();
        AudioStatus.Text = "Playback stopped. Headphone EQ unchanged.";
    }

    private void ApplyEq_Click(object sender, RoutedEventArgs e)
    {
        if (_hostEqualizer is null)
        {
            AudioStatus.Text = "Host EQ values staged; start WAV playback to hear them.";
            return;
        }
        ApplyCurrentEq();
        AudioStatus.Text = _hostEqualizer.Enabled
            ? "Temporary OpenBose-player EQ enabled. Headphone EQ unchanged."
            : "Host EQ bypassed. Headphone EQ unchanged.";
    }

    private void ApplyCurrentEq()
    {
        if (_hostEqualizer is null) return;
        _hostEqualizer.SetGains(BassSlider.Value, MidSlider.Value, TrebleSlider.Value);
        _hostEqualizer.SetEnabled(HostEqEnabled.IsChecked == true);
    }

    private void AudioEnded(object? sender, StoppedEventArgs args)
    {
        if (Dispatcher.HasShutdownStarted) return;
        _ = Dispatcher.BeginInvoke(() =>
        {
            if (!ReferenceEquals(sender, _audioOutput)) return;
            StopAudio();
            AudioStatus.Text = args.Exception is null
                ? "Playback ended. No headphone settings changed."
                : "Audio output stopped unexpectedly. Check the default output device.";
        });
    }

    private void StopAudio()
    {
        if (_audioOutput is not null)
        {
            WaveOutEvent output = _audioOutput;
            _audioOutput = null;
            output.PlaybackStopped -= AudioEnded;
            output.Stop();
            output.Dispose();
        }
        _audioReader?.Dispose();
        _audioReader = null;
        _hostEqualizer = null;
    }

    protected override void OnClosed(EventArgs e)
    {
        StopAudio();
        base.OnClosed(e);
    }
}
