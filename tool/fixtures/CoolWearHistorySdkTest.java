package cc.saidian.saydian_app;

import java.lang.reflect.Field;
import java.util.*;
import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.entity.k6.K6_Sport;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.*;

/** Uses the actual bundled SDK registry/parser, synthetic packets only. */
public final class CoolWearHistorySdkTest {
    public static void main(String[] args) throws Exception {
        CEDevData read = new CEDevData(3, 5);
        check(read.getCmd() == 3 && read.getDataType() == 5 && read.getData() == null, "read unexpectedly carries settings");
        List<String> order = new ArrayList<>();
        Parser original = new Parser(order);
        K6AnalysiDevRcvDataManager manager = registry(new ArrayList<>(List.of(original)));
        check(SayRingHistoryObserver.install(manager, p -> order.add("observer")), "observer unavailable");
        CEDevData packet = new CEDevData(-10001, 5);
        packet.setData(new byte[]{0, 0, 0});
        manager.process(packet);
        check(order.equals(List.of("parser", "observer")), "observer ran before SDK parser or replaced it");
        order.clear();
        check(SayRingHistoryObserver.install(manager, p -> order.add("replacement")), "observer reinstall failed");
        manager.process(packet);
        check(order.equals(List.of("parser", "replacement")), "reinstall stacked or retained old bridge callback");
        order.clear(); packet.setCmd(-10002); manager.process(packet);
        check(order.equals(List.of("parser", "replacement")), "data frame without transport ACK was discarded");
        order.clear(); packet.setCmd(-99); manager.process(packet);
        check(order.equals(List.of("parser")), "ACK entered data completion path");

        ProcessDATA_TYPE_SPORT parser = new ProcessDATA_TYPE_SPORT(null);
        check(parser.isMy(5) && parser.isMy(4), "audit SDK history/current types again");
        byte[] payload = new byte[3 + K6_Sport.getItemSize()];
        payload[2] = 1;
        check(parser.realProcess(payload).size() == 1, "actual sport parser disagrees with count header");
        check(parser.realProcess(new byte[]{0, 0, 0}).isEmpty(), "explicit empty batch is not empty");
        CoolWearHistoryBatch batch = new CoolWearHistoryBatch();
        batch.accept(payload);
        check(batch.complete(), "actual complete packet not confirmed");
        CoolWearHistoryBatch empty = new CoolWearHistoryBatch();
        empty.accept(new byte[]{0, 0, 0});
        check(empty.complete() && empty.status().equals("no_data"), "empty requires explicit packet");
        System.out.println("Actual bundled history SDK PASS");
    }
    private static K6AnalysiDevRcvDataManager registry(List<?> processors) throws Exception {
        Class<?> unsafeType = Class.forName("sun.misc.Unsafe");
        Field field = unsafeType.getDeclaredField("theUnsafe"); field.setAccessible(true);
        Object unsafe = field.get(null);
        K6AnalysiDevRcvDataManager manager = (K6AnalysiDevRcvDataManager) unsafeType.getMethod("allocateInstance", Class.class).invoke(unsafe, K6AnalysiDevRcvDataManager.class);
        Field all = K6AnalysiDevRcvDataManager.class.getDeclaredField("allProcess"); all.setAccessible(true); all.set(manager, processors);
        return manager;
    }
    private static final class Parser extends BaseK6AnalysiDevData<Object> {
        final List<String> order;
        Parser(List<String> order) { super(null); this.order = order; }
        @Override protected boolean process(CEDevData packet) { order.add("parser"); return false; }
        @Override protected Object realProcess(byte[] bytes) { return null; }
        @Override protected boolean processResult(Object value) { return false; }
        @Override protected boolean sendMsg(Object value) { return false; }
    }
    private static void check(boolean ok, String message) { if (!ok) throw new AssertionError(message); }
}
