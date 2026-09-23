using Windows.Devices.Bluetooth;
using Windows.Devices.Enumeration;

internal static class WinRtPairedDevices
{
    // Paired-only selector; no active scan and no device writes.
    public static async Task<int> PrintAsync()
    {
        string selector = BluetoothDevice.GetDeviceSelectorFromPairingState(true);
        DeviceInformationCollection infos = await DeviceInformation.FindAllAsync(selector);
        int count = 0;
        int invalid = 0;
        foreach (DeviceInformation info in infos)
        {
            try
            {
                BluetoothDevice? device = await BluetoothDevice.FromIdAsync(info.Id);
                if (device is null) { invalid++; continue; }
                using (device)
                {
                    Console.WriteLine($"{device.Name} | {device.BluetoothAddress:X12} | paired={device.DeviceInformation.Pairing.IsPaired} | connected={device.ConnectionStatus == BluetoothConnectionStatus.Connected}");
                    count++;
                }
            }
            catch (Exception ex) when (ex is ArgumentException or System.Runtime.InteropServices.COMException)
            {
                // One invalid cached PnP record must not hide other paired devices.
                invalid++;
            }
        }
        if (invalid > 0) Console.Error.WriteLine($"Skipped {invalid} stale or unsupported Bluetooth PnP records.");
        return count;
    }
}
