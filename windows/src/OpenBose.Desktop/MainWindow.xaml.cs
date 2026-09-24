using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Rfcomm;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;
using OpenBose.Protocol;

namespace OpenBose.Desktop;

public partial class MainWindow : Window
{
    private bool _channelVerified;
    private bool _busy;
    public MainWindow() => InitializeComponent();

    private static bool IsNc700(string name)
    {
        string normalized = name.Replace(" ", "", StringComparison.OrdinalIgnoreCase);
        return normalized.Contains("BoseNC700", StringComparison.OrdinalIgnoreCase) ||
            normalized.Contains("BoseHeadphones700", StringComparison.OrdinalIgnoreCase) ||
            normalized.Contains("BoseNoiseCancellingHeadphones700", StringComparison.OrdinalIgnoreCase);
    }

    private bool TrySelection(out string address, out bool isTarget)
    {
        address = "";
        isTarget = false;
        if (DeviceList.SelectedItem is not ListBoxItem item || item.Tag is not string value)
            return false;
        address = value;
        isTarget = IsNc700((string)item.Content);
        return true;
    }

    private async void Refresh_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        _busy = true;
        RefreshButton.IsEnabled = false;
        DeviceList.IsEnabled = false;
        ServicesButton.IsEnabled = QueryButton.IsEnabled = false;
        _channelVerified = false;
        DeviceList.Items.Clear();
        SelectedDevice.Text = "Discovering paired Bluetooth Classic devices...";
        try
        {
            string selector = BluetoothDevice.GetDeviceSelectorFromPairingState(true);
            DeviceInformationCollection paired = await DeviceInformation.FindAllAsync(selector);
            int stale = 0;
            foreach (DeviceInformation record in paired)
            {
                try
                {
                    using BluetoothDevice? device = await BluetoothDevice.FromIdAsync(record.Id);
                    if (device is null) { stale++; continue; }
                    var name = string.IsNullOrWhiteSpace(device.Name) ? "Unnamed device" : device.Name;
                    var connected = device.ConnectionStatus == BluetoothConnectionStatus.Connected;
                    var entry = new ListBoxItem
                    {
                        Content = name + (connected ? "  • Connected" : "  • Paired"),
                        Tag = device.BluetoothAddress.ToString("X12", CultureInfo.InvariantCulture),
                        Padding = new Thickness(8),
                        Margin = new Thickness(0, 2, 0, 2)
                    };
                    DeviceList.Items.Add(entry);
                }
                catch (Exception ex) when (ex is ArgumentException or System.Runtime.InteropServices.COMException)
                {
                    stale++;
                }
            }
            Status.Text = "Paired devices: " + DeviceList.Items.Count +
                (stale > 0 ? "; skipped stale records: " + stale : "") + ". No connections opened.";
            SelectedDevice.Text = DeviceList.Items.Count == 0
                ? "No paired devices found. Pair the NC 700 in Windows Bluetooth Settings."
                : "Select your Bose NC 700 to inspect its RFCOMM services.";
        }
        catch (Exception ex)
        {
            Status.Text = "Bluetooth enumeration failed: " + ex.GetType().Name;
        }
        finally
        {
            _busy = false;
            RefreshButton.IsEnabled = true;
            DeviceList.IsEnabled = true;
        }
    }

    private void DeviceList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _channelVerified = false;
        QueryButton.IsEnabled = false;
        ServicesText.Text = "No services queried.";
        ReadResult.Text = "No BMAP request sent.";
        if (TrySelection(out _, out bool isTarget))
        {
            SelectedDevice.Text = isTarget
                ? "NC 700 candidate selected. Inspect SDP before enabling any reads."
                : "This paired device is not identified as NC 700; BMAP reads remain disabled.";
            ServicesButton.IsEnabled = !_busy;
        }
        else ServicesButton.IsEnabled = false;
    }

    private async void Services_Click(object sender, RoutedEventArgs e)
    {
        if (_busy || !TrySelection(out string address, out bool isTarget)) return;
        _busy = true;
        ServicesButton.IsEnabled = QueryButton.IsEnabled = RefreshButton.IsEnabled = false;
        DeviceList.IsEnabled = false;
        _channelVerified = false;
        ServicesText.Text = "Reading published services only...";
        try
        {
            ulong mac = ulong.Parse(address, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            using BluetoothDevice device = await BluetoothDevice.FromBluetoothAddressAsync(mac)
                ?? throw new InvalidOperationException("Selected paired device not available.");
            var result = await device.GetRfcommServicesAsync(BluetoothCacheMode.Uncached);
            if (result.Error != BluetoothError.Success)
                throw new InvalidOperationException("Windows SDP discovery failed: " + result.Error);
            var lines = new List<string>();
            foreach (RfcommDeviceService service in result.Services)
            {
                using (service)
                {
                    var attrs = await service.GetSdpRawAttributesAsync();
                    int? channel = null;
                    if (attrs.TryGetValue(0x0004, out IBuffer? raw) && raw is not null)
                    {
                        byte[] protocol = new byte[(int)raw.Length];
                        DataReader.FromBuffer(raw).ReadBytes(protocol);
                        channel = SdpRfcommChannel.Parse(protocol);
                    }
                    lines.Add(service.ServiceId.AsString() + "  |  channel " +
                        (channel?.ToString(CultureInfo.InvariantCulture) ?? "?"));
                    if (channel == 8) _channelVerified = true;
                }
            }
            ServicesText.Text = lines.Count == 0
                ? "No RFCOMM services advertised." : string.Join(Environment.NewLine, lines);
            QueryButton.IsEnabled = _channelVerified && isTarget;
            Status.Text = QueryButton.IsEnabled
                ? "NC 700 candidate advertises channel 8. Allowlisted reads can be attempted."
                : "No validated NC 700 channel 8; no BMAP requests sent.";
        }
        catch (Exception ex)
        {
            ServicesText.Text = "Service inspection failed: " + ex.GetType().Name;
            Status.Text = "No BMAP command sent.";
        }
        finally
        {
            _busy = false;
            ServicesButton.IsEnabled = TrySelection(out _, out _);
            RefreshButton.IsEnabled = true;
            DeviceList.IsEnabled = true;
        }
    }

    private async void Query_Click(object sender, RoutedEventArgs e)
    {
        if (_busy || !_channelVerified || !TrySelection(out string address, out bool isTarget) ||
            !isTarget || CommandList.SelectedItem is not ComboBoxItem choice ||
            choice.Tag is not string command) return;
        byte[] request = ReadOnlyCommands.BuildGet(command);
        ReadOnlyCommands.RequireAllowed(request);
        _busy = true;
        QueryButton.IsEnabled = ServicesButton.IsEnabled = RefreshButton.IsEnabled = false;
        DeviceList.IsEnabled = false;
        ReadResult.Text = "Reading an allowlisted BMAP value...";
        try
        {
            BmapPacket answer = await global::WinRtRfcommProbe.QueryAsync(address, command);
            ReadResult.Text = "Block " + answer.Block.ToString("X2", CultureInfo.InvariantCulture) +
                " / function " + answer.Function.ToString("X2", CultureInfo.InvariantCulture) +
                " / op " + answer.Operator.ToString("X2", CultureInfo.InvariantCulture) +
                " / bytes " + Convert.ToHexString(answer.Payload.Span);
            Status.Text = "Read completed. No settings or firmware writes sent.";
        }
        catch (Exception ex)
        {
            ReadResult.Text = "Read failed: " + ex.GetType().Name +
                ". Verify the actual channel and paired state; no writes were sent.";
            Status.Text = "Read-only diagnostics remain active.";
        }
        finally
        {
            _busy = false;
            RefreshButton.IsEnabled = ServicesButton.IsEnabled = true;
            DeviceList.IsEnabled = true;
            QueryButton.IsEnabled = _channelVerified && TrySelection(out _, out isTarget) && isTarget;
        }
    }
}
