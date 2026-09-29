package dev.openbose.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioFocusRequest
import android.media.AudioManager
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
    private val mediaAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
        .setAudioAttributes(mediaAttributes)
        .setOnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS -> stop()
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> pause()
                // Resume after a call only when the user explicitly requests it.
            }
        }
        .build()

    fun setEqualizer(bass: Double, mid: Double, treble: Double, active: Boolean) {
        require(listOf(bass, mid, treble).all { it.isFinite() && it in -10.0..10.0 })
        gains = doubleArrayOf(bass, mid, treble)
        enabled = active
        current?.eq?.configure(bass, mid, treble, active)
        notifyCurrent(current, if (active) context.getString(R.string.player_eq_enabled)
            else context.getString(R.string.player_eq_bypassed))
    }

    fun play(uri: Uri) {
        val previous = current
        if (previous != null && previous.uri == uri && previous.paused.get() &&
            !previous.cancelled.get()) {
            if (audioManager.requestAudioFocus(focusRequest) !=
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                notifyCurrent(previous, context.getString(R.string.audio_focus_unavailable_paused))
                return
            }
            previous.paused.set(false)
            try { previous.track?.play() } catch (_: IllegalStateException) { }
            notifyCurrent(previous, context.getString(R.string.wav_playback_resumed))
            return
        }
        stop()
        if (audioManager.requestAudioFocus(focusRequest) !=
            AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            notify(context.getString(R.string.audio_focus_unavailable))
            return
        }
        val session = Session(uri)
        current = session
        executor.execute { run(session) }
    }

    fun pause() {
        val session = current ?: return
        session.paused.set(true)
        try { session.track?.pause() } catch (_: IllegalStateException) { }
        notifyCurrent(session, context.getString(R.string.wav_paused))
    }

    fun stop() {
        val session = current ?: return
        current = null
        session.cancelled.set(true)
        // Stopping the stream also releases a worker blocked in WRITE_BLOCKING.
        try { session.track?.stop() } catch (_: IllegalStateException) { }
        try { session.track?.flush() } catch (_: IllegalStateException) { }
        audioManager.abandonAudioFocusRequest(focusRequest)
        notify(context.getString(R.string.wav_stopped))
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
                ?: throw IllegalArgumentException(context.getString(R.string.selected_file_open_failed))
            input.use { stream ->
                val wav = PcmWave.open(stream)
                if (session.cancelled.get()) return
                val channelMask = if (wav.channels == 1)
                    AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
                val size = AudioTrack.getMinBufferSize(
                    wav.sampleRate, channelMask, AudioFormat.ENCODING_PCM_FLOAT,
                )
                require(size > 0) { context.getString(R.string.float_pcm_unsupported) }
                audio = AudioTrack.Builder()
                    .setAudioAttributes(mediaAttributes)
                    .setAudioFormat(AudioFormat.Builder()
                        .setSampleRate(wav.sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .setChannelMask(channelMask)
                        .build())
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setBufferSizeInBytes(maxOf(size, 16384))
                    .build()
                require(audio?.state == AudioTrack.STATE_INITIALIZED) {
                    context.getString(R.string.android_audio_init_failed)
                }
                session.track = audio
                val eq = HostEqualizer(wav.sampleRate, wav.channels)
                session.eq = eq
                val snapshot = gains
                eq.configure(snapshot[0], snapshot[1], snapshot[2], enabled)
                audio?.play()
                notifyCurrent(session, context.getString(R.string.wav_playing))
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
                        if (count <= 0) throw IllegalStateException(
                            context.getString(R.string.android_audio_output_failed)
                        )
                        offset += count
                    }
                }
                // Drain the final queued buffer rather than cutting off the WAV tail.
                val totalFrames = wav.dataBytes / (wav.channels * 2L)
                var deadline = SystemClock.elapsedRealtime() + 10_000L
                while (!session.cancelled.get() &&
                    ((audio!!.playbackHeadPosition.toLong()) and 0xFFFF_FFFFL) < totalFrames) {
                    if (session.paused.get())
                        deadline = SystemClock.elapsedRealtime() + 10_000L
                    else if (SystemClock.elapsedRealtime() >= deadline) break
                    Thread.sleep(20)
                }
                notifyCurrent(session, context.getString(R.string.wav_playback_finished))
            }
        } catch (ex: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (ex: Exception) {
            if (!session.cancelled.get())
                notifyCurrent(
                    session,
                    context.getString(
                        R.string.wav_playback_stopped_error,
                        ex.message ?: ex.javaClass.simpleName,
                    ),
                )
        } finally {
            try { audio?.pause() } catch (_: Exception) { }
            try { audio?.flush() } catch (_: Exception) { }
            try { audio?.release() } catch (_: Exception) { }
            session.track = null
            session.eq = null
            if (current === session) {
                current = null
                audioManager.abandonAudioFocusRequest(focusRequest)
            }
        }
    }

    override fun close() {
        stop()
        executor.shutdownNow()
    }
}
