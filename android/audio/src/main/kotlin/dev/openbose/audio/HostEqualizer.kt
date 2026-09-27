package dev.openbose.audio

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * Temporary app-owned float PCM EQ. Never writes a Bose setting or changes
 * the Bluetooth codec. Interleaved channel continuity survives split buffers.
 */
class HostEqualizer(val sampleRate: Int, val channels: Int) {
    init {
        require(sampleRate in 8000..192000) { "Unsupported sample rate" }
        require(channels in 1..8) { "Unsupported channel count" }
    }

    private var enabled = false
    private var bassDb = 0.0
    private var midDb = 0.0
    private var trebleDb = 0.0
    private var headroom = 1.0
    private var currentChannel = 0
    private var filters = Array(channels) { arrayOfNulls<Biquad>(3) }

    @Synchronized
    fun configure(bass: Double, mid: Double, treble: Double, active: Boolean) {
        require(listOf(bass, mid, treble).all { it.isFinite() && it in -10.0..10.0 }) {
            "Host EQ gains must be finite and within -10 to +10 dB"
        }
        if (bassDb == bass && midDb == mid && trebleDb == treble && enabled == active)
            return
        bassDb = bass
        midDb = mid
        trebleDb = treble
        enabled = active
        headroom = 10.0.pow(-max(0.0, max(bass, max(mid, treble))) / 20.0)
        filters = Array(channels) {
            arrayOf(
                if (bass != 0.0) Biquad(100.0, bass) else null,
                if (mid != 0.0) Biquad(1000.0, mid) else null,
                if (treble != 0.0) Biquad(min(8000.0, sampleRate * 0.4), treble)
                else null,
            )
        }
        currentChannel = 0
    }

    /** Bypass is bit-exact, including for unusual floating point input. */
    @Synchronized
    fun process(samples: FloatArray, offset: Int = 0, count: Int = samples.size - offset) {
        require(offset >= 0 && count >= 0 && offset <= samples.size - count)
        if (!enabled) return
        for (i in offset until offset + count) {
            var x = if (samples[i].isFinite()) samples[i].toDouble() else 0.0
            for (filter in filters[currentChannel]) {
                if (filter != null) x = filter.tick(x)
            }
            x *= headroom
            samples[i] = if (x.isFinite()) x.coerceIn(-1.0, 1.0).toFloat() else 0f
            currentChannel = (currentChannel + 1) % channels
        }
    }

    private inner class Biquad(frequency: Double, gainDb: Double) {
        private val a = 10.0.pow(gainDb / 40.0)
        private val omega = 2 * PI * frequency / sampleRate
        private val alpha = sin(omega) / 2.0
        private val cosine = cos(omega)
        private val a0 = 1 + alpha / a
        private val b0 = (1 + alpha * a) / a0
        private val b1 = (-2 * cosine) / a0
        private val b2 = (1 - alpha * a) / a0
        private val a1 = (-2 * cosine) / a0
        private val a2 = (1 - alpha / a) / a0
        private var z1 = 0.0
        private var z2 = 0.0

        fun tick(sample: Double): Double {
            val result = b0 * sample + z1
            z1 = b1 * sample - a1 * result + z2
            z2 = b2 * sample - a2 * result
            return result
        }
    }
}
