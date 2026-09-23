package dev.openbose.bmap

/**
 * Pure Kotlin BMAP frame codec: unrelated to Android's Bluetooth transport and
 * deliberately incapable of writing to hardware by itself.
 */
class BmapPacket(
    val block: Int,
    val function: Int,
    val operator: Int,
    payload: ByteArray = byteArrayOf()
) {
    private val bytes = payload.copyOf()
    val payload: ByteArray get() = bytes.copyOf()

    init {
        require((block in 0..255) && (function in 0..255) && (operator in 0..255))
        require(bytes.size <= 255)
    }

    fun toWire(): ByteArray =
        byteArrayOf(block.toByte(), function.toByte(), operator.toByte(), bytes.size.toByte()) + bytes

    companion object {
        const val GET = 0x01
        const val SETGET = 0x02
        const val STATUS = 0x03
        const val ERROR = 0x04
        const val START = 0x05

        fun parseExact(wire: ByteArray): BmapPacket {
            require(wire.size >= 4) { "Incomplete BMAP header" }
            val expected = 4 + (wire[3].toInt() and 0xFF)
            require(wire.size == expected) { "BMAP length mismatch: expected $expected, received ${wire.size}" }
            return BmapPacket(wire[0].toInt() and 0xFF, wire[1].toInt() and 0xFF,
                wire[2].toInt() and 0xFF, wire.copyOfRange(4, wire.size))
        }
    }
}
