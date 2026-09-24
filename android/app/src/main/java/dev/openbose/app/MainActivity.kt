package dev.openbose.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.graphics.Typeface
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Paired-device metadata only. No RFCOMM packets or firmware/settings writes. */
class MainActivity : Activity() {
    private lateinit var status: TextView
    private val permissionRequest = 700

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (20 * resources.displayMetrics.density).toInt()
        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
        }
        val title = TextView(this).apply {
            text = "OpenBose"
            textSize = 28f
            setTypeface(typeface, Typeface.BOLD)
        }
        val description = TextView(this).apply {
            text = "NC700 research | paired-device diagnostics\n" +
                "Read-only baseline. No firmware changes, settings writes or codec activation."
            textSize = 15f
            setPadding(0, padding / 2, 0, padding / 2)
        }
        status = TextView(this).apply {
            text = "Tap below to request Bluetooth permission and list paired devices."
            textSize = 15f
            setTextIsSelectable(true)
        }
        val refresh = Button(this).apply {
            text = "Show paired Bluetooth devices"
            setOnClickListener { requestOrRefresh() }
        }
        val notes = TextView(this).apply {
            text = "\nAndroid's codec choices do not prove headphone compatibility. " +
                "Actual NC700 codec advertisements require an AVDTP capture."
            textSize = 13f
        }
        page.addView(title)
        page.addView(description)
        page.addView(refresh)
        page.addView(status)
        page.addView(notes)
        val scroll = ScrollView(this)
        scroll.addView(page)
        setContentView(scroll)
    }

    private fun requestOrRefresh() {
        if (Build.VERSION.SDK_INT >= 31 &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), permissionRequest)
            return
        }
        refreshPaired()
    }

    @SuppressLint("MissingPermission")
    private fun refreshPaired() {
        try {
            val manager = getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter = manager?.adapter
            if (adapter == null) { status.text = "No Bluetooth adapter."; return }
            if (!adapter.isEnabled) { status.text = "Enable Bluetooth in Android settings."; return }
            val devices = adapter.bondedDevices.sortedWith(
                compareByDescending<android.bluetooth.BluetoothDevice> {
                    it.name?.contains("Bose", ignoreCase = true) == true
                }.thenBy { it.name ?: "" }
            )
            status.text = if (devices.isEmpty()) {
                "No paired devices. Pair the NC700 in Android settings first."
            } else buildString {
                append("Paired devices: "); append(devices.size); append("\n")
                for (device in devices) {
                    append("\n"); append(device.name ?: "Unnamed Bluetooth device"); append("\n")
                    val profiles = device.uuids?.map { it.uuid.toString() }.orEmpty()
                    if (profiles.isEmpty()) append("  No cached UUIDs; do not infer codec support.\n")
                    else append("  Cached service UUIDs:\n" +
                        profiles.joinToString("\n") { "  " + it } + "\n")
                }
            }
        } catch (ex: SecurityException) {
            status.text = "Bluetooth permission missing or revoked. Grant it and retry."
        } catch (ex: Exception) {
            status.text = "Discovery failed: " + ex.javaClass.simpleName
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequest) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) refreshPaired()
        else status.text = "Bluetooth permission denied; no connection attempted."
    }
}
