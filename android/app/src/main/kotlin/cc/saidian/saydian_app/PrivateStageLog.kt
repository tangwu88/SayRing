package cc.saidian.saydian_app

/** A closed set of stage names; never returns any part of a vendor payload. */
internal object PrivateStageNames {
    fun fromMessage(message: String): String {
        val text = message.lowercase()
        return when {
            text.startsWith("measurement start") -> "measurement_start"
            text.startsWith("measurement stop") -> "measurement_stop"
            text.startsWith("measurement result") -> "measurement_result"
            text.startsWith("measurement callback") -> "measurement_callback"
            text.contains("disconnect") -> "device_disconnect"
            text.contains("connect") -> "device_connection"
            text.contains("health sync") -> "health_sync"
            text.contains("history") -> "history_read"
            text.contains("watch face") || text.contains("watch-face") -> "watch_face_operation"
            text.contains("battery") -> "battery_read"
            text.contains("permission") -> "permission_check"
            text.contains("measurement") || text.contains("mini-checkup") -> "measurement_operation"
            else -> "native_operation"
        }
    }
}

/** Drop verbose logs and payload/throwable text in every build configuration. */
@Suppress("UNUSED_PARAMETER")
internal object PrivateStageLog {
    fun d(tag: String, message: String, error: Throwable? = null): Int = 0

    fun i(tag: String, message: String, error: Throwable? = null): Int =
        android.util.Log.i("SaydianNative", PrivateStageNames.fromMessage(message))

    fun w(tag: String, message: String, error: Throwable? = null): Int =
        android.util.Log.w("SaydianNative", PrivateStageNames.fromMessage(message))

    fun e(tag: String, message: String, error: Throwable? = null): Int =
        android.util.Log.e("SaydianNative", PrivateStageNames.fromMessage(message))
}
