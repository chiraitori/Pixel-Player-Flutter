package com.chiraitori.pixelplay

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaCodecList
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
     * Reads bitrate, sample rate, and MIME type from [MediaMetadataRetriever],
     * identical to the Kotlin PixelPlayer app's probeAudioMetadata() logic.
     * Must be called from a background thread.
     */
    private fun readAudioMeta(uriString: String): Map<String, Any?>? {
        val retriever = MediaMetadataRetriever()
        return try {
            val uri = Uri.parse(uriString)
            if (uri.scheme == "content" || uri.scheme == "http" || uri.scheme == "https") {
                retriever.setDataSource(this, uri)
            } else {
                // file:// or bare path
                val path = if (uriString.startsWith("file://"))
                    Uri.decode(uriString.removePrefix("file://"))
                else uriString
                retriever.setDataSource(path)
            }

            val mimeType = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                ?.takeIf { it.isNotBlank() }
                ?: run {
                    // Fallback: ask ContentResolver for the MIME type
                    val parsed = Uri.parse(uriString)
                    if (parsed.scheme == "content") contentResolver.getType(parsed) else null
                }

            val bitrate = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toIntOrNull()
                ?.takeIf { it > 0 }

            // METADATA_KEY_SAMPLERATE is only available on Android 12+ (API 31)
            val sampleRate = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_SAMPLERATE)
                    ?.toIntOrNull()
                    ?.takeIf { it > 0 }
            } else null

            mapOf(
                "mimeType" to mimeType,
                "bitrate" to bitrate,
                "sampleRate" to sampleRate,
            )
        } catch (_: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun readCapabilities(): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
