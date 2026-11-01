package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;

/** Executes the production bridge methods against a deterministic vendor transport. */
public final class QRingPhotoSessionHarness {
    interface ICommandResponse<T> { void onResponse(T value); }
    static final class MethodChannel {
        interface Result {
            void success(Object value);
            void error(String code, String message, Object details);
            void notImplemented();
        }
    }
    static final class Result implements MethodChannel.Result {
        int calls;
        String code;
        public void success(Object value) { calls++; }
        public void error(String code, String message, Object details) { calls++; this.code = code; }
        public void notImplemented() { throw new AssertionError("unexpected method"); }
    }
    static class BaseRspCmd {
        static final int RESULT_OK = 0;
        final int status;
        BaseRspCmd(int status) { this.status = status; }
        int getStatus() { return status; }
    }
    static final class CameraNotifyRsp extends BaseRspCmd {
        static final byte ACTION_TAKE_PHOTO = 2, ACTION_FINISH = 3;
        final byte action;
        CameraNotifyRsp(byte action) { super(RESULT_OK); this.action = action; }
        byte getAction() { return action; }
    }
    static final class CameraReq {
        static final byte ACTION_INTO_CAMARA_UI = 4, ACTION_KEEP_SCREEN_ON = 5, ACTION_FINISH = 6;
        final byte action;
        CameraReq(byte action) { this.action = action; }
    }
    static final class Constants { static final int CMD_TAKING_PICTURE = 2; }
    static final class SystemClock { static long now; static long elapsedRealtime() { return now; } }
    static final class Handler {
        record Task(long when, int order, Runnable run) implements Comparable<Task> {
            public int compareTo(Task other) {
                int byTime = Long.compare(when, other.when);
                return byTime == 0 ? Integer.compare(order, other.order) : byTime;
            }
        }
        final PriorityQueue<Task> queue = new PriorityQueue<>();
        int order;
        void post(Runnable run) { postDelayed(run, 0); }
        void postDelayed(Runnable run, long delay) { queue.add(new Task(SystemClock.now + delay, order++, run)); }
        void removeCallbacks(Runnable run) { queue.removeIf(task -> task.run() == run); }
        void drain() {
            while (!queue.isEmpty() && queue.peek().when() <= SystemClock.now) queue.remove().run().run();
        }
        void advance(long duration) {
            long target = SystemClock.now + duration;
            while (!queue.isEmpty() && queue.peek().when() <= target) {
                SystemClock.now = queue.peek().when(); drain();
            }
            SystemClock.now = target;
        }
    }
    static final class Manager {
        ICommandResponse<CameraNotifyRsp> listener;
        void addNotifyListener(int command, ICommandResponse<CameraNotifyRsp> listener) { this.listener = listener; }
        void removeNotifyListener(int command) { listener = null; }
        void notify(byte action) { if (listener != null) listener.onResponse(new CameraNotifyRsp(action)); }
    }
    static final class CommandHandle {
        record Request(byte action, ICommandResponse<BaseRspCmd> callback, boolean listenerRegistered) {
            void ack(int status) { callback.onResponse(new BaseRspCmd(status)); }
        }
        static CommandHandle instance;
        final QRingPhotoSessionHarness bridge;
        final List<Request> requests = new ArrayList<>();
        CommandHandle(QRingPhotoSessionHarness bridge) { this.bridge = bridge; instance = this; }
        static CommandHandle getInstance() { return instance; }
        void executeReqCmd(CameraReq request, ICommandResponse<BaseRspCmd> response) {
            requests.add(new Request(request.action, response, bridge.manager.listener != null));
        }
        Request last() { return requests.get(requests.size() - 1); }
    }
    static final class SupportFlags { boolean supportGesture = true, supportTouch; }
    final Handler main = new Handler();
    final Manager manager = new Manager();
    final SupportFlags supportFlags = new SupportFlags();
    final QRingControlChannelState controlChannels = new QRingControlChannelState();
    QRingControlChannelState.Channel pendingControlChannel;
    final List<String> events = new ArrayList<>();
    final CommandHandle transport = new CommandHandle(this);
    MethodChannel.Result pendingCamera;
    Object pendingSync, activeMeasurement, activeSportType;
    int connectionGeneration = 1, cameraOperation, remoteCameraEpoch;
    String connectedId = "exact-target";
    boolean connected = true, remoteCameraActive;
    Runnable remoteCameraKeepAlive;
    boolean resolved() { return connected; }
    boolean isCurrentConnection(int generation, String id) {
        return connected && generation == connectionGeneration && id.equals(connectedId);
    }
    void emit(String event, Map<String, Object> payload) {
        check(connectedId.equals(payload.get("deviceId")));
        events.add(event);
    }
    void traceControl(String stage) { }

    // PRODUCTION_METHODS

