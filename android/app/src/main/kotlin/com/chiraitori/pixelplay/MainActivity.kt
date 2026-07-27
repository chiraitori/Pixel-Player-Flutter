package com.chiraitori.pixelplay

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.AudioDeviceInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Device capability channel ─────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chiraitori.pixelplay/device_capabilities",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapabilities" -> result.success(readCapabilities())
                "openAudioOutputSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

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

    private fun readCapabilities(): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
