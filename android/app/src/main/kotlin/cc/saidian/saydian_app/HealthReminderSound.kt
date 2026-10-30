package cc.saidian.saydian_app

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Bounded foreground feedback; never changes volume, ringer or DND settings. */
internal class HealthReminderSound(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.saydian.ring/health_reminder_sound")
    private val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notifications = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val handler = Handler(Looper.getMainLooper())
    private var foreground = false
    private var token: String? = null
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var pending: MethodChannel.Result? = null
    private var timeout: Runnable? = null

    init {
        channel.setMethodCallHandler { call, result ->
            val request = call.argument<String>("token")
            when (call.method) {
                "play" -> {
                    if (request == null || !request.matches(Regex("reading-[0-9-]{1,80}"))) {
                        result.success(false)
                    } else play(request, result)
                }
                "stop" -> { if (request == token) stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    fun onForeground(value: Boolean) {
        foreground = value
        if (!value) stop()
    }

    private fun finishRequest(accepted: Boolean) {
        val result = pending
        pending = null
        result?.success(accepted)
    }

    private fun play(request: String, result: MethodChannel.Result) {
        if (request == token) { result.success(false); return }
        stop()
        if (!foreground || audio.ringerMode != AudioManager.RINGER_MODE_NORMAL ||
            audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION) == 0 ||
            notifications.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
            result.success(false); return
        }
        token = request
        pending = result
        try {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener { change ->
                    if (token == request && (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT)) stop()
                }.build()
            if (audio.requestAudioFocus(focusRequest) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                stop(); return
            }
            focus = focusRequest
            val asset = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/audio/health_reminder_alarm.wav")
            val file = File(activity.cacheDir, "sayring-health-reminder-alarm-v1.wav")
            activity.assets.open(asset).use { input -> file.outputStream().use { input.copyTo(it) } }
            val current = MediaPlayer()
            player = current
            current.setAudioAttributes(attributes)
            current.setVolume(0.85f, 0.85f)
            current.setDataSource(file.absolutePath)
            current.setOnPreparedListener {
                if (token != request || !foreground || player !== current) return@setOnPreparedListener
                try { current.start(); finishRequest(true) } catch (_: Exception) { stop() }
            }
            current.setOnCompletionListener { if (token == request && player === current) stop() }
            current.setOnErrorListener { _, _, _ ->
                if (token == request && player === current) stop()
                true
            }
            timeout = Runnable { if (token == request) stop() }.also { handler.postDelayed(it, 6000) }
            current.prepareAsync()
        } catch (_: Exception) { stop() }
    }

    private fun stop() {
        token = null
        timeout?.let(handler::removeCallbacks)
        timeout = null
        val previous = player
        player = null
        try { previous?.release() } catch (_: Exception) { }
        val previousFocus = focus
        focus = null
        previousFocus?.let { audio.abandonAudioFocusRequest(it) }
        finishRequest(false)
    }

    fun dispose() { stop(); channel.setMethodCallHandler(null) }
}
