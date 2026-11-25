package cc.saidian.saydian_app;

import org.junit.Test;
import static org.junit.Assert.*;
import java.util.*;

public class CoolWearReadEvidenceTest {
    private Map<String,Object> clock() { return new CoolWearClockSync().evidence(1, 0); }
    @SuppressWarnings("unchecked")
    private Map<String,Object> first(CoolWearReadEvidence e) {
        return ((List<Map<String,Object>>)e.snapshot(Collections.singletonMap("heart_rate", "partial"), clock(), null, null).get("metrics")).get(0);
    }
    @Test public void missingPacketsAndRejectedMappingsRemainDistinct() {
        CoolWearReadEvidence e = new CoolWearReadEvidence(); e.requested(8);
        assertEquals(0, first(e).get("packets")); assertEquals(false,first(e).get("mappingObserved"));
        e.packet(8,new byte[]{3,0,3});
        e.mapped("heart_rate",3,Collections.singletonList(Collections.singletonMap("type","heart_rate")));
        assertEquals(3, first(e).get("wireRows")); assertEquals(3, first(e).get("decodedRows"));
        assertEquals(1, first(e).get("mappedRecords")); assertEquals(2, first(e).get("filteredRecords"));
        assertEquals(true,first(e).get("mappingObserved"));
    }
    @Test public void emptyDataPacketIsAnObservationNotAnInventedRecord() {
        CoolWearReadEvidence e = new CoolWearReadEvidence(); e.requested(8); e.packet(8,new byte[0]);
        assertEquals(1,first(e).get("packets")); assertEquals(0,first(e).get("wireRows"));
        assertEquals(false,first(e).get("mappingObserved"));
    }
    @Test public void newWindowHasNoOldCountersOrMonitoring() {
        CoolWearReadEvidence e = new CoolWearReadEvidence(); e.requested(8);
        assertFalse(e.snapshot(Collections.emptyMap(),clock(),null,null).containsKey("monitoring"));
        assertEquals(Collections.emptyList(),new CoolWearReadEvidence().snapshot(Collections.emptyMap(),clock(),null,null).get("metrics"));
    }
    @Test public void clockAttemptIsNeverClaimedAsADeviceAcknowledgement() {
        CoolWearClockSync c = new CoolWearClockSync();
        assertEquals("not_requested",c.evidence(1,0).get("submission"));
        CoolWearClockSync.Request r=c.offer(1,1,"synthetic-target",0,0,0);
        assertEquals("pending",c.evidence(1,0).get("submission"));
        assertTrue(c.claim(r)); assertEquals("attempted",c.evidence(1,0).get("submission"));
        assertEquals("not_observed",c.evidence(1,0).get("verification"));
        assertEquals("not_confirmed",c.evidence(2,0).get("format"));
    }
}
