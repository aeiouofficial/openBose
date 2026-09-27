package dev.openbose.audio

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.EOFException
import java.io.InputStream
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class PcmWaveTest {
    private fun ByteArrayOutputStream.le16(n: Int) {
        write(n and 255)
        write((n ushr 8) and 255)
    }
    private fun ByteArrayOutputStream.le32(n: Int) {
        le16(n and 65535)
        le16((n ushr 16) and 65535)
    }
    private fun wave(channels: Int, samples: ShortArray, junk: Boolean = false): ByteArray {
        val pcm = ByteArrayOutputStream()
        for (sample in samples) pcm.le16(sample.toInt())
        val extra = if (junk) 10 else 0
        return ByteArrayOutputStream().apply {
            write("RIFF".toByteArray())
            le32(36 + extra + pcm.size())
            write("WAVE".toByteArray())
            if (junk) {
                write("JUNK".toByteArray())
                le32(1)
                write(7)
                write(0)
            }
            write("fmt ".toByteArray())
            le32(16)
            le16(1)
            le16(channels)
            le32(48000)
            le32(48000 * channels * 2)
            le16(channels * 2)
            le16(16)
            write("data".toByteArray())
            le32(pcm.size())
            write(pcm.toByteArray())
        }.toByteArray()
    }

    @Test fun decodesStreamingStereoWithMetadataChunk() {
        val input = ByteArrayInputStream(wave(2,
            shortArrayOf(32767, -32768, 0, 16384, -16384, 0), junk = true))
        val data = PcmWave.open(input)
        assertEquals(48000, data.sampleRate)
        assertEquals(2, data.channels)
        assertEquals(12L, data.dataBytes)
        val first = data.readChunk(input, frames = 1)!!
        assertEquals(2, first.size)
        assertEquals(32767 / 32768f, first[0], 0f)
        assertEquals(-1f, first[1], 0f)
        val rest = data.readChunk(input)!!
        assertArrayEquals(floatArrayOf(0f, 0.5f, -0.5f, 0f), rest)
        assertNull(data.readChunk(input))
        assertEquals(0L, data.remainingBytes)
    }

    @Test fun supportsSlowInputStreamAndMono() {
        val content = wave(1, shortArrayOf(-32768, 32767, 0))
        val slow = object : InputStream() {
            var position = 0
            override fun read(): Int =
                if (position >= content.size) -1 else content[position++].toInt() and 255
            override fun read(bytes: ByteArray, off: Int, len: Int): Int {
                if (len == 0) return 0
                if (position >= content.size) return -1
                bytes[off] = content[position++]
                return 1
            }
            override fun skip(n: Long) = 0L
        }
        val fmt = PcmWave.open(slow)
        assertEquals(1, fmt.channels)
        assertEquals(3, fmt.readChunk(slow)!!.size)
        assertNull(fmt.readChunk(slow))
    }

    @Test fun rejectsMalformedHeadersAndUnsupportedFormats() {
        val valid = wave(1, shortArrayOf(1))
        val badEncoding = valid.clone().apply { this[20] = 3 }
        val badRate = valid.clone().apply { this[24] = 0; this[25] = 0;
            this[26] = 0; this[27] = 0 }
        val invalidFrame = wave(2, shortArrayOf(1))
        for (bad in listOf(valid.copyOfRange(0, 6),
            valid.clone().apply { this[0] = 'X'.code.toByte() },
            badEncoding, badRate, invalidFrame)) {
            assertThrows(Exception::class.java) { PcmWave.open(ByteArrayInputStream(bad)) }
        }
    }

    @Test fun rejectsTruncatedDataAndExcessiveMetadata() {
        val valid = wave(1, shortArrayOf(1, 2, 3))
        val truncated = valid.copyOf(valid.size - 1)
        val stream = ByteArrayInputStream(truncated)
        val data = PcmWave.open(stream)
        assertThrows(EOFException::class.java) { data.readChunk(stream) }
        val oversized = valid.clone().apply {
            // fmt size is at index 16, cannot consume beyond RIFF declared length.
            this[16] = 0xFF.toByte()
            this[17] = 0xFF.toByte()
            this[18] = 0xFF.toByte()
            this[19] = 0x7F
        }
        assertThrows(IllegalArgumentException::class.java) {
            PcmWave.open(ByteArrayInputStream(oversized))
        }
    }
}
