package dev.openbose.audio

import java.io.EOFException
import java.io.InputStream
import kotlin.math.min

/** Streaming RIFF PCM16 decoder; never loads the user's full file into memory. */
object PcmWave {
    private const val MAX_HEADER = 1_048_576L
    private fun word(bytes: ByteArray, start: Int): Int =
        (bytes[start].toInt() and 255) or ((bytes[start + 1].toInt() and 255) shl 8)

    private fun dword(bytes: ByteArray, start: Int): Long =
        word(bytes, start).toLong() or (word(bytes, start + 2).toLong() shl 16)

    private fun InputStream.exact(count: Int): ByteArray {
        val result = ByteArray(count)
        var offset = 0
        while (offset < count) {
            val n = read(result, offset, count - offset)
            if (n < 0) throw EOFException("Truncated WAV file")
            if (n == 0) {
                val one = read()
                if (one < 0) throw EOFException("Truncated WAV file")
                result[offset++] = one.toByte()
            } else offset += n
        }
        return result
    }

    private fun InputStream.skipExact(count: Long) {
        var left = count
        while (left > 0) {
            val skipped = skip(left)
            if (skipped > 0) left -= skipped
            else {
                if (read() == -1) throw EOFException("Truncated WAV chunk")
                left--
            }
        }
    }

    class Data internal constructor(
        val sampleRate: Int,
        val channels: Int,
        val dataBytes: Long,
    ) {
        private val bytesPerFrame = channels * 2
        var remainingBytes: Long = dataBytes
            private set

        /** Return the next bounded interleaved float chunk, or null at EOF. */
        fun readChunk(input: InputStream, frames: Int = 2048): FloatArray? {
            require(frames in 1..8192)
            if (remainingBytes == 0L) return null
            val toRead = min(remainingBytes, frames.toLong() * bytesPerFrame).toInt()
            val bytes = input.exact(toRead)
            remainingBytes -= toRead
            return FloatArray(bytes.size / 2) { i ->
                val low = bytes[i * 2].toInt() and 255
                val high = bytes[i * 2 + 1].toInt() and 255
                (low or (high shl 8)).toShort().toInt() / 32768f
            }
        }
    }

    /** Leaves the input stream positioned at the PCM data bytes. */
    fun open(input: InputStream): Data {
        val riff = input.exact(12)
        require(riff.copyOfRange(0, 4).decodeToString() == "RIFF" &&
            riff.copyOfRange(8, 12).decodeToString() == "WAVE") {
            "Only standard RIFF/WAVE files are supported"
        }
        var remainingRiff = dword(riff, 4) - 4
        require(remainingRiff >= 8) { "Invalid RIFF length" }
        var scanned = 12L
        var format: Pair<Int, Int>? = null

        while (remainingRiff >= 8 && scanned <= MAX_HEADER) {
            val chunk = input.exact(8)
            val id = chunk.copyOfRange(0, 4).decodeToString()
            val size = dword(chunk, 4)
            val padded = size + (size and 1L)
            remainingRiff -= 8
            scanned += 8
            require(padded <= remainingRiff) { "WAV chunk exceeds RIFF length" }
            if (id == "data") {
                val info = format ?: throw IllegalArgumentException("Missing fmt chunk before data")
                require(size % (info.second * 2L) == 0L) {
                    "PCM data must contain whole sample frames"
                }
                return Data(info.first, info.second, size)
            }
            require(padded <= MAX_HEADER - scanned) { "WAV metadata header is too large" }
            if (id == "fmt ") {
                require(format == null) { "Duplicate WAV fmt chunk" }
                require(size in 16L..64L) { "Unsupported WAV fmt chunk length" }
                val bytes = input.exact(size.toInt())
                val encoding = word(bytes, 0)
                val channels = word(bytes, 2)
                val rate = dword(bytes, 4)
                val byteRate = dword(bytes, 8)
                val align = word(bytes, 12)
                val bits = word(bytes, 14)
                require(encoding == 1 && channels in 1..2 &&
                    rate in 8000L..192000L && bits == 16 &&
                    align == channels * 2 &&
                    byteRate == rate * align) {
                    "Only mono/stereo PCM16 WAV with valid sample metadata is supported"
                }
                format = rate.toInt() to channels
                if (size and 1L != 0L) input.skipExact(1)
            } else input.skipExact(padded)
            remainingRiff -= padded
            scanned += padded
        }
        throw IllegalArgumentException("Missing or invalid WAV data chunk")
    }
}
