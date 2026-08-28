package cc.saidian.saydian_app

import android.content.Context

object AppPaymentStore {
    private const val PREFERENCES = "saidian_app_payments"
    private const val WECHAT_APP_ID = "wechat_app_id"
    private const val WECHAT_RESULT_CODE = "wechat_result_code"
    private const val WECHAT_RESULT_MESSAGE = "wechat_result_message"
    private const val WECHAT_RESULT_TIME = "wechat_result_time"

    fun saveWechatAppId(context: Context, appId: String) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(WECHAT_APP_ID, appId)
            .apply()
    }

    fun readWechatAppId(context: Context): String =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(WECHAT_APP_ID, "")
            .orEmpty()

    fun clearWechatResult(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .remove(WECHAT_RESULT_CODE)
            .remove(WECHAT_RESULT_MESSAGE)
            .remove(WECHAT_RESULT_TIME)
            .apply()
    }

    fun saveWechatResult(context: Context, code: Int, message: String?) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putInt(WECHAT_RESULT_CODE, code)
            .putString(WECHAT_RESULT_MESSAGE, message.orEmpty())
            .putLong(WECHAT_RESULT_TIME, System.currentTimeMillis())
            .apply()
    }

    fun takeWechatResult(context: Context): Map<String, Any?>? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (!preferences.contains(WECHAT_RESULT_CODE)) return null
        val result =
            mapOf(
                "code" to preferences.getInt(WECHAT_RESULT_CODE, -1),
                "message" to preferences.getString(WECHAT_RESULT_MESSAGE, "").orEmpty(),
                "completedAt" to preferences.getLong(WECHAT_RESULT_TIME, 0L),
            )
        clearWechatResult(context)
        return result
    }
}
