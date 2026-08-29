package cc.saidian.saydian_app

import java.security.MessageDigest
import java.util.Locale

/**
 * Immutable compatibility data read from the currently authenticated Veepoo
 * device.  A profile is created only after both SERVER and CUSTOM UI reads
 * succeed; production code must never fill missing fields with another model's
 * constants.
 */
internal data class VeepooWatchFaceProfile(
    val provider: String,
    val deviceId: String,
    val deviceLabel: String,
    val deviceNumber: Int,
    val firmware: String,
    val width: Int,
    val height: Int,
    val dialShape: Int,
    val binProtocol: Int,
    val maxFileLength: Long,
    val slotCount: Int,
    val connectionGeneration: Int,
) {
    val profileFingerprint: String =
        VeepooWatchFaceProfileRules.fingerprint(
            provider = provider,
            deviceId = deviceId,
            deviceNumber = deviceNumber,
            firmware = firmware,
            width = width,
            height = height,
            dialShape = dialShape,
            binProtocol = binProtocol,
            maxFileLength = maxFileLength,
            slotCount = slotCount,
        )

    fun matchesContext(deviceId: String, connectionGeneration: Int): Boolean =
        this.connectionGeneration == connectionGeneration &&
            this.deviceId.equals(deviceId.trim(), ignoreCase = true)

    fun toPayload(): Map<String, Any?> =
        mapOf(
            "onlineMarketSupported" to true,
            "profileVersion" to 1,
            "profileFingerprintAlgorithm" to "sha256",
            "provider" to provider,
            "deviceId" to deviceId,
            "deviceLabel" to deviceLabel,
            "deviceNumber" to deviceNumber,
            "firmware" to firmware,
            "width" to width,
            "height" to height,
            "dialShape" to dialShape,
            "binProtocol" to binProtocol,
            "maxFileLength" to maxFileLength,
            "slotCount" to slotCount,
            "profileFingerprint" to profileFingerprint,
            // Backward-compatible aliases consumed by the current Flutter page.
            "deviceTestVersion" to firmware,
            "screenWidth" to width,
            "screenHeight" to height,
            "maxLength" to maxFileLength,
        )
}

internal data class VeepooWatchFaceProfileInput(
    val deviceId: String,
    val deviceLabel: String,
    val deviceNumber: Int,
    val firmware: String,
    val width: Int,
    val height: Int,
    val serverDialShape: Int,
    val binProtocol: Int,
    val maxFileLength: Long,
    val slotCount: Int,
    val connectionGeneration: Int,
    val isJlPlatform: Boolean,
)

internal data class VeepooWatchFaceOperationContext(
    val deviceId: String,
    val connectionGeneration: Int,
)

internal data class VeepooWatchFaceUploadRequest(
    val deviceId: String?,
    val profileFingerprint: String?,
    val width: Int,
    val height: Int,
    val profileDialShape: Int,
    val itemDialShape: Int,
    val binProtocol: Int,
    val maxFileLength: Long,
    val expectedFileLength: Long,
)

internal enum class VeepooWatchFaceUploadIssue {
    DEVICE_CONTEXT_CHANGED,
    PROFILE_FINGERPRINT_MISMATCH,
    DIMENSIONS_MISMATCH,
    DIAL_SHAPE_MISMATCH,
    BIN_PROTOCOL_MISMATCH,
    MAX_FILE_LENGTH_MISMATCH,
    FILE_INVALID,
    FILE_LENGTH_MISMATCH,
}

internal object VeepooWatchFaceProfileRules {
    const val PROVIDER = "Vep"
    const val JL_410_X_502_CATALOGUE_DIAL_SHAPE = 58

