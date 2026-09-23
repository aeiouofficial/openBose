package dev.openbose.bmap

/** Accumulates fragmented RFCOMM reads without assuming one read == one frame. */
class BmapStreamDecoder {
    private val pending = ArrayList<Byte>()
    val pendingBytes: Int get() = pending.size

    fun feed(chunk: ByteArray): List<BmapPacket> {
        if (chunk.size > MAX_BUFFER - pending.size) {
            pending.clear()
            throw IllegalArgumentException("BMAP receive buffer limit exceeded")
        }
        chunk.forEach(pending::add)
        val frames = ArrayList<BmapPacket>()
        while (pending.size >= 4) {
            val length = 4 + (pending[3].toInt() and 0xFF)
            if (pending.size < length) break
            val wire = ByteArray(length) { pending[it] }
            frames.add(BmapPacket.parseExact(wire))
            pending.subList(0, length).clear()
        }
        return frames
    }

    fun reset() = pending.clear()

    companion object { const val MAX_BUFFER = 4096 }
}
