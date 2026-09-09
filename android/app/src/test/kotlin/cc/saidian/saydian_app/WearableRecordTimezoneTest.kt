package cc.saidian.saydian_app

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.SimpleTimeZone
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Test

class WearableRecordTimezoneTest {
    private fun date(value: String): Date = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.parse(value)!!

    @Test
    fun `historical records use their own New York winter or summer offset`() {
        val newYork = TimeZone.getTimeZone("America/New_York")
        assertEquals("-05:00", WearableRecordTimezone.offsetAt(date("2026-01-15T12:00:00Z"), newYork))
        assertEquals("-04:00", WearableRecordTimezone.offsetAt(date("2026-07-15T12:00:00Z"), newYork))
    }

    @Test
    fun `DST spring boundary uses each actual observation instant`() {
        val newYork = TimeZone.getTimeZone("America/New_York")
        assertEquals("-05:00", WearableRecordTimezone.offsetAt(date("2026-03-08T06:59:59Z"), newYork))
        assertEquals("-04:00", WearableRecordTimezone.offsetAt(date("2026-03-08T07:00:00Z"), newYork))
    }

    @Test
    fun `fractional hour and negative subhour offsets preserve their signs`() {
        val at = date("2026-01-15T12:00:00Z")
        assertEquals("+05:45", WearableRecordTimezone.offsetAt(at, TimeZone.getTimeZone("Asia/Kathmandu")))
        assertEquals("-00:30", WearableRecordTimezone.offsetAt(at, SimpleTimeZone(-30 * 60000, "synthetic-minus-half-hour")))
    }
}
