package dev.openbose.bmap

/** No raw send API. The real Bluetooth transport must also call requireAllowed. */
object ReadOnlyCommands {
    private val commands: Map<String, Pair<Int, Int>> = mapOf(
        "bmap_version" to (0 to 1),
        "function_blocks" to (0 to 2),
        "product_id" to (0 to 3),
        "firmware_version" to (0 to 5),
        "noise_control" to (1 to 5),
        "equalizer" to (1 to 7),
        "battery" to (2 to 2),
    )
    val names: Set<String> get() = commands.keys

    fun buildGet(name: String): ByteArray {
        val address = commands[name] ?: error("Unapproved BMAP read: $name")
        return BmapPacket(address.first, address.second, BmapPacket.GET).toWire()
    }

    fun requireAllowed(wire: ByteArray) {
        val packet = BmapPacket.parseExact(wire)
        if (packet.operator != BmapPacket.GET || packet.payload.isNotEmpty() ||
            !commands.values.contains(packet.block to packet.function)
        ) throw SecurityException("Only allowlisted zero-payload NC700 GETs are permitted")
    }
}
