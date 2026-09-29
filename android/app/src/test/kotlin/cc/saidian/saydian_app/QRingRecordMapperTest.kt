package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class QRingRecordMapperTest {
    @Test
    fun `seconds and milliseconds from SDK normalize to milliseconds`() {
        val fallback = 1_700_000_000_000L
        assertEquals(1_700_000_000_000L, QRingRecordMapper.sdkTimestamp(1_700_000_000L, fallback))
        assertEquals(1_700_000_000_123L, QRingRecordMapper.sdkTimestamp(1_700_000_000_123L, fallback))
        assertEquals(fallback, QRingRecordMapper.sdkTimestamp(0, fallback))
    }

    @Test
    fun `supported sports round trip and unknown modes fail closed`() {
        val modes = listOf(
            "running",
            "indoor_running",
            "walking",
            "cycling",
            "indoor_cycling",
            "basketball",
            "football",
            "badminton",
            "swimming",
            "jump_rope",
            "yoga",
            "hiking",
            "mountaineering",
        )

        modes.forEach { mode ->
            val type = QRingRecordMapper.sportType(mode)
            assertTrue("missing QRing sport type for $mode", type != null)
            assertEquals(mode, QRingRecordMapper.sportMode(type!!))
        }
        assertEquals(null, QRingRecordMapper.sportType("unknown"))
        assertEquals(null, QRingRecordMapper.sportMode(9_999))
    }

    @Test
    fun `native records use qring scoped device identity without double prefix`() {
        val values = linkedMapOf<String, Any>("value" to 72)
        val first = QRingRecordMapper.healthRecord(
            "AA:BB:CC:DD:EE:FF",
            "Q_HR01",
            "1.0.0",
            "heart_rate",
            1_700_000_000_000L,
            values,
            "bpm",
            "watch_history",
            "device_reported",
        )
        val second = QRingRecordMapper.healthRecord(
            "qring:AA:BB:CC:DD:EE:FF",
            "Q_HR01",
            "1.0.0",
            "heart_rate",
            1_700_000_000_000L,
            values,
            "bpm",
            "watch_history",
            "device_reported",
        )

        assertEquals("qring:AA:BB:CC:DD:EE:FF", first["deviceId"])
        assertEquals(first["deviceId"], second["deviceId"])
        assertEquals("qring", first["sourceVendor"])
        assertEquals("ring", first["sourceDeviceCategory"])
    }
}
