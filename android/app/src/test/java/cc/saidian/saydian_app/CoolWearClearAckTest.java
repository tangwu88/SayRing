package cc.saidian.saydian_app;

import static org.junit.Assert.*;
import org.junit.Test;
import ce.com.cenewbluesdk.entity.CEDevData;

public class CoolWearClearAckTest {
    @Test public void sdkHistoryClearEnvelopeAndMatchingAck() {
        CEDevData request = CoolWearClearAck.request();
        assertEquals(1, request.getCmd());
        assertEquals(207, request.getDataType());
        assertEquals(1, request.getItemL());
        assertEquals(1, request.getItemNumber());
        assertArrayEquals(new byte[]{1}, request.getData());
        assertEquals(CoolWearClearAck.Reply.CONFIRMED,
                CoolWearClearAck.reply(request, 1));
    }

    @Test public void otherRequestsNeverConfirm() {
        for (int command : new int[]{-10001, -10002, 3}) {
            CEDevData request = CoolWearClearAck.request(); request.setCmd(command);
            assertEquals(CoolWearClearAck.Reply.IGNORE, CoolWearClearAck.reply(request, 1));
        }
        for (int type : new int[]{44, 5, 6, 118}) {
            CEDevData request = CoolWearClearAck.request(); request.setDataType(type);
            assertEquals(CoolWearClearAck.Reply.IGNORE, CoolWearClearAck.reply(request, 1));
        }
    }

    @Test public void rejectionUnknownAndMalformedRepliesAreNotSuccess() {
        CEDevData request = CoolWearClearAck.request();
        assertEquals(CoolWearClearAck.Reply.REJECTED, CoolWearClearAck.reply(request, 0));
        for (int status : new int[]{-1, -101, 2, 207})
            assertEquals(CoolWearClearAck.Reply.IGNORE, CoolWearClearAck.reply(request, status));
        for (byte[] data : new byte[][]{null, {}, {0}, {1, 1}}) {
            request.setData(data);
            assertEquals(CoolWearClearAck.Reply.IGNORE, CoolWearClearAck.reply(request, 1));
        }
        assertEquals(CoolWearClearAck.Reply.IGNORE, CoolWearClearAck.reply(null, 1));
    }
}
