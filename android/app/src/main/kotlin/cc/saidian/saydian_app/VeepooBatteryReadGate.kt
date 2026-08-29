package cc.saidian.saydian_app

internal data class VeepooBatteryReadRequest(
    val token: Long,
    val connectionGeneration: Int,
    val deviceId: String,
)

internal data class VeepooBatterySnapshot(
    val value: Int,
    val scale: Int,
    val isPercent: Boolean,
    val low: Boolean,
    val chargeState: Int,
) {
    val percent: Int?
        get() = value.takeIf { isPercent }

    fun toPayload(): Map<String, Any> =
        mapOf(
            "value" to value,
            "scale" to scale,
            "isPercent" to isPercent,
            "low" to low,
            "chargeState" to chargeState,
        )

    companion object {
        fun fromSdk(
            isPercent: Boolean,
            percent: Int,
            level: Int,
            low: Boolean,
            chargeState: Int,
        ): VeepooBatterySnapshot? {
            val value = if (isPercent) percent else level
            val scale = if (isPercent) 100 else 4
            if (value !in 0..scale) return null
            return VeepooBatterySnapshot(
                value = value,
                scale = scale,
                isPercent = isPercent,
                low = low,
                chargeState = chargeState,
            )
        }
    }
}

/** Keeps battery callbacks bound to the watch session that started them. */
internal class VeepooBatteryReadGate {
    private var generation = 0L
    var active: VeepooBatteryReadRequest? = null
        private set

    val isInFlight: Boolean
        get() = active != null

    fun begin(connectionGeneration: Int, deviceId: String): VeepooBatteryReadRequest? {
        if (active != null) return null
        val request =
            VeepooBatteryReadRequest(
                token = ++generation,
                connectionGeneration = connectionGeneration,
                deviceId = deviceId,
            )
        active = request
        return request
    }

    fun owns(request: VeepooBatteryReadRequest): Boolean = active == request

    fun complete(
        request: VeepooBatteryReadRequest,
        currentConnectionGeneration: Int,
        currentDeviceId: String,
    ): Boolean {
        if (!owns(request)) return false
        active = null
        return request.connectionGeneration == currentConnectionGeneration &&
            request.deviceId.equals(currentDeviceId, ignoreCase = true)
    }

    fun reset() {
        generation += 1
        active = null
    }
}

internal class VeepooExclusiveOperationGate {
    private var generation = 0L
    var activeGeneration: Long? = null
        private set

    val isInFlight: Boolean
        get() = activeGeneration != null

    fun begin(): Long? {
        if (activeGeneration != null) return null
        generation += 1
        activeGeneration = generation
        return generation
    }

    fun complete(expectedGeneration: Long): Boolean {
        if (activeGeneration != expectedGeneration) return false
        activeGeneration = null
        return true
    }

    fun reset() {
        generation += 1
        activeGeneration = null
    }
}
