package dev.openbose.audio

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

class HostEqualizerTest {
    private fun tone(hz: Int, frames: Int = 48000): FloatArray =
        FloatArray(frames * 2) { index ->
            if (index % 2 == 1) 0f
            else (0.1 * sin(2 * PI * hz * (index / 2) / 48000.0)).toFloat()
        }

    private fun leftRms(samples: FloatArray): Double {
        val first = 48000 / 5 * 2
        val sum = (first until samples.size step 2).sumOf {
            samples[it].toDouble() * samples[it]
        }
        return sqrt(sum / ((samples.size - first) / 2))
    }

    @Test fun exactBypassAndStateToggle() {
        val input = tone(1000)
        val expected = input.clone()
        val eq = HostEqualizer(48000, 2)
        eq.configure(0.0, 8.0, 0.0, false)
        eq.process(input)
        assertArrayEquals(expected, input)
        eq.configure(0.0, 8.0, 0.0, true)
        eq.configure(0.0, 8.0, 0.0, false)
        eq.process(input)
        assertArrayEquals(expected, input)
    }

    @Test fun peakedFrequencyResponseAndChannelSeparation() {
        val eq = HostEqualizer(48000, 2)
        eq.configure(0.0, 6.0, 0.0, true)
        val bass = tone(100)
        eq.process(bass)
        eq.configure(0.0, 6.0, 0.0, false)
        eq.configure(0.0, 6.0, 0.0, true)
        val mid = tone(1000)
        eq.process(mid)
        val ratio = leftRms(mid) / leftRms(bass)
        assertTrue(ratio in 1.65..2.3, "Expected 1kHz boost, ratio=$ratio")
        assertTrue(mid.indices.filter { it % 2 == 1 }.all { mid[it] == 0f })
    }

    @Test fun splitBuffersPreserveFilterState() {
        val original = tone(1000)
        val whole = original.clone()
        val split = original.clone()
        val a = HostEqualizer(48000, 2)
        val b = HostEqualizer(48000, 2)
        a.configure(2.0, 4.0, -3.0, true)
        b.configure(2.0, 4.0, -3.0, true)
        a.process(whole)
        b.process(split, 0, 101)
        b.process(split, 101, 903)
        b.process(split, 1004, split.size - 1004)
        assertArrayEquals(whole, split)
    }

    @Test fun rejectsUnsafeInputsAndBoundsOutput() {
        for (rate in listOf(0, 7999, 192001)) {
            assertThrows(IllegalArgumentException::class.java) { HostEqualizer(rate, 2) }
        }
        for (channels in listOf(0, 9)) {
            assertThrows(IllegalArgumentException::class.java) { HostEqualizer(48000, channels) }
        }
        val eq = HostEqualizer(48000, 2)
        for (bad in listOf(-10.01, 10.01, Double.NaN,
            Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY)) {
            assertThrows(IllegalArgumentException::class.java) {
                eq.configure(bad, 0.0, 0.0, true)
            }
        }
        assertThrows(IllegalArgumentException::class.java) { eq.process(FloatArray(2), 2, 1) }
        eq.configure(10.0, 0.0, 0.0, true)
        val extreme = floatArrayOf(Float.NaN, Float.POSITIVE_INFINITY, 100f, -100f)
        eq.process(extreme)
        assertTrue(extreme.all { it.isFinite() && it in -1f..1f })
    }
}
