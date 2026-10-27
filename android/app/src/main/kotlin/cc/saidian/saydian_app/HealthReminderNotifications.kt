package cc.saidian.saydian_app

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Local requests only. This does not start sampling or provide a monitor service. */
internal class HealthReminderNotifications(private val activity: Activity, messenger: BinaryMessenger) {
    private val prefs = activity.getSharedPreferences("sayring-health-reminders-v1", Context.MODE_PRIVATE)
    private val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var pendingPermission: MethodChannel.Result? = null
    private val action = "${activity.packageName}.HEALTH_REMINDER_OPEN"

    init {
        MethodChannel(messenger, "cn.saydian.ring/health_reminders").setMethodCallHandler { call, result ->
            when (call.method) {
                "setOwner" -> {
                    val next = call.argument<String>("owner")?.takeIf { it.matches(Regex("[a-f0-9]{64}")) }
                    val previous = prefs.getString("owner", null)
                    prefs.edit().putString("owner", next).apply()
                    if (previous != next) {
                        if (Build.VERSION.SDK_INT >= 23) {
                            manager.activeNotifications.filter { it.tag == "sayring-health-$previous" }
                                .forEach { manager.cancel(it.tag, it.id) }
                        }
                        if (activity.intent?.action == action) activity.intent?.action = null
                    }
                    result.success(null)
                }
                "permission" -> result.success(permission())
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (pendingPermission != null) {
                            result.error("BUSY", "Permission request already active", null)
                        } else {
                            pendingPermission = result
                            prefs.edit().putBoolean("requested", true).apply()
                            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST)
                        }
                    } else result.success(permission())
                }
                "show" -> {
                    val owner = call.argument<String>("owner")
                    val eventId = call.argument<String>("eventId")
                    if (owner == null || owner != prefs.getString("owner", null) ||
                        eventId == null || !eventId.matches(Regex("[A-Za-z0-9-]{1,100}")) || permission() != "granted") {
                        result.success(false)
                    } else {
                        if (Build.VERSION.SDK_INT >= 26) {
                            manager.createNotificationChannel(NotificationChannel(CHANNEL, "健康提醒", NotificationManager.IMPORTANCE_HIGH))
                        }
                        val intent = Intent(activity, MainActivity::class.java).apply {
                            action = this@HealthReminderNotifications.action
                            data = Uri.parse("sayring-reminder://$owner/$eventId")
                            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            putExtra("reminder-owner", owner)
                            putExtra("reminder-event", eventId)
                        }
                        val pending = PendingIntent.getActivity(activity, 0, intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        val notification = NotificationCompat.Builder(activity, CHANNEL)
                            .setSmallIcon(activity.applicationInfo.icon)
                            .setContentTitle("健康提醒")
                            .setContentText("有一条健康提醒，请打开查看测量时间与详情。")
                            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setContentIntent(pending).setAutoCancel(true).build()
                        try {
                            manager.notify("sayring-health-$owner", eventId.hashCode(), notification)
                            result.success(true) // Request accepted, not proof of delivery.
                        } catch (_: SecurityException) { result.success(false) }
                    }
                }
                "cancel" -> {
                    val eventId = call.argument<String>("eventId")
                    val owner = prefs.getString("owner", null)
                    if (eventId != null && owner != null) manager.cancel("sayring-health-$owner", eventId.hashCode())
                    result.success(null)
                }
                "consumeOpen" -> {
                    val intent = activity.intent
                    val owner = intent?.getStringExtra("reminder-owner")
                    val event = intent?.getStringExtra("reminder-event")
                    val valid = intent?.action == action && owner != null && event != null &&
                        owner == prefs.getString("owner", null) &&
                        intent.data == Uri.parse("sayring-reminder://$owner/$event")
                    if (intent?.action == action) {
                        intent.action = null
                        intent.removeExtra("reminder-owner"); intent.removeExtra("reminder-event")
                    }
                    result.success(if (valid) mapOf("owner" to owner, "eventId" to event) else null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun permission(): String {
        if (NotificationManagerCompat.from(activity).areNotificationsEnabled()) return "granted"
        if (Build.VERSION.SDK_INT >= 33 && !prefs.getBoolean("requested", false)) return "notDetermined"
        return "denied"
    }

    fun onPermissionResult(requestCode: Int) {
        if (requestCode != REQUEST) return
        val pending = pendingPermission ?: return
        pendingPermission = null
        pending.success(permission())
    }

    companion object {
        const val REQUEST = 27157
        private const val CHANNEL = "sayring-health-reminders-v1"
    }
}
