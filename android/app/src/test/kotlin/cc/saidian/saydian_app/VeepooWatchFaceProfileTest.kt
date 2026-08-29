package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VeepooWatchFaceProfileTest {
    @Test
    fun `410x502 JL variants use catalogue dial shape 58`() {
        val profile = requireNotNull(VeepooWatchFaceProfileRules.create(validInput()))

        assertEquals(58, profile.dialShape)
        assertEquals(126, validInput().serverDialShape)
    }

    @Test
    fun `profile is unsupported when any required compatibility field is missing`() {
        val valid = validInput()
        val incomplete =
            listOf(
                valid.copy(deviceId = ""),
                valid.copy(deviceLabel = ""),
                valid.copy(deviceNumber = 0),
                valid.copy(firmware = ""),
                valid.copy(width = 0),
                valid.copy(height = 0),
                valid.copy(serverDialShape = 0),
                valid.copy(binProtocol = 0),
                valid.copy(maxFileLength = 0),
                valid.copy(slotCount = 0),
                valid.copy(connectionGeneration = 0),
                valid.copy(isJlPlatform = false),
            )

        incomplete.forEach { assertNull(VeepooWatchFaceProfileRules.create(it)) }
    }

    @Test
    fun `payload contains complete strict profile and legacy aliases`() {
        val profile = requireNotNull(VeepooWatchFaceProfileRules.create(validInput()))
        val payload = profile.toPayload()
        val requiredKeys =
            setOf(
                "provider",
                "deviceId",
                "deviceLabel",
                "deviceNumber",
                "firmware",
                "width",
                "height",
                "dialShape",
                "binProtocol",
                "maxFileLength",
                "slotCount",
                "profileFingerprint",
            )

        assertTrue(payload.keys.containsAll(requiredKeys))
        assertEquals("Vep", payload["provider"])
        assertEquals(true, payload["onlineMarketSupported"])
        assertEquals(payload["width"], payload["screenWidth"])
        assertEquals(payload["height"], payload["screenHeight"])
        assertEquals(payload["maxFileLength"], payload["maxLength"])
        assertTrue((payload["profileFingerprint"] as String).matches(Regex("[0-9a-f]{64}")))
        assertFalse(payload.containsKey("crc"))
    }

    @Test
    fun `fingerprint is stable across reconnect generation but changes with firmware`() {
        val first = requireNotNull(VeepooWatchFaceProfileRules.create(validInput()))
        val reconnected =
            requireNotNull(
                VeepooWatchFaceProfileRules.create(
                    validInput().copy(connectionGeneration = 9, deviceLabel = "Renamed W9S"),
                ),
            )
        val updated =
            requireNotNull(
                VeepooWatchFaceProfileRules.create(validInput().copy(firmware = "00.21.00.00")),
            )

        assertEquals(first.profileFingerprint, reconnected.profileFingerprint)
        assertNotEquals(first.profileFingerprint, updated.profileFingerprint)
        assertFalse(first.matchesContext(first.deviceId, 9))
        assertTrue(reconnected.matchesContext(first.deviceId.lowercase(), 9))
    }

    @Test
    fun `upload validation accepts only the current exact profile`() {
        val profile = requireNotNull(VeepooWatchFaceProfileRules.create(validInput()))
        val request = validUploadRequest(profile)

        assertNull(
            VeepooWatchFaceProfileRules.validateUpload(
                profile = profile,
                request = request,
                actualFileLength = 500_000,
                currentDeviceId = profile.deviceId,
                currentConnectionGeneration = profile.connectionGeneration,
            ),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.DEVICE_CONTEXT_CHANGED,
            validate(profile, request, generation = profile.connectionGeneration + 1),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.PROFILE_FINGERPRINT_MISMATCH,
            validate(profile, request.copy(profileFingerprint = "stale")),
        )
        for (missingDeviceId in listOf<String?>(null, "", "   ")) {
            assertEquals(
                VeepooWatchFaceUploadIssue.DEVICE_CONTEXT_CHANGED,
                validate(profile, request.copy(deviceId = missingDeviceId)),
            )
        }
        for (missingFingerprint in listOf<String?>(null, "", "   ")) {
            assertEquals(
                VeepooWatchFaceUploadIssue.PROFILE_FINGERPRINT_MISMATCH,
                validate(profile, request.copy(profileFingerprint = missingFingerprint)),
            )
        }
        assertEquals(
            VeepooWatchFaceUploadIssue.DIMENSIONS_MISMATCH,
            validate(profile, request.copy(width = 390)),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.DIAL_SHAPE_MISMATCH,
            validate(profile, request.copy(itemDialShape = 1)),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.BIN_PROTOCOL_MISMATCH,
            validate(profile, request.copy(binProtocol = 1)),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.MAX_FILE_LENGTH_MISMATCH,
            validate(profile, request.copy(maxFileLength = profile.maxFileLength - 1)),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.FILE_INVALID,
            validate(profile, request, actualFileLength = profile.maxFileLength + 1),
        )
        assertEquals(
            VeepooWatchFaceUploadIssue.FILE_LENGTH_MISMATCH,
            validate(profile, request.copy(expectedFileLength = 499_999)),
        )
    }

    private fun validate(
        profile: VeepooWatchFaceProfile,
        request: VeepooWatchFaceUploadRequest,
        actualFileLength: Long = 500_000,
        generation: Int = profile.connectionGeneration,
    ): VeepooWatchFaceUploadIssue? =
        VeepooWatchFaceProfileRules.validateUpload(
            profile = profile,
            request = request,
            actualFileLength = actualFileLength,
            currentDeviceId = profile.deviceId,
            currentConnectionGeneration = generation,
        )

    private fun validUploadRequest(profile: VeepooWatchFaceProfile) =
        VeepooWatchFaceUploadRequest(
            deviceId = profile.deviceId,
            profileFingerprint = profile.profileFingerprint,
            width = profile.width,
            height = profile.height,
            profileDialShape = profile.dialShape,
            itemDialShape = profile.dialShape,
            binProtocol = profile.binProtocol,
            maxFileLength = profile.maxFileLength,
            expectedFileLength = 500_000,
        )

    private fun validInput() =
        VeepooWatchFaceProfileInput(
            deviceId = "38:23:A4:5E:CA:69",
            deviceLabel = "SD-watch-W9S",
            deviceNumber = 2126,
            firmware = "00.20.01.00",
            width = 410,
            height = 502,
            serverDialShape = 126,
            binProtocol = 2,
            maxFileLength = 614_733,
            slotCount = 1,
            connectionGeneration = 7,
            isJlPlatform = true,
        )
}
