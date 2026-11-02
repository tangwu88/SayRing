import ce.com.cenewbluesdk.CEBC;
import ce.com.cenewbluesdk.entity.k6.K6_Action;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class CoolWearPhotoTest {
    long cameraSession, connectionEpoch;
    String connectedId = "ring-A";
    CoolWearPhotoTest activeBridge = this;
    boolean linkConnected = true, deviceInfoReceived = true;
    final List<Object> shutters = new ArrayList<>();
    final Main main = new Main();
    final Helper helper = new Helper();
    static final class Main extends ArrayDeque<Runnable> {
        private static final long serialVersionUID = 1L;
        void post(Runnable task) { add(task); }
        void drain() { while (!isEmpty()) remove().run(); }
    }
    static final class Helper {
        K6BleDataResult<Integer> listener;
        boolean throwOnSwitch;
        Helper getRcvDataManager() { return this; }
        Helper getSendBlueData() { return this; }
        void addBleDataResultListener(String action, K6BleDataResult<Integer> callback) {
            assert K6_Action.RCVD.RCVD_TAKE_PHOTOS.equals(action);
            listener = callback;
        }
        void sendPhotoSwitch(boolean enabled) {
            if (throwOnSwitch) throw new IllegalStateException("synthetic write failure");
        }
    }
    void emitOnMain(String event, Map<String, Object> payload) {
        assert "cameraShutter".equals(event);
        shutters.add(payload.get("deviceId"));
    }

    // PRODUCTION_METHOD

    void run() {
        setRemoteCamera(true);
        K6BleDataResult<Integer> old = helper.listener;
        old.bleDataResult(1);
        setRemoteCamera(false);
        setRemoteCamera(true);
        old.bleDataResult(1);
        main.drain();
        assert shutters.isEmpty() : "retired camera page triggered new page";

        helper.listener.bleDataResult(0);
        helper.listener.bleDataResult(null);
        helper.listener.bleDataResult(1);
        main.drain();
        assert shutters.equals(List.of("ring-A")) : "expected one exact-target shutter";

        helper.listener.bleDataResult(1);
        connectionEpoch++; // same ring recovered before dispatch
        main.drain();
        helper.listener.bleDataResult(1);
        main.drain();
        assert shutters.size() == 1 : "old connection triggered recovered ring";
        connectedId = "ring-B";
        setRemoteCamera(true);
        helper.listener.bleDataResult(1);
        main.drain();
        assert shutters.equals(List.of("ring-A", "ring-B"));

        helper.throwOnSwitch = true;
        try {
            setRemoteCamera(true);
            throw new AssertionError("expected failed SDK write");
        } catch (IllegalStateException expected) {
            helper.listener.bleDataResult(1);
            main.drain();
            assert shutters.size() == 2 : "failed camera mode accepted shutter";
        }
    }

    public static void main(String[] args) { new CoolWearPhotoTest().run(); }
}
