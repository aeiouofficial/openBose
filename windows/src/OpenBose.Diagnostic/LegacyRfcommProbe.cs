using InTheHand.Net;
using InTheHand.Net.Bluetooth;
using InTheHand.Net.Sockets;
using OpenBose.Protocol;

internal static class LegacyRfcommProbe
{
    // Explicit opt-in fallback for NC700 research. Never attempt unknown channels.
    public static async Task<BmapPacket> QueryAsync(string addressText, string command)
    {
        ReadOnlyCommands.RequireAllowed(ReadOnlyCommands.BuildGet(command));
        BluetoothAddress address = BluetoothAddress.Parse(addressText);
        using var client = new BluetoothClient();
        var endpoint = new BluetoothEndPoint(address, BluetoothService.SerialPort, 8);
        Console.WriteLine("Legacy 32feet: connecting to known NC700 RFCOMM channel 8...");
        Task connect = Task.Run(() => client.Connect(endpoint));
        try { await connect.WaitAsync(TimeSpan.FromSeconds(7)); }
        catch (TimeoutException)
        {
            client.Dispose();
            throw new TimeoutException("Legacy RFCOMM connection timed out without sending a BMAP command.");
        }
        using Stream stream = client.GetStream();
        using var exchange = new BmapReadOnlyExchange(stream);
        return await exchange.QueryAsync(command, TimeSpan.FromSeconds(5));
    }
}
