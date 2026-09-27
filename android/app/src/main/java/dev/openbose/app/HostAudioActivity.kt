package dev.openbose.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView

/**
 * User-selected WAV preview only. No broad storage permission, audio capture,
 * codec switching, Bose native EQ writes or background playback.
 */
class HostAudioActivity : Activity() {
    private val pickerCode = 701
    private var selectedWav: Uri? = null
    private lateinit var status: TextView
    private lateinit var player: AndroidWavePlayer
    private lateinit var enabled: CheckBox
    private lateinit var sliders: List<SeekBar>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        selectedWav = savedInstanceState?.getString("selectedWav")?.let(Uri::parse)
        val savedGains = savedInstanceState?.getIntArray("hostEqGains")
        val savedEnabled = savedInstanceState?.getBoolean("hostEqEnabled") ?: false
        player = AndroidWavePlayer(applicationContext) { message ->
            runOnUiThread {
                if (!isFinishing && !isDestroyed) status.text = message
            }
        }
        val margin = (18 * resources.displayMetrics.density).toInt()
        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(margin, margin, margin, margin)
        }
        fun label(textValue: String, size: Float = 15f): TextView =
            TextView(this).apply {
                text = textValue
                textSize = size
                setPadding(0, margin / 3, 0, margin / 3)
            }
        page.addView(label("OpenBose • Temporary phone EQ", 24f))
        page.addView(label(
            "Only affects WAV files played inside OpenBose. " +
                "Connect the NC 700 in Android Bluetooth settings to route audio to it. " +
                "Your headphone's stored EQ and Bluetooth codec remain unchanged.", 14f))
        status = label(if (selectedWav == null) "Choose a WAV file to begin."
            else "WAV selection restored. Press Play to reopen it.", 14f).also {
            it.setTextIsSelectable(true)
            page.addView(it)
        }
        page.addView(Button(this).apply {
            text = "Choose WAV file"
            setOnClickListener {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "audio/*"
                }
                @Suppress("DEPRECATION")
                startActivityForResult(intent, pickerCode)
            }
        })
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        actions.addView(Button(this).apply {
            text = "Play / Resume"
            setOnClickListener {
                val uri = selectedWav
                if (uri == null) status.text = "Choose a WAV file first."
                else player.play(uri)
            }
        })
        actions.addView(Button(this).apply {
            text = "Pause"
            setOnClickListener { player.pause() }
        })
        actions.addView(Button(this).apply {
            text = "Stop"
            setOnClickListener { player.stop() }
        })
        page.addView(actions)
        page.addView(label("Host EQ: bass / mid / treble (minus ten to plus ten dB)"))
        val controlList = mutableListOf<SeekBar>()
        for (band in listOf("Bass", "Mid", "Treble")) {
            val value = label("$band: 0 dB", 14f)
            val saved = savedGains?.getOrNull(controlList.size)?.coerceIn(0, 20) ?: 10
            val seek = SeekBar(this).apply {
                max = 20
                progress = saved
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(
                        control: SeekBar?, position: Int, fromUser: Boolean
                    ) {
                        value.text = "$band: ${position - 10} dB"
                    }
                    override fun onStartTrackingTouch(control: SeekBar?) = Unit
                    override fun onStopTrackingTouch(control: SeekBar?) = Unit
                })
            }
            value.text = "$band: ${saved - 10} dB"
            controlList.add(seek)
            page.addView(value)
            page.addView(seek)
        }
        sliders = controlList
        enabled = CheckBox(this).apply {
            text = "Enable temporary OpenBose player EQ"
            isChecked = savedEnabled
        }
        page.addView(enabled)
        if (savedInstanceState != null) {
            player.setEqualizer(
                (sliders[0].progress - 10).toDouble(),
                (sliders[1].progress - 10).toDouble(),
                (sliders[2].progress - 10).toDouble(),
                enabled.isChecked,
            )
        }
        page.addView(Button(this).apply {
            text = "Apply EQ / Bypass"
            setOnClickListener {
                player.setEqualizer(
                    (sliders[0].progress - 10).toDouble(),
                    (sliders[1].progress - 10).toDouble(),
                    (sliders[2].progress - 10).toDouble(),
                    enabled.isChecked,
                )
                status.text = if (enabled.isChecked)
                    "Host EQ enabled for OpenBose playback only."
                else "Host EQ bypassed; headphone settings unchanged."
            }
        })
        page.addView(label(
            "Only PCM16 RIFF/WAVE mono or stereo is supported. " +
                "Playback stops when you leave this screen. No other app's sound is modified.", 13f))
        setContentView(ScrollView(this).apply { addView(page) })
    }

    @Deprecated("Used for the platform document picker without AndroidX dependencies")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickerCode || resultCode != RESULT_OK) return
        selectedWav = data?.data
        status.text = if (selectedWav != null)
            "File selected. Press Play. The file is read only after you press Play."
        else "No file was selected."
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("selectedWav", selectedWav?.toString())
        outState.putIntArray("hostEqGains", sliders.map { it.progress }.toIntArray())
        outState.putBoolean("hostEqEnabled", enabled.isChecked)
        super.onSaveInstanceState(outState)
    }

    override fun onStop() {
        player.stop() // No background processing without a foreground service.
        super.onStop()
    }

    override fun onDestroy() {
        player.close()
        super.onDestroy()
    }
}
