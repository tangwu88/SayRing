package cc.saidian.saydian_app

import android.content.Context

data class WechatAuthCallback(
    val errorCode: Int,
    val code: String,
    val state: String,
    val completedAt: Long,
)

object AppWechatAuthStore {
    private const val PREFERENCES = "saidian_app_wechat_auth"
    private const val WECHAT_APP_ID = "wechat_app_id"
    private const val RESULT_ERROR_CODE = "result_error_code"
    private const val RESULT_CODE = "result_code"
    private const val RESULT_STATE = "result_state"
    private const val RESULT_OPEN_ID = "result_open_id"
    private const val RESULT_TIME = "result_time"

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
            .remove(RESULT_ERROR_CODE)
            .remove(RESULT_CODE)
            .remove(RESULT_STATE)
            .remove(RESULT_OPEN_ID)
            .remove(RESULT_TIME)
            .apply()
    }

    fun saveWechatResult(
        context: Context,
        errorCode: Int,
        code: String?,
        state: String?,
    ) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putInt(RESULT_ERROR_CODE, errorCode)
            .putString(RESULT_CODE, code.orEmpty().take(1024))
            .putString(RESULT_STATE, state.orEmpty().take(256))
            .putLong(RESULT_TIME, System.currentTimeMillis())
            .apply()
    }

    fun takeWechatResult(context: Context): WechatAuthCallback? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (!preferences.contains(RESULT_ERROR_CODE)) return null
        val callback =
            WechatAuthCallback(
                errorCode = preferences.getInt(RESULT_ERROR_CODE, -1),
                code = preferences.getString(RESULT_CODE, "").orEmpty(),
                state = preferences.getString(RESULT_STATE, "").orEmpty(),
                completedAt = preferences.getLong(RESULT_TIME, 0L),
            )
        clearWechatResult(context)
        return callback
    }
}
