package cc.saidian.saydian_app

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import com.tencent.mm.opensdk.modelmsg.SendMessageToWX
import com.tencent.mm.opensdk.modelmsg.WXMediaMessage
import com.tencent.mm.opensdk.modelmsg.WXWebpageObject
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.net.URI
import java.util.UUID

internal object RingWechatSharing {
    fun share(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        try {
            launch(activity, call, result)
        } catch (_: Exception) {
            result.error("WECHAT_SHARE_SEND_FAILED", "无法打开微信分享，请稍后重试", null)
        }
    }

    private fun launch(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        val appId = call.argument<String>("appId").orEmpty().trim()
        val link = call.argument<String>("url").orEmpty()
        if (!RingWechatLinkPolicy.valid(appId, link)) {
            result.error("WECHAT_SHARE_INVALID", "分享链接无效，请重新生成", null)
            return
        }
        val api = WXAPIFactory.createWXAPI(activity, appId, false)
        if (!api.isWXAppInstalled) {
            result.error("WECHAT_NOT_INSTALLED", "请先安装微信", null)
            return
        }
        if (!api.registerApp(appId)) {
            result.error("WECHAT_SHARE_CONFIG_INVALID", "微信应用配置暂不可用", null)
            return
        }
        // The callback Activity also handles login; record only the public ID,
        // and keep share responses out of its authentication result store.
        AppWechatAuthStore.saveWechatAppId(activity, appId)
        val message = WXMediaMessage(WXWebpageObject().apply { webpageUrl = link }).apply {
            title = call.argument<String>("title").orEmpty().take(100)
            description = call.argument<String>("description").orEmpty().take(200)
            val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
            try {
                val icon = activity.applicationInfo.loadIcon(activity.packageManager)
                icon.setBounds(0, 0, 96, 96)
                icon.draw(Canvas(bitmap))
                val bytes = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)
                if (bytes.size() <= 32768) thumbData = bytes.toByteArray()
            } finally { bitmap.recycle() }
        }
        val request = SendMessageToWX.Req().apply {
            transaction = "ring-share-" + UUID.randomUUID()
            this.message = message
            scene = SendMessageToWX.Req.WXSceneSession
        }
        // Acceptance opens WeChat; it is not proof that the recipient received it.
        if (api.sendReq(request)) result.success(true)
        else result.error("WECHAT_SHARE_SEND_FAILED", "无法打开微信分享，请稍后重试", null)
    }
}

internal object RingWechatLinkPolicy {
    fun valid(appId: String, link: String): Boolean {
        val uri = runCatching { URI(link) }.getOrNull() ?: return false
        return Regex("^wx[A-Za-z0-9]{8,64}$").matches(appId) &&
            uri.scheme == "https" && uri.host == "app.saydian.cn" &&
            uri.userInfo == null && (uri.port == -1 || uri.port == 443) &&
            when (uri.rawPath) {
                "/global/say-ring/share" -> Regex("^[A-Za-z0-9_-]{43}$").matches(uri.rawFragment.orEmpty())
                "/global/say-ring/invite" -> uri.rawQuery == null &&
                    Regex("^[A-HJ-NP-Z2-9]{20}$").matches(uri.rawFragment.orEmpty())
                "/global/saidian-mall/" -> uri.rawQuery == null &&
                    Regex("^/pages/product/index\\?id=[A-Za-z0-9_-]{1,180}$").matches(uri.rawFragment.orEmpty())
                else -> false
            } &&
            link.length <= 2048
    }
}
