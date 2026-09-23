using InTheHand.Net;
using InTheHand.Net.Bluetooth;
using InTheHand.Net.Sockets;
using OpenBose.Protocol;

static void PrintUsage()
{
    Console.WriteLine("OpenBose NC700 read-only Windows RFCOMM diagnostic");
    Console.WriteLine("  --help                        Show instructions; no device access");
    Console.WriteLine("  --list                        Enumerate paired Bluetooth devices only");
    Console.WriteLine("  --read <name> --address <MAC>        WinRT RFCOMM discovery then one allowed GET");
    Console.WriteLine("  --legacy-read <name> --address <MAC> Legacy channel-8 GET (explicit opt-in)");
    Console.WriteLine("  --services show --address <MAC>     List advertised RFCOMM services; no writes");
    Console.WriteLine("Allowed reads: " + string.Join(", ", ReadOnlyCommands.Names.Order()));
    Console.WriteLine("No ANC/EQ writes, firmware operations or arbitrary raw commands.");
}

try
{
    if (args.Length == 0 || args[0] is "--help" or "-h")
    {
        PrintUsage();
        return 0;
    }

    if (args.Length == 1 && args[0] == "--list")
    {
        try
        {
            using var discoveryClient = new BluetoothClient();
            // Only cached paired devices, never a broad Bluetooth inquiry.
            BluetoothDeviceInfo[] paired = discoveryClient.PairedDevices.ToArray();
            foreach (BluetoothDeviceInfo device in paired)
                Console.WriteLine($"{device.DeviceName} | {device.DeviceAddress} | paired={device.Authenticated}");
            if (paired.Length == 0) Console.WriteLine("No paired Bluetooth Classic devices returned.");
            return 0;
        }
        catch (Exception ex) when (ex is AggregateException or PlatformNotSupportedException)
        {
            Console.Error.WriteLine("Legacy paired-device enumeration failed; trying the Windows Runtime API.");
            try
            {
                int count = await WinRtPairedDevices.PrintAsync();
                if (count == 0) Console.WriteLine("WinRT reported no paired Bluetooth Classic devices.");
                return 0;
            }
            catch (Exception fallbackEx)
            {
                Console.Error.WriteLine($"Paired-device enumeration unavailable: {fallbackEx.GetType().Name}. " +
                    "Use Windows Bluetooth settings to identify the NC700 and the explicit --read command.");
                return 3;
            }
        }
    }

    if (args.Length != 4 ||
        (args[0] is not ("--read" or "--legacy-read" or "--services")) ||
        args[2] != "--address")
    {
        PrintUsage();
        return 2;
    }

    // Validate both operation and address before any connection or service lookup.
    BluetoothAddress address = BluetoothAddress.Parse(args[3]);
    if (args[0] == "--services")
    {
        if (args[1] != "show") { PrintUsage(); return 2; }
        await WinRtRfcommProbe.PrintServicesAsync(address.ToString());
        return 0;
    }
    string command = args[1];
    ReadOnlyCommands.RequireAllowed(ReadOnlyCommands.BuildGet(command));
    BmapPacket response = args[0] == "--legacy-read"
        ? await LegacyRfcommProbe.QueryAsync(address.ToString(), command)
        : await WinRtRfcommProbe.QueryAsync(address.ToString(), command);
    Console.WriteLine($"RX [{response.Block:X2}:{response.Function:X2}] op={response.Operator:X2} " +
        $"payload={Convert.ToHexString(response.Payload.Span)}");

    if (response.Operator == BmapPacket.ErrorOperator)
    {
        Console.Error.WriteLine("Headphones reported a BMAP error; do not infer unsupported codecs.");
        return 4;
    }
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"{ex.GetType().Name}: {ex.Message}");
    return 1;
}
