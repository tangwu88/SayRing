package cc.saidian.saydian_app

import java.util.IdentityHashMap

/** Main-thread barrier: a retired GATT must be closed before another can start. */
internal class UrionGattDrain<T : Any>(
    private val disconnect: (T) -> Unit,
    private val close: (T) -> Unit,
    private val scheduleTimeout: (() -> Unit) -> (() -> Unit),
) {
    private val retiring = IdentityHashMap<T, () -> Unit>()
    private val waiters = mutableListOf<(Boolean) -> Unit>()
    private var closeFailed = false

    fun retire(connection: T) {
        if (retiring.containsKey(connection)) return
        retiring[connection] = {}
        val cancelTimeout = scheduleTimeout { didDisconnect(connection) }
        if (retiring.containsKey(connection)) retiring[connection] = cancelTimeout
        else cancelTimeout()
        try {
            disconnect(connection)
        } catch (_: Throwable) {
            // Android close() still releases this client if disconnect() fails.
            didDisconnect(connection)
        }
    }

    fun didDisconnect(connection: T) {
        val cancelTimeout = retiring.remove(connection) ?: return
        cancelTimeout()
        try {
            close(connection)
        } catch (_: Throwable) {
            // Do not report a successful drain or open another GATT if closing
            // the old client itself failed. A fresh transport is then required.
            closeFailed = true
        }
        if (retiring.isEmpty()) {
            val completions = waiters.toList()
            waiters.clear()
            completions.forEach { it(!closeFailed) }
        }
    }

    fun whenDrained(completion: (Boolean) -> Unit) {
        if (retiring.isEmpty()) completion(!closeFailed)
        else waiters.add(completion)
    }
}
