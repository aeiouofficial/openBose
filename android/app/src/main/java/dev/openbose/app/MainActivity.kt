package dev.openbose.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.View
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
        page.addView(TextView(this).apply {
            text = getString(R.string.app_name)
            textSize = 28f
            setTypeface(typeface, Typeface.BOLD)
        })
        page.addView(TextView(this).apply {
            text = getString(R.string.main_description)
            textSize = 15f
            setPadding(0, padding / 2, 0, padding / 2)
        })
        status = TextView(this).apply {
            text = getString(R.string.main_permission_prompt)
            textSize = 15f
            setTextIsSelectable(true)
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        page.addView(Button(this).apply {
            text = getString(R.string.show_paired_devices)
            setOnClickListener { requestOrRefresh() }
        })
        page.addView(Button(this).apply {
            text = getString(R.string.open_host_eq)
            setOnClickListener {
                startActivity(Intent(this@MainActivity, HostAudioActivity::class.java))
            }
        })
        page.addView(status)
        page.addView(TextView(this).apply {
            text = getString(R.string.codec_evidence_note)
            textSize = 13f
        })
        setContentView(ScrollView(this).apply { addView(page) })
    }

    private fun requestOrRefresh() {
        if (Build.VERSION.SDK_INT >= 31 &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) !=
            PackageManager.PERMISSION_GRANTED
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
            if (adapter == null) {
                status.text = getString(R.string.no_bluetooth_adapter)
                return
            }
            if (!adapter.isEnabled) {
                status.text = getString(R.string.enable_bluetooth)
                return
            }
            val devices = adapter.bondedDevices.sortedWith(
                compareByDescending<android.bluetooth.BluetoothDevice> {
                    it.name?.contains("Bose", ignoreCase = true) == true
                }.thenBy { it.name ?: "" }
            )
            status.text = if (devices.isEmpty()) {
                getString(R.string.no_paired_devices)
            } else buildString {
                append(resources.getQuantityString(
                    R.plurals.paired_devices_count, devices.size, devices.size
                ))
                append("\n")
                for (device in devices) {
                    append("\n")
                    append(device.name ?: getString(R.string.unnamed_bluetooth_device))
                    append("\n")
                    val profiles = device.uuids?.map { it.uuid.toString() }.orEmpty()
                    if (profiles.isEmpty()) {
                        append("  ")
                        append(getString(R.string.no_cached_uuids))
                        append("\n")
                    } else {
                        append("  ")
                        append(getString(R.string.cached_service_uuids))
                        append("\n")
                        profiles.forEach {
                            append("  ")
                            append(it)
                            append("\n")
                        }
                    }
                }
            }
        } catch (_: SecurityException) {
            status.text = getString(R.string.bluetooth_permission_missing)
        } catch (ex: Exception) {
            status.text = getString(R.string.bluetooth_discovery_failed, ex.javaClass.simpleName)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequest) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) refreshPaired()
        else status.text = getString(R.string.bluetooth_permission_denied)
    }
}