    static int checks;
    static void check(boolean condition) {
        checks++;
        if (!condition) throw new AssertionError("Photo session assertion failed at " + checks);
    }
    static QRingPhotoSessionHarness fresh() { SystemClock.now = 0; return new QRingPhotoSessionHarness(); }
    Result enter() { Result r = new Result(); remoteCameraCommand(CameraReq.ACTION_INTO_CAMARA_UI, r); return r; }
    public static void main(String[] args) {
        QRingPhotoSessionHarness b = fresh();
        check(b.canOpenRemoteCamera());
        check(!b.remoteCameraActive && b.transport.requests.isEmpty());
        b.supportFlags.supportGesture = false;
        check(!b.canOpenRemoteCamera());
        b.supportFlags.supportTouch = true;
        check(b.canOpenRemoteCamera());
        Result result = b.enter();
        check(b.transport.last().listenerRegistered());
        check(!b.remoteCameraActive && result.calls == 0);
        b.manager.notify(CameraNotifyRsp.ACTION_TAKE_PHOTO); b.main.drain();
        check(b.events.isEmpty());
        b.transport.last().ack(0); b.main.drain();
        check(b.remoteCameraActive && result.calls == 1 && result.code == null);
        b.manager.notify(CameraNotifyRsp.ACTION_TAKE_PHOTO); b.main.drain();
        check(b.events.equals(List.of("cameraShutter")));
        b.main.advance(10_000);
        check(b.transport.last().action() == CameraReq.ACTION_KEEP_SCREEN_ON);
        b.transport.last().ack(0); b.main.drain();
        Result stop = new Result(); b.stopRemoteCamera(stop);
        check(!b.remoteCameraActive && b.manager.listener == null);
        check(b.transport.last().action() == CameraReq.ACTION_FINISH);
        b.transport.last().ack(0); b.main.drain();
        check(stop.calls == 1 && stop.code == null);
        check(b.events.equals(List.of("cameraShutter", "cameraRemoteStopped")));

        b = fresh(); result = b.enter();
        CommandHandle.Request cancelledEnter = b.transport.last();
        stop = new Result(); b.stopRemoteCamera(stop);
        check(b.manager.listener == null && !b.remoteCameraActive && b.transport.requests.size() == 1);
        cancelledEnter.ack(0); b.main.drain();
        check(result.calls == 1 && "QRING_CONTROL_CANCELLED".equals(result.code));
        b.main.advance(100);
        check(b.transport.requests.size() == 2 && b.transport.last().action() == CameraReq.ACTION_FINISH);
        b.transport.last().ack(0); b.main.drain();
        check(stop.calls == 1 && !b.remoteCameraActive);

        b = fresh(); result = b.enter();
        b.transport.last().ack(1); b.main.drain();
        check("QRING_ACTION_FAILED".equals(result.code) && !b.remoteCameraActive && b.manager.listener == null);
        check(b.canOpenRemoteCamera());
        check(!b.controlChannels.blocked(QRingControlChannelState.Channel.PHOTO_UI, 1));
        result = b.enter(); b.transport.last().ack(0); b.main.drain();
        check(result.code == null && b.remoteCameraActive);
        ICommandResponse<CameraNotifyRsp> staleNotify = b.manager.listener;
        b.resetRemoteCamera(); b.enter(); b.transport.last().ack(0); b.main.drain();
        staleNotify.onResponse(new CameraNotifyRsp(CameraNotifyRsp.ACTION_TAKE_PHOTO)); b.main.drain();
        check(b.events.equals(List.of("cameraRemoteStopped")));
        b.manager.notify(CameraNotifyRsp.ACTION_TAKE_PHOTO); b.main.drain();
        check(b.events.get(1).equals("cameraShutter"));

        b = fresh(); result = b.enter(); CommandHandle.Request timedOut = b.transport.last();
        b.main.advance(8_000);
        check(result.calls == 1 && "QRING_CONTROL_UNCONFIRMED".equals(result.code));
        check(b.manager.listener == null && !b.remoteCameraActive && b.canOpenRemoteCamera());
        check(b.controlChannels.blocked(QRingControlChannelState.Channel.PHOTO_UI, 1));
        check(!b.controlChannels.blocked(QRingControlChannelState.Channel.HID, 1));
        timedOut.ack(0); b.main.drain();
        check(result.calls == 1 && !b.remoteCameraActive);
        check("QRING_CONTROL_UNCONFIRMED".equals(b.enter().code));
        b.connectionGeneration++; result = b.enter(); b.transport.last().ack(0); b.main.drain();
        check(result.calls == 1 && result.code == null && b.remoteCameraActive);

        b = fresh(); b.controlChannels.block(QRingControlChannelState.Channel.HID, 1);
        result = b.enter(); b.transport.last().ack(0); b.main.drain();
        check(result.code == null && b.remoteCameraActive);
        check(b.controlChannels.blocked(QRingControlChannelState.Channel.HID, 1));
        staleNotify = b.manager.listener; b.connectedId = "replacement-target";
        staleNotify.onResponse(new CameraNotifyRsp(CameraNotifyRsp.ACTION_TAKE_PHOTO)); b.main.drain();
        check(b.events.isEmpty());

        b = fresh(); b.pendingSync = new Object(); result = b.enter();
        check("DEVICE_BUSY".equals(result.code) && b.manager.listener == null && b.transport.requests.isEmpty());
        b = fresh(); b.connected = false; result = b.enter();
        check("QRING_FEATURE_UNVERIFIED".equals(result.code) && b.transport.requests.isEmpty());
        System.out.println("Android production Photo UI: " + checks + " behavioral assertions passed");
    }
}
