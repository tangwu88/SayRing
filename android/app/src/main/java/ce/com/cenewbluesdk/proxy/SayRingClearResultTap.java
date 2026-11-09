package ce.com.cenewbluesdk.proxy;

import java.util.function.IntConsumer;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.SendDataHelper.K6SendDataManager;

/** Temporary, one-command result tap. Preserves the original SDK listeners. */
public final class SayRingClearResultTap extends K6SendDataManager implements AutoCloseable {
    private final CEDevK6Proxy proxy;
    private final K6SendDataManager original;
    private volatile IntConsumer receiver;

    private SayRingClearResultTap(CEDevK6Proxy proxy, K6SendDataManager original, IntConsumer receiver) {
        super(proxy);
        this.proxy = proxy;
        this.original = original;
        this.receiver = receiver;
    }

    public static SayRingClearResultTap install(CEBluetoothProxyBase source, IntConsumer receiver) {
        if (!(source instanceof CEDevK6Proxy) || receiver == null) return null;
        CEDevK6Proxy proxy = (CEDevK6Proxy) source;
        K6SendDataManager original = proxy.mIK6SendDataManager;
        if (original == null || original instanceof SayRingClearResultTap) return null;
        SayRingClearResultTap tap = new SayRingClearResultTap(proxy, original, receiver);
        proxy.mIK6SendDataManager = tap;
        return tap;
    }

    @Override public void processResult(int type, int status) {
        IntConsumer callback = type == 207 && proxy.mIK6SendDataManager == this ? receiver : null;
        original.processResult(type, status);
        // SDK cmd=1 reaches status=1 only after its real matching command ACK;
        // GATT write completion merely starts the SDK ACK timer.
        if (callback != null) {
            try { callback.accept(status); }
            catch (RuntimeException ignored) { /* An observer must not stop the SDK queue. */ }
        }
    }

    @Override public void addSendDataResultListener(String type, K6BleDataResult<Integer> listener) {
        original.addSendDataResultListener(type, listener);
    }

    @Override public void setVolume(int volume) {
        super.setVolume(volume);
        original.setVolume(volume);
    }

    @Override public void close() {
        receiver = null;
        if (proxy.mIK6SendDataManager == this) proxy.mIK6SendDataManager = original;
    }
}
