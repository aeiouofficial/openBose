using System.Globalization;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Rfcomm;
using Windows.Networking.Sockets;
using Windows.Storage.Streams;
using OpenBose.Protocol;

internal static class WinRtRfcommProbe
{
    private static async Task<byte[]> ReadProtocolListAsync(RfcommDeviceService service)
    {
        var attributes = await service.GetSdpRawAttributesAsync();
        if (!attributes.TryGetValue(0x0004, out IBuffer? raw) || raw is null)
            return Array.Empty<byte>();
        var bytes = new byte[(int)raw.Length];
        DataReader.FromBuffer(raw).ReadBytes(bytes);
        return bytes;
    }

    public static async Task PrintServicesAsync(string hexAddress)
    {
        ulong mac = ulong.Parse(hexAddress, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        using BluetoothDevice device = await BluetoothDevice.FromBluetoothAddressAsync(mac)
            ?? throw new InvalidOperationException("No Bluetooth Classic device at that address.");
        var result = await device.GetRfcommServicesAsync(BluetoothCacheMode.Uncached);
        Console.WriteLine($"RFCOMM discovery: {result.Error}; service count: {result.Services.Count}");
        foreach (RfcommDeviceService service in result.Services)
        {
            using (service)
            {
                // SDP attribute 0x0004 = ProtocolDescriptorList (includes RFCOMM channel).
                // Avoid printing opaque Windows service strings containing private MACs.
                byte[] protocol = await ReadProtocolListAsync(service);
                int? channel = SdpRfcommChannel.Parse(protocol);
                string channelDisplay = channel?.ToString() ?? "unknown SDP encoding";
                Console.WriteLine($"Service {service.ServiceId.AsString()} | RFCOMM channel={channelDisplay}");
            }
        }
    }

    public static async Task<BmapPacket> QueryAsync(string hexAddress, string command)
    {
        // Fail closed before constructing Windows Bluetooth objects.
        ReadOnlyCommands.RequireAllowed(ReadOnlyCommands.BuildGet(command));
        ulong mac = ulong.Parse(hexAddress, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        using BluetoothDevice device = await BluetoothDevice.FromBluetoothAddressAsync(mac)
            ?? throw new InvalidOperationException("No paired Bluetooth Classic device at that address.");

        var result = await device.GetRfcommServicesAsync(BluetoothCacheMode.Uncached);
        if (result.Error != BluetoothError.Success)
            throw new InvalidOperationException($"RFCOMM service discovery failed: {result.Error}.");

        // Windows exposes an opaque service path, not a decimal channel name.
        // Inspect SDP 0x0004, only accepting the documented NC700 channel 8.
        RfcommDeviceService? target = null;
        foreach (RfcommDeviceService service in result.Services)
        {
            int? channel = SdpRfcommChannel.Parse(await ReadProtocolListAsync(service));
            if (channel == 8) { target = service; break; }
        }
        if (target is null)
        {
            foreach (RfcommDeviceService service in result.Services) service.Dispose();
            throw new InvalidOperationException(
                "SDP does not advertise NC700 BMAP channel 8; refusing unverified vendor channels.");
        }

        try
        {
            using var socket = new StreamSocket();
            Console.WriteLine("WinRT: connecting to advertised NC700 channel 8 (GET-only)...");
            Task connect = Task.Run(async () => await socket.ConnectAsync(
                target.ConnectionHostName, target.ConnectionServiceName,
                SocketProtectionLevel.BluetoothEncryptionAllowNullAuthentication));
            try { await connect.WaitAsync(TimeSpan.FromSeconds(7)); }
            catch (TimeoutException) { socket.Dispose(); throw; }

            using Stream reader = socket.InputStream.AsStreamForRead();
            using Stream writer = socket.OutputStream.AsStreamForWrite();
            using var duplex = new WinRtDuplexStream(reader, writer);
            using var session = new BmapReadOnlyExchange(duplex);
            return await session.QueryAsync(command, TimeSpan.FromSeconds(5));
        }
        finally
        {
            foreach (RfcommDeviceService service in result.Services) service.Dispose();
        }
    }
}
