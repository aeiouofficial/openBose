package dev.openbose.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.SystemClock
import dev.openbose.audio.HostEqualizer
import dev.openbose.audio.PcmWave
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Only user-selected app-owned WAV playback; it does not intercept other apps
 * or send any Bluetooth/headphone setting, codec or firmware commands.
 */
internal class AndroidWavePlayer(
    private val context: Context,
    private val report: (String) -> Unit,
) : AutoCloseable {
    private val executor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "openbose-wav").apply { isDaemon = true }
    }
    private data class Session(
        val uri: Uri,
        val cancelled: AtomicBoolean = AtomicBoolean(),
        val paused: AtomicBoolean = AtomicBoolean(),
        @Volatile var track: AudioTrack? = null,
        @Volatile var eq: HostEqualizer? = null,
    )

    @Volatile private var current: Session? = null
    @Volatile private var gains = doubleArrayOf(0.0, 0.0, 0.0)
    @Volatile private var enabled = false

    fun setEqualizer(bass: Double, mid: Double, treble: Double, active: Boolean) {
        require(listOf(bass, mid, treble).all { it.isFinite() && it in -10.0..10.0 })
        gains = doubleArrayOf(bass, mid, treble)
        enabled = active
        current?.eq?.configure(bass, mid, treble, active)
        notifyCurrent(current, if (active) "Host EQ enabled for this player only."
            else "Host EQ bypassed. Headphone settings are unchanged.")
    }

    fun play(uri: Uri) {
        val previous = current
        if (previous != null && previous.uri == uri && previous.paused.get() &&
            !previous.cancelled.get()) {
            previous.paused.set(false)
            try { previous.track?.play() } catch (_: IllegalStateException) { }
            notifyCurrent(previous, "WAV playback resumed.")
            return
        }
        stop()
        val session = Session(uri)
        current = session
        executor.execute { run(session) }
    }

    fun pause() {
        val session = current ?: return
        session.paused.set(true)
        try { session.track?.pause() } catch (_: IllegalStateException) { }
        notifyCurrent(session, "Paused; playback stays inside OpenBose.")
    }

    fun stop() {
        val session = current ?: return
        current = null
        session.cancelled.set(true)
        // Stopping the stream also releases a worker blocked in WRITE_BLOCKING.
        try { session.track?.stop() } catch (_: IllegalStateException) { }
        try { session.track?.flush() } catch (_: IllegalStateException) { }
        notify("Stopped. Bose-stored EQ unchanged.")
    }

    private fun notify(message: String) = report(message)

    private fun notifyCurrent(session: Session?, message: String) {
        if (session != null && current === session && !session.cancelled.get())
            notify(message)
    }

    private fun run(session: Session) {
        var audio: AudioTrack? = null
        try {
            val input = context.contentResolver.openInputStream(session.uri)
                ?: throw IllegalArgumentException("The selected file could not be opened.")
            input.use { stream ->
                val wav = PcmWave.open(stream)
                if (session.cancelled.get()) return
                val channelMask = if (wav.channels == 1)
                    AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
                val size = AudioTrack.getMinBufferSize(
                    wav.sampleRate, channelMask, AudioFormat.ENCODING_PCM_FLOAT,
                )
                require(size > 0) { "Float PCM output not supported on this device." }
                audio = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                    .setAudioFormat(AudioFormat.Builder()
                        .setSampleRate(wav.sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .setChannelMask(channelMask)
                        .build())
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setBufferSizeInBytes(maxOf(size, 16384))
                    .build()
                require(audio?.state == AudioTrack.STATE_INITIALIZED) {
                    "Android audio output could not be initialized."
                }
                session.track = audio
                val eq = HostEqualizer(wav.sampleRate, wav.channels)
                session.eq = eq
                val snapshot = gains
                eq.configure(snapshot[0], snapshot[1], snapshot[2], enabled)
                audio?.play()
                notifyCurrent(session, "Playing WAV via Android's active output device.")
                while (!session.cancelled.get()) {
                    if (session.paused.get()) {
                        Thread.sleep(20)
                        continue
                    }
                    val chunk = wav.readChunk(stream) ?: break
                    eq.process(chunk)
                    var offset = 0
                    while (offset < chunk.size && !session.cancelled.get()) {
                        if (session.paused.get()) {
                            Thread.sleep(20)
                            continue
                        }
                        val count = audio!!.write(
                            chunk, offset, chunk.size - offset, AudioTrack.WRITE_BLOCKING)
                        if (count <= 0) throw IllegalStateException("Android audio output failed.")
                        offset += count
                    }
                }
                // Drain the final queued buffer rather than cutting off the WAV tail.
                val totalFrames = wav.dataBytes / (wav.channels * 2L)
                var deadline = SystemClock.elapsedRealtime() + 10_000L
                while (!session.cancelled.get() &&
                    ((audio!!.playbackHeadPosition.toLong()) and 0xFFFF_FFFFL) < totalFrames) {
                    if (session.paused.get()) deadline += 20L
                    else if (SystemClock.elapsedRealtime() >= deadline) break
                    Thread.sleep(20)
                }
                notifyCurrent(session, "Playback finished. No headphone settings changed.")
            }
        } catch (ex: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (ex: Exception) {
            if (!session.cancelled.get())
                notifyCurrent(session, "Playback stopped: " +
                    (ex.message ?: ex.javaClass.simpleName))
        } finally {
            try { audio?.pause() } catch (_: Exception) { }
            try { audio?.flush() } catch (_: Exception) { }
            try { audio?.release() } catch (_: Exception) { }
            session.track = null
            session.eq = null
            if (current === session) current = null
        }
    }

    override fun close() {
        stop()
        executor.shutdownNow()
    }
}
