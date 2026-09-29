package dev.openbose.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
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
        fun label(textValue: CharSequence, size: Float = 15f): TextView =
            TextView(this).apply {
                text = textValue
                textSize = size
                setPadding(0, margin / 3, 0, margin / 3)
            }

        page.addView(label(getString(R.string.host_eq_title), 24f))
        page.addView(label(getString(R.string.host_eq_description), 14f))
        status = label(
            if (selectedWav == null) getString(R.string.choose_wav_begin)
            else getString(R.string.wav_selection_restored),
            14f,
        ).also {
            it.setTextIsSelectable(true)
            it.accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
            page.addView(it)
        }
        page.addView(Button(this).apply {
            text = getString(R.string.choose_wav_file)
            setOnClickListener {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "audio/*"
                }
                @Suppress("DEPRECATION")
                startActivityForResult(intent, pickerCode)
            }
        })

        val actions = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        actions.addView(Button(this).apply {
            text = getString(R.string.play_resume)
            setOnClickListener {
                val uri = selectedWav
                if (uri == null) status.text = getString(R.string.choose_wav_first)
                else player.play(uri)
            }
        })
        actions.addView(Button(this).apply {
            text = getString(R.string.pause)
            setOnClickListener { player.pause() }
        })
        actions.addView(Button(this).apply {
            text = getString(R.string.stop)
            setOnClickListener { player.stop() }
        })
        page.addView(actions)
        page.addView(label(getString(R.string.host_eq_heading)))

        val controlList = mutableListOf<SeekBar>()
        val bandNames = listOf(
            getString(R.string.band_bass),
            getString(R.string.band_mid),
            getString(R.string.band_treble),
        )
        for (band in bandNames) {
            val index = controlList.size
            val saved = savedGains?.getOrNull(index)?.coerceIn(0, 20) ?: 10
            val initialDb = saved - 10
            val value = label(getString(R.string.eq_band_value, band, initialDb), 14f)
            val seek = SeekBar(this).apply {
                max = 20
                progress = saved
                contentDescription = getString(
                    R.string.eq_band_accessibility, band, initialDb
                )
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(
                        control: SeekBar?,
                        position: Int,
                        fromUser: Boolean,
                    ) {
                        val db = position - 10
                        value.text = getString(R.string.eq_band_value, band, db)
                        control?.contentDescription = getString(
                            R.string.eq_band_accessibility, band, db
                        )
                    }
                    override fun onStartTrackingTouch(control: SeekBar?) = Unit
                    override fun onStopTrackingTouch(control: SeekBar?) = Unit
                })
            }
            controlList.add(seek)
            page.addView(value)
            page.addView(seek)
        }

        sliders = controlList
        enabled = CheckBox(this).apply {
            text = getString(R.string.enable_host_eq)
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
            text = getString(R.string.apply_bypass_host_eq)
            setOnClickListener {
                player.setEqualizer(
                    (sliders[0].progress - 10).toDouble(),
                    (sliders[1].progress - 10).toDouble(),
                    (sliders[2].progress - 10).toDouble(),
                    enabled.isChecked,
                )
                status.text = if (enabled.isChecked)
                    getString(R.string.host_eq_enabled_status)
                else getString(R.string.host_eq_bypassed_status)
            }
        })
        page.addView(label(getString(R.string.host_eq_format_note), 13f))
        setContentView(ScrollView(this).apply { addView(page) })
    }

    @Deprecated("Used for the platform document picker without AndroidX dependencies")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickerCode || resultCode != RESULT_OK) return
        selectedWav = data?.data
        status.text = if (selectedWav != null) getString(R.string.file_selected)
        else getString(R.string.no_file_selected)
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
