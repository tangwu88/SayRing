package cc.saidian.saydian_app

import android.app.Notification
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.model.enums.ESocailMsg
import com.veepoo.protocol.model.settings.ContentSetting
import com.veepoo.protocol.model.settings.ContentSmsSetting
import com.veepoo.protocol.model.settings.ContentSocailSetting
import java.util.ArrayDeque

/** Forwards only the notification categories explicitly enabled by the user. */
class SaidianNotificationListener : NotificationListenerService() {
    private val handler = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<ContentSetting>()
    private var sending = false

    override fun onNotificationPosted(notification: StatusBarNotification?) {
        val item = notification ?: return
        if (item.packageName == packageName || item.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
            return
        }
        val mapping = if (item.notification.category == Notification.CATEGORY_CALL) {
            NotificationCategory("incomingCall", "来电", ESocailMsg.OTHER)
        } else categoryFor(item.packageName) ?: return
        val coolWear = CoolWearRingBridge.isConnectedHr05()
        if (!coolWear && mapping.preference == "incomingCall") return
        val preferences = getSharedPreferences(
            if (coolWear) COOLWEAR_PREFS else PREFS, Context.MODE_PRIVATE)
        if (!preferences.getBoolean(mapping.preference, false)) return
        val extras = item.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val content =
            (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))
                ?.toString()
                ?.trim()
                .orEmpty()
        if (title.isEmpty() && content.isEmpty()) return
        val safeTitle = title.ifBlank { mapping.label }.take(48)
        val safeContent = content.ifBlank { "收到一条新消息" }.take(160)
        if (coolWear) {
            CoolWearRingBridge.forwardNotification(mapping.preference, safeTitle, safeContent)
            return
        }
        val setting =
            if (mapping.type == ESocailMsg.SMS) {
                ContentSmsSetting(ESocailMsg.SMS, safeTitle, "", safeContent)
            } else {
                ContentSocailSetting(mapping.type, safeTitle, safeContent)
            }
        enqueue(setting)
    }

    private fun enqueue(setting: ContentSetting) {
        handler.post {
            while (pending.size >= MAX_PENDING) pending.removeFirst()
            pending.addLast(setting)
            sendNext()
        }
    }

    private fun sendNext() {
        if (sending || pending.isEmpty()) return
        val manager = VPOperateManager.getInstance()
        if (!manager.isCurrentDeviceConnected) {
            pending.clear()
            return
        }
        sending = true
        val setting = pending.removeFirst()
        var completed = false
        fun finish() {
            if (completed) return
            completed = true
            handler.removeCallbacksAndMessages(setting)
            sending = false
            sendNext()
        }
        val timeout = Runnable { finish() }
        handler.postAtTime(timeout, setting, SystemClock.uptimeMillis() + SEND_TIMEOUT_MS)
        runCatching {
            manager.sendSocialMsgContent(IBleWriteResponse { finish() }, setting)
        }.onFailure { finish() }
    }

    private fun categoryFor(packageName: String): NotificationCategory? {
        val normalized = packageName.lowercase()
        return when {
            normalized == "com.tencent.mm" -> NotificationCategory("wechat", "微信", ESocailMsg.WECHAT)
            normalized.contains("mobileqq") -> NotificationCategory("qq", "QQ", ESocailMsg.QQ)
            normalized.contains("whatsapp") ->
                NotificationCategory("whatsapp", "WhatsApp", ESocailMsg.WHATS)
            normalized.contains("dingtalk") ->
                NotificationCategory("dingtalk", "钉钉", ESocailMsg.DINGDING)
            normalized.contains("wxwork") ->
                NotificationCategory("wecom", "企业微信", ESocailMsg.WXWORK)
            normalized.contains("aweme") || normalized.contains("tiktok") ->
                NotificationCategory("tiktok", "抖音", ESocailMsg.TIKTOK)
            normalized.contains("telegram") ->
                NotificationCategory("telegram", "Telegram", ESocailMsg.TELEGRAM)
            normalized.contains("messaging") || normalized.contains("mms") ->
                NotificationCategory("sms", "短信", ESocailMsg.SMS)
            else -> NotificationCategory("otherApps", "应用消息", ESocailMsg.OTHER)
        }
    }

    private data class NotificationCategory(
        val preference: String,
        val label: String,
        val type: ESocailMsg,
    )

    companion object {
        private const val PREFS = "saidian_notification_settings"
        private const val COOLWEAR_PREFS = "coolwear_notification_settings"
        private const val MAX_PENDING = 20
        private const val SEND_TIMEOUT_MS = 2_000L
    }
}
