package ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean;

import java.util.function.Consumer;
import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.proxy.interfaces.IK6AnalysiDevRcvDataManager;

/** Say Ring adapter for the bundled SDK's decoded, CRC-checked packet stream.
 * Lives in this package solely to append an observer to the SDK's package-visible
 * processor list. Existing parsers/listeners run first and are never replaced.
 * No SDK binary, Android permission, private reflection or payload logging.
 */
public final class SayRingHistoryObserver extends BaseK6AnalysiDevData<Object> {
    private volatile Consumer<CEDevData> receiver;
    private volatile boolean observeGestureAcks;
    private SayRingHistoryObserver(Consumer<CEDevData> receiver) {
        super(null);
        this.receiver = receiver;
    }

    public static boolean install(IK6AnalysiDevRcvDataManager source, Consumer<CEDevData> receiver) {
        return install(source, receiver, false);
    }

    public static boolean install(IK6AnalysiDevRcvDataManager source, Consumer<CEDevData> receiver, boolean observeGestureAcks) {
        if (!(source instanceof K6AnalysiDevRcvDataManager)) return false;
        K6AnalysiDevRcvDataManager manager = (K6AnalysiDevRcvDataManager) source;
        for (BaseK6AnalysiDevData<?> parser : manager.allProcess) {
            if (parser instanceof SayRingHistoryObserver) {
                ((SayRingHistoryObserver) parser).receiver = receiver;
                ((SayRingHistoryObserver) parser).observeGestureAcks = observeGestureAcks;
                return true;
            }
        }
        SayRingHistoryObserver observer = new SayRingHistoryObserver(receiver);
        observer.observeGestureAcks = observeGestureAcks;
        manager.allProcess.add(observer);
        return true;
    }

    @Override protected boolean process(CEDevData packet) {
        Consumer<CEDevData> current = receiver;
        // SDK data frames: -10001 requires transport ACK, -10002 does not.
        // A command ACK (-99) is never a history terminal.
        if (current != null && packet != null
                && (packet.getCmd() == -10001 || packet.getCmd() == -10002
                    || (observeGestureAcks
                        && packet.getCmd() == -99 && packet.getDataType() == 44))) current.accept(packet);
        return false;
    }
    @Override protected Object realProcess(byte[] bytes) { return null; }
    @Override protected boolean processResult(Object value) { return false; }
    @Override protected boolean sendMsg(Object value) { return false; }
}