    fun create(input: VeepooWatchFaceProfileInput): VeepooWatchFaceProfile? {
        val deviceId = input.deviceId.trim()
        val deviceLabel = input.deviceLabel.trim()
        val firmware = input.firmware.trim()
        val dialShape =
            catalogueDialShape(
                reportedDialShape = input.serverDialShape,
                width = input.width,
                height = input.height,
                isJlPlatform = input.isJlPlatform,
            )
        if (!input.isJlPlatform ||
            deviceId.isEmpty() ||
            deviceLabel.isEmpty() ||
            input.deviceNumber <= 0 ||
            firmware.isEmpty() ||
            input.width <= 0 ||
            input.height <= 0 ||
            input.serverDialShape <= 0 ||
            dialShape <= 0 ||
            input.binProtocol <= 0 ||
            input.maxFileLength <= 100L ||
            input.slotCount <= 0 ||
            input.connectionGeneration <= 0
        ) {
            return null
        }
        return VeepooWatchFaceProfile(
            provider = PROVIDER,
            deviceId = deviceId,
            deviceLabel = deviceLabel,
            deviceNumber = input.deviceNumber,
            firmware = firmware,
            width = input.width,
            height = input.height,
            dialShape = dialShape,
            binProtocol = input.binProtocol,
            maxFileLength = input.maxFileLength,
            slotCount = input.slotCount,
            connectionGeneration = input.connectionGeneration,
        )
    }

    /**
     * Veepoo exposes several JL UI variants for the same 410x502 panel.  Its
     * online catalogue groups those variants under the base shape code 58.
     */
    fun catalogueDialShape(
        reportedDialShape: Int,
        width: Int,
        height: Int,
        isJlPlatform: Boolean,
    ): Int =
        if (isJlPlatform && width == 410 && height == 502) {
            JL_410_X_502_CATALOGUE_DIAL_SHAPE
        } else {
            reportedDialShape
        }

    fun validateUpload(
        profile: VeepooWatchFaceProfile,
        request: VeepooWatchFaceUploadRequest,
        actualFileLength: Long,
        currentDeviceId: String,
        currentConnectionGeneration: Int,
    ): VeepooWatchFaceUploadIssue? {
        val requestedDeviceId = request.deviceId?.trim().orEmpty()
        if (requestedDeviceId.isEmpty() ||
            !profile.matchesContext(currentDeviceId, currentConnectionGeneration) ||
            !requestedDeviceId.equals(currentDeviceId.trim(), ignoreCase = true)
        ) {
            return VeepooWatchFaceUploadIssue.DEVICE_CONTEXT_CHANGED
        }
        val requestedFingerprint = request.profileFingerprint?.trim().orEmpty()
        if (requestedFingerprint.isEmpty() ||
            !requestedFingerprint.equals(profile.profileFingerprint, ignoreCase = true)
        ) {
            return VeepooWatchFaceUploadIssue.PROFILE_FINGERPRINT_MISMATCH
        }
        if (request.width != profile.width || request.height != profile.height) {
            return VeepooWatchFaceUploadIssue.DIMENSIONS_MISMATCH
        }
        if (request.profileDialShape != profile.dialShape ||
            request.itemDialShape != profile.dialShape
        ) {
            return VeepooWatchFaceUploadIssue.DIAL_SHAPE_MISMATCH
        }
        if (request.binProtocol != profile.binProtocol) {
            return VeepooWatchFaceUploadIssue.BIN_PROTOCOL_MISMATCH
        }
        if (request.maxFileLength != profile.maxFileLength) {
            return VeepooWatchFaceUploadIssue.MAX_FILE_LENGTH_MISMATCH
        }
        if (actualFileLength <= 100L || actualFileLength > profile.maxFileLength) {
            return VeepooWatchFaceUploadIssue.FILE_INVALID
        }
        if (request.expectedFileLength > 0L && request.expectedFileLength != actualFileLength) {
            return VeepooWatchFaceUploadIssue.FILE_LENGTH_MISMATCH
        }
        return null
    }

    fun fingerprint(
        provider: String,
        deviceId: String,
        deviceNumber: Int,
        firmware: String,
        width: Int,
        height: Int,
        dialShape: Int,
        binProtocol: Int,
        maxFileLength: Long,
        slotCount: Int,
    ): String {
        val canonical =
            listOf(
                provider.trim(),
                deviceId.trim().uppercase(Locale.US),
                deviceNumber.toString(),
                firmware.trim(),
                "${width}x$height",
                dialShape.toString(),
                binProtocol.toString(),
                maxFileLength.toString(),
                slotCount.toString(),
            ).joinToString("|")
        return MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }
}
