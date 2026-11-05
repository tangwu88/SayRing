package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;

/** Real bridge methods; only radio, clock, capabilities and Flutter are fakes. */
public final class QRingGestureExclusionHarness {
    final Main main = new Main();
    final Flags supportFlags = new Flags();
    final QRingControlChannelState controlChannels = new QRingControlChannelState();
    QRingControlChannelState.Channel pendingControlChannel;
    MethodChannel.Result pendingCamera;
    Object pendingSync, activeMeasurement, activeSportType;
    int cameraPhase, cameraOperation, connectionGeneration = 1;
    String connectedId = "synthetic-owned";
    final Radio radio = new Radio();
    final Result result = new Result();
    boolean current = true;
    final List<String> traces = new ArrayList<>();

    // PRODUCTION_METHODS

    boolean supportsGesture() { return true; }
    List<Integer> gestureModes(boolean touch) { return List.of(0, 1, 2, 3, 4, 5); }
    boolean currentCamera(int op, int conn, String id) {
        return current && pendingCamera != null && op == cameraOperation
                && conn == connectionGeneration && id.equals(connectedId);
    }
    void traceControl(String stage) { traces.add(stage); }
    Map<String, Object> cameraSnapshot(TouchControlResp rsp, boolean touch) {
        return rsp == null || rsp.getStatus() != 0 || !rsp.isRead() || rsp.isTouch() != touch
                ? null : QRingCameraPolicy.snapshot(rsp.mode, rsp.strength, touch, rsp.duration);
    }
    void finishCamera(Object value, String code, String message) {
        var pending = pendingCamera; pendingCamera = null;
        if (pending != null) {
            if (code == null) pending.success(value); else pending.error(code, message, null);
        }
    }
    void write(int app, boolean stop) {
        CommandHandle.radio = radio;
        var values = new HashMap<String, Object>();
        values.put("mode", app); values.put("expectedMode", radio.gestureMode);
        if (stop) values.put("stopControl", true);
        gestureControl(new MethodCall(Map.of("values", values)), true, result);
    }
    static void check(boolean yes, String message) { if (!yes) throw new AssertionError(message); }
    public static void main(String[] args) {
        var h = new QRingGestureExclusionHarness();
        h.write(1, false); h.main.drain();
        check(h.radio.writes.equals(List.of("touch:0:0:3", "gesture:2:6:0")),
                "other channel must close before selected write");
        check(h.result.ok && h.radio.touchMode == 0 && h.radio.gestureMode == 2,
                "both real readbacks precede success");
        check(h.radio.strength == 6 && h.radio.duration == 3, "preserve original parameters");
        h = new QRingGestureExclusionHarness(); h.radio.touchMode = 0;
        h.write(3, false); h.main.drain();
        check(h.result.ok && h.radio.writes.equals(List.of("gesture:4:6:0")),
                "already-off channel is read only and reading maps to raw four");
        h = new QRingGestureExclusionHarness(); h.radio.gestureMode = 0; h.radio.strength = 0;
        h.write(0, true); h.main.drain();
        check(h.result.ok && h.radio.writes.equals(List.of("touch:0:0:3", "gesture:0:0:0")),
                "stop both supported channels without inventing sensitivity");
        h = new QRingGestureExclusionHarness(); h.radio.rejectClose = true;
        h.write(1, false); h.main.drain();
        check(!h.result.ok && h.result.code != null && h.radio.writes.size() == 1,
                "rejected other close cannot enable a scene");
        h = new QRingGestureExclusionHarness(); h.radio.ignoreClose = true;
        h.write(1, false); h.main.drain();
        check(!h.result.ok && h.radio.writes.size() == 1 && h.radio.touchReads == 4,
                "ACK alone cannot replace bounded other-channel readback");
        h = new QRingGestureExclusionHarness(); h.radio.invalidOther = true;
        h.write(1, false); h.main.drain();
        check(!h.result.ok && h.radio.writes.isEmpty(), "invalid other read cannot write");
        h = new QRingGestureExclusionHarness(); h.radio.changeDuration = true;
        h.write(1, false); h.main.drain();
        check(!h.result.ok && h.radio.writes.size() == 1, "changed sleep parameter is not confirmed");
        h = new QRingGestureExclusionHarness(); h.supportFlags.supportTouch = false;
        h.write(1, false); h.main.drain();
        check(h.result.ok && h.radio.touchReads == 0 && h.radio.writes.size() == 1,
                "unsupported other channel is not probed");
        h = new QRingGestureExclusionHarness();
        var stale = h; h.radio.beforeCloseAck = () -> stale.connectionGeneration++;
        h.write(1, false); h.main.drain();
        check(!h.result.ok && h.radio.writes.size() == 1, "stale close cannot enable new connection");
        h = new QRingGestureExclusionHarness(); CommandHandle.radio = h.radio;
        h.gestureControl(new MethodCall(Map.of()), false, h.result); h.main.drain();
        check(h.result.ok && h.radio.writes.isEmpty() && h.radio.touchReads == 0,
                "ordinary read changes no settings");
        System.out.println("QRing exclusion PASS: 10 scenarios");
    }
    static final class Flags { boolean supportGesture = true, supportTouch = true, supportRt11; }
    static final class Main {
        record Job(long time, long seq, Runnable run) { }
        long time, seq;
        final PriorityQueue<Job> queue = new PriorityQueue<>(Comparator.comparingLong(Job::time).thenComparingLong(Job::seq));
        void post(Runnable run) { postDelayed(run, 0); }
        void postDelayed(Runnable run, long delay) { queue.add(new Job(time + delay, seq++, run)); }
        void drain() { int count = 0; while (!queue.isEmpty()) {
            check(++count < 100, "bounded jobs"); var job = queue.remove(); time = job.time(); job.run().run();
        } }
    }
    static final class MethodCall {
        final Map<String, Object> values;
        MethodCall(Map<String, Object> values) { this.values = values; }
        <T> T argument(String key) { @SuppressWarnings("unchecked") T value = (T) values.get(key); return value; }
    }
    static final class MethodChannel { interface Result {
        void success(Object value); void error(String code, String message, Object details);
    } }
    static final class Result implements MethodChannel.Result {
        boolean ok; String code;
        public void success(Object value) { ok = true; }
        public void error(String code, String message, Object details) { this.code = code; }
    }
    interface ICommandResponse<T> { void onResponse(T value); }
    static final class BaseRspCmd { static final int RESULT_OK = 0; }
    static final class TouchControlResp {
        int mode, strength, duration = 3, status; boolean read, touch;
        boolean isRead() { return read; } boolean isTouch() { return touch; }
        int getStatus() { return status; }
    }
    static final class TouchControlReq {
        int mode, strength, duration; boolean touch, read;
        static TouchControlReq getReadInstance(boolean touch) {
            var req = new TouchControlReq(); req.touch = touch; req.read = true; return req;
        }
        static TouchControlReq getWriteInstance(int mode, boolean touch, int strength, int duration) {
            var req = new TouchControlReq(); req.mode = mode; req.touch = touch;
            req.strength = strength; req.duration = duration; return req;
        }
    }
    static final class Radio {
        int touchMode = 4, gestureMode = 1, strength = 6, duration = 3, touchReads;
        boolean rejectClose, ignoreClose, invalidOther, changeDuration;
        Runnable beforeCloseAck;
        final List<String> writes = new ArrayList<>();
        void execute(TouchControlReq req, ICommandResponse<TouchControlResp> callback) {
            var rsp = new TouchControlResp(); rsp.read = req.read; rsp.touch = req.touch;
            if (req.read) {
                if (req.touch) touchReads++;
                rsp.mode = req.touch ? touchMode : gestureMode;
                rsp.strength = strength; rsp.duration = duration;
                if (req.touch && invalidOther) rsp.status = 1;
            } else {
                writes.add((req.touch ? "touch:" : "gesture:") + req.mode + ":" + req.strength + ":" + req.duration);
                if (req.touch && rejectClose) rsp.status = 1;
                else if (!ignoreClose || !req.touch) {
                    if (req.touch) touchMode = req.mode; else gestureMode = req.mode;
                }
                if (req.touch && changeDuration) duration++;
                if (req.touch && beforeCloseAck != null) beforeCloseAck.run();
            }
            callback.onResponse(rsp);
        }
    }
    static final class CommandHandle {
        static Radio radio;
        static CommandHandle getInstance() { return new CommandHandle(); }
        void executeReqCmd(TouchControlReq req, ICommandResponse<TouchControlResp> callback) { radio.execute(req, callback); }
    }
}
