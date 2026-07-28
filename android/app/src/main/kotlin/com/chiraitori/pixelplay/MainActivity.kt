package com.chiraitori.pixelplay

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.annotation.SuppressLint
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.AudioDeviceInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.RingtoneManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val discoveredBluetoothAudioDevices = linkedMapOf<String, BluetoothAudioRoute>()
    private var bluetoothDeviceEventSink: EventChannel.EventSink? = null
    private var bluetoothReceiverRegistered = false
    private var pendingMediaDeleteResult: MethodChannel.Result? = null

    private companion object {
        const val MEDIA_DELETE_REQUEST_CODE = 4107
    }

    private val bluetoothDeviceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    extractBluetoothDevice(intent)
                        ?.takeIf { it.isAudioOutputCandidate() }
                        ?.toBluetoothAudioRoute(isConnected = false)
                        ?.let { route ->
                            discoveredBluetoothAudioDevices[route.stableId] = route
                        }
                }
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    if (!isBluetoothEnabled()) {
                        discoveredBluetoothAudioDevices.clear()
                    }
                }
            }
            emitBluetoothAudioDevices()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Device capability channel ─────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chiraitori.pixelplay/device_capabilities",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapabilities" -> result.success(readCapabilities())
                "startBluetoothDiscovery" -> {
                    result.success(startBluetoothAudioDiscovery())
                }
                "stopBluetoothDiscovery" -> {
                    stopBluetoothAudioDiscovery()
                    result.success(null)
                }
                "getBluetoothAudioDevices" -> {
                    result.success(readBluetoothAudioDevices())
                }
                "setMediaVolume" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val maxVolume = audioManager
                        .getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        .coerceAtLeast(1)
                    val requestedLevel = call.argument<Number>("level")?.toInt() ?: 0
                    val level = requestedLevel.coerceIn(0, maxVolume)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, level, 0)
                    result.success(
                        mapOf(
                            "mediaVolume" to audioManager.getStreamVolume(
                                AudioManager.STREAM_MUSIC,
                            ),
                            "mediaVolumeMax" to maxVolume,
                        ),
                    )
                }
                "openAudioOutputSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "openBluetoothSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "openWifiSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                    result.success(null)
                }
                "setRingtone" -> {
                    val uriValue = call.argument<String>("uri")
                    val tone = call.argument<String>("tone") ?: "ringtone"
                    if (uriValue.isNullOrBlank()) {
                        result.success(mapOf("status" to "error", "message" to "This track is not a local file."))
                        return@setMethodCallHandler
                    }
                    if (!Settings.System.canWrite(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(mapOf("status" to "permission"))
                        return@setMethodCallHandler
                    }
                    val type = when (tone) {
                        "notification" -> RingtoneManager.TYPE_NOTIFICATION
                        "alarm" -> RingtoneManager.TYPE_ALARM
                        else -> RingtoneManager.TYPE_RINGTONE
                    }
                    try {
                        RingtoneManager.setActualDefaultRingtoneUri(this, type, Uri.parse(uriValue))
                        result.success(mapOf("status" to "success"))
                    } catch (error: Exception) {
                        result.success(
                            mapOf(
                                "status" to "error",
                                "message" to (error.localizedMessage ?: "Could not set the ringtone."),
                            ),
                        )
                    }
                }
                "deleteMediaStoreAudio" -> {
                    val uriValue = call.argument<String>("uri")
                    if (uriValue.isNullOrBlank()) {
                        result.success(
                            mapOf(
                                "status" to "error",
                                "message" to "This track is not a local MediaStore item.",
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    val uri = Uri.parse(uriValue)
                    if (uri.scheme != "content" || uri.authority != MediaStore.AUTHORITY) {
                        result.success(
                            mapOf(
                                "status" to "error",
                                "message" to "Only MediaStore audio can be deleted from PixelPlay.",
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    if (pendingMediaDeleteResult != null) {
                        result.success(
                            mapOf(
                                "status" to "busy",
                                "message" to "Another delete confirmation is already open.",
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            pendingMediaDeleteResult = result
                            val request = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
                            startIntentSenderForResult(
                                request.intentSender,
                                MEDIA_DELETE_REQUEST_CODE,
                                null,
                                0,
                                0,
                                0,
                            )
                        } else {
                            val deleted = contentResolver.delete(uri, null, null)
                            result.success(
                                mapOf(
                                    "status" to if (deleted > 0) "success" else "error",
                                    "message" to if (deleted > 0) null else "The audio file could not be deleted.",
                                ),
                            )
                        }
                    } catch (error: Exception) {
                        pendingMediaDeleteResult = null
                        result.success(
                            mapOf(
                                "status" to "error",
                                "message" to (error.localizedMessage ?: "The audio file could not be deleted."),
                            ),
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chiraitori.pixelplay/bluetooth_audio_devices",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bluetoothDeviceEventSink = events
                    ensureBluetoothReceiverRegistered()
                    emitBluetoothAudioDevices()
                }

                override fun onCancel(arguments: Any?) {
                    bluetoothDeviceEventSink = null
                }
            },
        )

        // ── Audio meta channel (bitrate / sampleRate / mimeType) ──────────
        // Mirrors Kotlin's MediaControllerSyncStateHolder probe logic:
        // uses MediaMetadataRetriever to read the real values from the file.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chiraitori.pixelplay/audio_meta",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAudioMeta" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    // Read metadata on a background thread to avoid blocking the main thread
                    Thread {
                        val meta = readAudioMeta(uriString)
                        mainHandler.post { result.success(meta) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != MEDIA_DELETE_REQUEST_CODE) return
        val result = pendingMediaDeleteResult ?: return
        pendingMediaDeleteResult = null
        result.success(
            mapOf(
                "status" to if (resultCode == Activity.RESULT_OK) "success" else "cancelled",
                "message" to if (resultCode == Activity.RESULT_OK) null else "Delete was cancelled.",
            ),
        )
    }

    /**
     * Reads bitrate, sample rate, and MIME type using the same two-stage
     * MediaMetadataRetriever -> MediaExtractor flow as Kotlin AudioMetaUtils.
     * Must be called from a background thread.
     */
    private fun readAudioMeta(uriString: String): Map<String, Any?>? {
        val retriever = MediaMetadataRetriever()
        val uri = Uri.parse(uriString)
        val localPath = if (uriString.startsWith("file://")) {
            Uri.decode(uriString.removePrefix("file://"))
        } else {
            uriString
        }
        var mimeType: String? = null
        var bitrate: Int? = null
        var sampleRate: Int? = null

        try {
            if (uri.scheme == "content" || uri.scheme == "http" || uri.scheme == "https") {
                retriever.setDataSource(this, uri)
            } else {
                retriever.setDataSource(localPath)
            }

            mimeType = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                ?.takeIf { it.isNotBlank() }
                ?: run {
                    if (uri.scheme == "content") contentResolver.getType(uri) else null
                }

            bitrate = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toIntOrNull()
                ?.takeIf { it > 0 }

            sampleRate = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_SAMPLERATE)
                    ?.toIntOrNull()
                    ?.takeIf { it > 0 }
            } else null
        } catch (_: Exception) {
        } finally {
            retriever.release()
        }

        // Some formats have incomplete metadata in MediaMetadataRetriever.
        // Match the original app and fill only missing values from the audio
        // track exposed by MediaExtractor.
        try {
            val extractor = MediaExtractor()
            try {
                if (uri.scheme == "content" || uri.scheme == "http" || uri.scheme == "https") {
                    extractor.setDataSource(this, uri, null)
                } else {
                    extractor.setDataSource(localPath)
                }
                for (index in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(index)
                    val trackMime = format.getString(MediaFormat.KEY_MIME)
                    if (trackMime?.startsWith("audio/") != true) continue
                    mimeType = mimeType ?: trackMime
                    if (sampleRate == null && format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (bitrate == null && format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                        bitrate = format.getInteger(MediaFormat.KEY_BIT_RATE)
                    }
                    break
                }
            } finally {
                extractor.release()
            }
        } catch (_: Exception) {
        }

        return mapOf(
            "mimeType" to mimeType,
            "bitrate" to bitrate,
            "sampleRate" to sampleRate,
        )
    }

    override fun onDestroy() {
        stopBluetoothAudioDiscovery()
        if (bluetoothReceiverRegistered) {
            runCatching { unregisterReceiver(bluetoothDeviceReceiver) }
            bluetoothReceiverRegistered = false
        }
        bluetoothDeviceEventSink = null
        super.onDestroy()
    }

    private fun ensureBluetoothReceiverRegistered() {
        if (bluetoothReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bluetoothDeviceReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(bluetoothDeviceReceiver, filter)
        }
        bluetoothReceiverRegistered = true
    }

    @SuppressLint("MissingPermission")
    private fun startBluetoothAudioDiscovery(): Boolean {
        ensureBluetoothReceiverRegistered()
        discoveredBluetoothAudioDevices.clear()
        emitBluetoothAudioDevices()

        val adapter = getSystemService(BluetoothManager::class.java)?.adapter ?: return false
        if (!hasBluetoothScanPermission() || !hasBluetoothConnectPermission()) return false
        if (!runCatching { adapter.isEnabled }.getOrDefault(false)) return false

        runCatching {
            if (adapter.isDiscovering) adapter.cancelDiscovery()
            adapter.startDiscovery()
        }.onFailure { emitBluetoothAudioDevices() }
        return runCatching { adapter.isDiscovering }.getOrDefault(false)
    }

    @SuppressLint("MissingPermission")
    private fun stopBluetoothAudioDiscovery() {
        val adapter = getSystemService(BluetoothManager::class.java)?.adapter ?: return
        if (!hasBluetoothScanPermission()) return
        runCatching {
            if (adapter.isDiscovering) adapter.cancelDiscovery()
        }
    }

    private fun emitBluetoothAudioDevices() {
        bluetoothDeviceEventSink?.success(readBluetoothAudioDevices())
    }

    @SuppressLint("MissingPermission")
    private fun readBluetoothAudioDevices(): List<Map<String, Any?>> {
        if (!hasBluetoothConnectPermission()) return emptyList()

        val localNames = localBluetoothDeviceNames()
        val connectedDevices = linkedMapOf<String, BluetoothAudioRoute>()
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .asSequence()
            .filter { device -> device.isBluetoothAudioOutput() }
            .mapNotNull { device ->
                val name = device.productName?.toString()?.trim().orEmpty()
                if (name.isEmpty() || localNames.any { it.equals(name, ignoreCase = true) }) {
                    return@mapNotNull null
                }
                val address = device.address.trim().takeIf(String::isNotEmpty)
                BluetoothAudioRoute(
                    name = name,
                    address = address,
                    isConnected = true,
                    batteryPercent = null,
                )
            }
            .forEach { route -> connectedDevices[route.stableId] = route }

        val merged = linkedMapOf<String, BluetoothAudioRoute>()
        connectedDevices.values.forEach { route -> merged[route.stableId] = route }
        discoveredBluetoothAudioDevices.values.forEach { route ->
            if (localNames.any { it.equals(route.name, ignoreCase = true) }) return@forEach
            val current = merged[route.stableId]
            merged[route.stableId] = if (current == null) {
                route
            } else {
                current.copy(batteryPercent = current.batteryPercent ?: route.batteryPercent)
            }
        }

        return merged.values
            .sortedWith(
                compareByDescending<BluetoothAudioRoute> { it.isConnected }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it.name },
            )
            .map(BluetoothAudioRoute::toMap)
    }

    private fun AudioDeviceInfo.isBluetoothAudioOutput(): Boolean {
        return type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
            type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                type == AudioDeviceInfo.TYPE_HEARING_AID) ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                (type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    type == AudioDeviceInfo.TYPE_BLE_SPEAKER))
    }

    @SuppressLint("MissingPermission")
    private fun BluetoothDevice.toBluetoothAudioRoute(
        isConnected: Boolean,
    ): BluetoothAudioRoute? {
        if (!hasBluetoothConnectPermission()) return null
        val name = runCatching { name?.trim().orEmpty() }.getOrDefault("")
        if (name.isEmpty() ||
            localBluetoothDeviceNames().any { it.equals(name, ignoreCase = true) }
        ) {
            return null
        }
        val address = runCatching { address?.trim().orEmpty() }
            .getOrDefault("")
            .takeIf(String::isNotEmpty)
        return BluetoothAudioRoute(
            name = name,
            address = address,
            isConnected = isConnected,
            batteryPercent = readBluetoothBatteryPercent(this),
        )
    }

    @SuppressLint("MissingPermission")
    private fun BluetoothDevice.isAudioOutputCandidate(): Boolean {
        if (!hasBluetoothConnectPermission()) return false
        val deviceClass = runCatching { bluetoothClass }.getOrNull() ?: return false
        return deviceClass.majorDeviceClass == BluetoothClass.Device.Major.AUDIO_VIDEO ||
            deviceClass.hasService(BluetoothClass.Service.RENDER)
    }

    private fun readBluetoothBatteryPercent(device: BluetoothDevice): Int? {
        if (!hasBluetoothConnectPermission()) return null
        return runCatching {
            val method = device.javaClass.methods.firstOrNull {
                it.name == "getBatteryLevel" && it.parameterCount == 0
            } ?: device.javaClass.declaredMethods.firstOrNull {
                it.name == "getBatteryLevel" && it.parameterCount == 0
            }
            (method?.apply { isAccessible = true }?.invoke(device) as? Int)
                ?.takeIf { it in 0..100 }
        }.getOrNull()
    }

    @SuppressLint("MissingPermission")
    private fun localBluetoothDeviceNames(): Set<String> {
        val adapterName = if (hasBluetoothConnectPermission()) {
            runCatching {
                getSystemService(BluetoothManager::class.java)
                    ?.adapter
                    ?.name
                    ?.trim()
                    .orEmpty()
            }.getOrDefault("")
        } else {
            ""
        }
        return buildSet {
            adapterName.takeIf(String::isNotEmpty)?.let(::add)
            Build.MODEL.trim().takeIf(String::isNotEmpty)?.let(::add)
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        if (!hasBluetoothConnectPermission()) return false
        return runCatching {
            getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled == true
        }.getOrDefault(false)
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasBluetoothScanPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
            PackageManager.PERMISSION_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun extractBluetoothDevice(intent: Intent): BluetoothDevice? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
    }

    private fun readCapabilities(): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val mediaVolumeMax = audioManager
            .getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            .coerceAtLeast(1)
        val mediaVolume = audioManager
            .getStreamVolume(AudioManager.STREAM_MUSIC)
            .coerceIn(0, mediaVolumeMax)
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val bluetoothManager =
            getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothOutput = audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { device ->
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                        device.type == AudioDeviceInfo.TYPE_HEARING_AID) ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        (
                            device.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                                device.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                            ))
            }
        val wifiOn = wifiManager.isWifiEnabled
        val wifiConnected = connectivityManager.activeNetwork
            ?.let(connectivityManager::getNetworkCapabilities)
            ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val wifiSsid = if (wifiConnected) {
            runCatching {
                wifiManager.connectionInfo.ssid
                    ?.trim('"')
                    ?.takeUnless { it.isBlank() || it == WifiManager.UNKNOWN_SSID }
            }.getOrNull()
        } else {
            null
        }
        val bluetoothEnabled = runCatching {
            bluetoothManager.adapter?.isEnabled == true
        }.getOrElse {
            Settings.Global.getInt(
                contentResolver,
                Settings.Global.BLUETOOTH_ON,
                if (bluetoothOutput != null) 1 else 0,
            ) == 1
        }
        val packageManager = packageManager
        val decoderTypes = MediaCodecList(MediaCodecList.ALL_CODECS)
            .codecInfos
            .asSequence()
            .filter { !it.isEncoder }
            .flatMap { it.supportedTypes.asSequence() }
            .map { it.lowercase() }
            .toSet()
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdk" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "outputSampleRate" to audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE),
            "framesPerBuffer" to audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER),
            "mediaVolume" to mediaVolume,
            "mediaVolumeMax" to mediaVolumeMax,
            "wifiOn" to wifiOn,
            "wifiConnected" to wifiConnected,
            "wifiSsid" to wifiSsid,
            "bluetoothEnabled" to bluetoothEnabled,
            "bluetoothActive" to (bluetoothOutput != null),
            "bluetoothName" to bluetoothOutput?.productName?.toString(),
            "decoderTypes" to decoderTypes.toList().sorted(),
            "dynamicColor" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
            "notificationsEnabled" to notificationManager.areNotificationsEnabled(),
            "exactAlarms" to (
                Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
            ),
            "batteryOptimized" to !powerManager.isIgnoringBatteryOptimizations(packageName),
            "automotive" to packageManager.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE),
            "watch" to packageManager.hasSystemFeature(PackageManager.FEATURE_WATCH),
            "lowLatencyAudio" to packageManager.hasSystemFeature(PackageManager.FEATURE_AUDIO_LOW_LATENCY),
            "proAudio" to packageManager.hasSystemFeature(PackageManager.FEATURE_AUDIO_PRO),
        )
    }
}

private data class BluetoothAudioRoute(
    val name: String,
    val address: String?,
    val isConnected: Boolean,
    val batteryPercent: Int?,
) {
    val stableId: String
        get() = address?.takeIf(String::isNotBlank)
            ?: "name:${name.lowercase()}"

    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to stableId,
            "name" to name,
            "address" to address,
            "isConnected" to isConnected,
            "batteryPercent" to batteryPercent,
        )
    }
}
