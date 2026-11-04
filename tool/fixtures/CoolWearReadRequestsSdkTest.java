package cc.saidian.saydian_app;

import java.util.Arrays;

import ce.com.cenewbluesdk.CEBC;
import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.entity.QueueSendData;
import ce.com.cenewbluesdk.entity.k6.K6_CESyncTime;
import ce.com.cenewbluesdk.queue.CEProtocolB;

/** 使用原 AAR 的真实编码／解析，防止以错误的方法名断言代替请求帧验收。 */
public final class CoolWearReadRequestsSdkTest {
    public static void main(String[] args) {
        for (CoolWearReadRequests.Kind kind : CoolWearReadRequests.Kind.values()) {
            CEDevData request = CoolWearReadRequests.query(kind);
            require(request.getCmd() == CEBC.K6.CMD_TYPE_REQUEST, "read became a write");
            require(request.getDataType() == kind.dataType, "wrong request target");
            require(empty(request.getData()), "read carries a setting body");
            CEDevData decoded = roundTrip(request);
            require(decoded.getDataType() == kind.dataType && empty(decoded.getData()),
                    "actual wire frame is not an empty request: " + kind + " cmd="
                            + decoded.getCmd() + " type=" + decoded.getDataType()
                            + " body=" + (decoded.getData() == null ? -1 : decoded.getData().length));
            // SDK 帧是可变对象；下一次读取不能复用被写入者污染过的上个对象。
            request.setCmd(CEBC.K6.CMD_TYPE_SEND);
            request.setData(new byte[]{1});
            require(CoolWearReadRequests.query(kind) != request
                    && empty(CoolWearReadRequests.query(kind).getData()), "mutated request was reused");
        }
        for (byte format = 0; format <= 1; format++) {
            for (byte md = 0; md <= 1; md++) {
                K6_CESyncTime phone = new K6_CESyncTime(1700000000L, 28800L,
                        (byte) (1 - format), (byte) (1 - md));
                K6_CESyncTime device = new K6_CESyncTime(1600000000L, 0L, format, md);
                byte[] original = device.getBytes().clone();
                byte[] originalPhone = phone.getBytes().clone();
                CEDevData update = CoolWearReadRequests.connectionClockUpdate(phone, format, md);
                CEDevData decoded = roundTrip(update);
                require(decoded.getDataType() == CEBC.K6.DATA_TYPE_TIME
                        && decoded.getData().length == 9, "clock included another setting");
                K6_CESyncTime result = new K6_CESyncTime(decoded.getData().clone());
                require(result.getFormat() == format && result.getMdFormat() == md,
                        "clock changed reported device display format");
                require(Arrays.equals(Arrays.copyOf(decoded.getData(), 8),
                        Arrays.copyOf(originalPhone, 8)), "phone clock or zone lost");
                require(Arrays.equals(original, device.getBytes()), "reported setting snapshot mutated");
            }
        }
        System.out.println("Actual SDK read frames PASS: empty REQUEST packets, fresh objects, separate clock preserves all reported display formats.");
    }

    private static CEDevData roundTrip(CEDevData value) {
        CEProtocolB encoder = new CEProtocolB(1); // 与原 SDK CEDevK6Proxy 相同的协议变体。
        QueueSendData wire = encoder.getSendData(value);
        require(wire != null && wire.getSendData() != null, "SDK did not encode request");
        // 原厂 Analysis 在重组完成后把 cmd 归一为内部接收事件 -10001；
        // 出站读/写标志必须检查真实帧头，不能错用归一后的 cmd 来判断。
        require(wire.getSendData().length >= 10
                && Byte.toUnsignedInt(wire.getSendData()[4]) == value.getCmd(),
                "actual outgoing command differs from the SDK request");
        CEDevData decoded = new CEProtocolB(1).Analysis(wire.getSendData());
        require(decoded != null, "SDK could not decode generated frame");
        return decoded;
    }

    private static boolean empty(byte[] value) { return value == null || value.length == 0; }
    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
