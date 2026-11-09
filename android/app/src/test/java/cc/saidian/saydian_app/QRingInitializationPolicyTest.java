package cc.saidian.saydian_app;

import org.junit.Test;
import static org.junit.Assert.*;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import com.oudmon.ble.base.bluetooth.BeanFactory;
import com.oudmon.ble.base.communication.Constants;
import com.oudmon.ble.base.communication.req.RestoreKeyReq;

public class QRingInitializationPolicyTest {
    private static final long BOUNDARY = Instant.parse("2026-11-09T10:00:00Z").toEpochMilli();

    @Test public void actualBundledResetHasNoResponseParser() {
        assertNull(BeanFactory.createBean(new RestoreKeyReq(Constants.CMD_RE_STORE).getNotifyKey(), 0));
    }
    @Test public void noAckNeverTurnsIntoResetAck() {
        assertEquals(13, QRingInitializationPolicy.completedPhase(1));
        assertEquals(0, QRingInitializationPolicy.completedPhase(1) & 2);
        assertEquals(7, QRingInitializationPolicy.completedPhase(3));
        assertFalse(QRingInitializationPolicy.complete(1, BOUNDARY));
        assertFalse(QRingInitializationPolicy.complete(13, 0));
        assertFalse(QRingInitializationPolicy.complete(13, Long.MAX_VALUE));
        assertTrue(QRingInitializationPolicy.complete(13, BOUNDARY));
        assertTrue(QRingInitializationPolicy.complete(7, 0));
    }
    @Test public void resetConnectionAndUnrecognizedPhasesCannotInitialize() {
        for (int phase : new int[]{1,3}) {
            assertTrue(QRingInitializationPolicy.canInitialize(phase, false));
            assertFalse(QRingInitializationPolicy.canInitialize(phase, true));
        }
        for (int phase : new int[]{0,2,4,5,6,7,8,9,-1,11,13})
            assertFalse(QRingInitializationPolicy.canInitialize(phase, false));
    }
    @Test public void oldHealthAndInvalidTimesStayOutWithoutMutatingRecords() {
        Map<String,Object> old = Map.of("measuredAt", "2026-11-09T09:59:59Z", "values", Map.of("value", 88));
        assertFalse(QRingInitializationPolicy.healthRecordAllowed(old, BOUNDARY));
        assertTrue(QRingInitializationPolicy.healthRecordAllowed(old, 0));
        assertEquals(88, ((Map<?,?>)old.get("values")).get("value"));
        assertFalse(QRingInitializationPolicy.healthRecordAllowed(Map.of("measuredAt","bad"), BOUNDARY));
        assertFalse(QRingInitializationPolicy.healthRecordAllowed(Map.of(), BOUNDARY));
        assertFalse(QRingInitializationPolicy.healthRecordAllowed(old, Long.MAX_VALUE));
        assertTrue(QRingInitializationPolicy.healthRecordAllowed(Map.of("measuredAt","2026-11-09T18:00:00+08:00"), BOUNDARY));
    }
    @Test public void sleepUsesEverySegmentRatherThanDayOrReadTimestamp() {
        Map<String,Object> fresh = timeline("2026-11-09T10:01:00Z");
        Map<String,Object> mixed = Map.of("sessions", List.of(
                Map.of("segments", List.of(Map.of("startAt","2026-11-09T09:59:59Z"))),
                Map.of("segments", List.of(Map.of("startAt","2026-11-09T10:01:00Z")))));
        assertTrue(QRingInitializationPolicy.sleepTimelineAllowed(fresh, BOUNDARY));
        assertFalse(QRingInitializationPolicy.sleepTimelineAllowed(mixed, BOUNDARY));
        assertFalse(QRingInitializationPolicy.sleepTimelineAllowed(Map.of("sessions",List.of(),
                "readAt","2026-11-10T12:00:00Z", "rawSummary",Map.of("totalSeconds",20000)), BOUNDARY));
        assertTrue(QRingInitializationPolicy.healthRecordAllowed(Map.of("measuredAt","2026-11-09T00:00:00Z",
                "sleepTimeline", fresh), BOUNDARY));
        assertFalse(QRingInitializationPolicy.healthRecordAllowed(Map.of("measuredAt","2026-11-10T00:00:00Z",
                "sleepTimeline", mixed), BOUNDARY));
    }
    @Test public void sportsUseOriginalStartAndNeverEndOrImportTime() {
        assertFalse(QRingInitializationPolicy.sportRecordAllowed(Map.of("startedAt","2026-11-09T09:59:59Z",
                "endedAt","2026-11-09T10:30:00Z"), BOUNDARY));
        assertTrue(QRingInitializationPolicy.sportRecordAllowed(Map.of("startedAt","2026-11-09T10:00:00Z"), BOUNDARY));
        assertFalse(QRingInitializationPolicy.sportRecordAllowed(Map.of(), BOUNDARY));
    }
    @Test public void rawSleepSummariesAndDroppedRawSegmentsDoNotCrossOwners() {
        Map<String,Object> firstDay=Map.of("sessions",timeline("2026-11-09T10:01:00Z").get("sessions"),
                "rawSummary",Map.of("totalSeconds",100),"sdkDate","2026-11-09","timezone","UTC");
        assertFalse(QRingInitializationPolicy.sleepTimelineAllowed(firstDay,BOUNDARY));
        Map<String,Object> nextDay=Map.of("sessions",timeline("2026-11-10T01:00:00Z").get("sessions"),
                "rawSummary",Map.of("totalSeconds",100),"sdkDate","2026-11-10","timezone","UTC");
        assertTrue(QRingInitializationPolicy.sleepTimelineAllowed(nextDay,BOUNDARY));
        Map<String,Object> hiddenOld=Map.of("sessions",List.of(Map.of("segments",List.of(Map.of("startAt","2026-11-10T01:00:00Z")),
                "rawSegments",List.of(Map.of("startSeconds",BOUNDARY/1000-1)))));
        assertFalse(QRingInitializationPolicy.sleepTimelineAllowed(hiddenOld,BOUNDARY));
        assertFalse(QRingInitializationPolicy.sleepTimelineAllowed(Map.of("invalidSegments",true,
                "sessions",timeline("2026-11-10T01:00:00Z").get("sessions")),BOUNDARY));
    }
    @Test public void historyWindowRespectsLocalDaysAndPreservesUnboundedAccounts() {
        long nextDay = Instant.parse("2026-11-09T16:00:00Z").toEpochMilli();
        assertEquals(1, QRingInitializationPolicy.eligibleDays(BOUNDARY, BOUNDARY+30000, ZoneId.of("Asia/Shanghai"), 7));
        assertEquals(2, QRingInitializationPolicy.eligibleDays(BOUNDARY, nextDay, ZoneId.of("Asia/Shanghai"), 7));
        assertEquals(1, QRingInitializationPolicy.eligibleDays(BOUNDARY, nextDay, ZoneId.of("UTC"), 7));
        assertEquals(7, QRingInitializationPolicy.eligibleDays(0, nextDay, ZoneId.of("UTC"), 7));
        assertEquals(1, QRingInitializationPolicy.eligibleDays(BOUNDARY, BOUNDARY-1, ZoneId.of("UTC"), 7));
    }
    private static Map<String,Object> timeline(String start) {
        return Map.of("sessions", List.of(Map.of("segments", List.of(Map.of("startAt",start)))));
    }
}
