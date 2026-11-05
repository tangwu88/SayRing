package cc.saidian.saydian_app;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Executes the production gesture entry/ACK/rollback methods, without a radio. */
public final class CoolWearGesturePairingHarness {
    private final CoolWearGestureState gesture = new CoolWearGestureState();
    private MethodChannel.Result pendingGesture;
    private String gesturePairingFailureCode, gesturePairingFailureMessage;
    private Runnable gestureDeadline;
    private Object gestureBondReceiver;
    private Object pendingConnect, pendingScan, pendingHealthSync, pendingSportSync;
    private Object pendingAutoSettings, pendingReminders, activeMeasurement, activeSportMode;
    private final Main main = new Main();
    private final Activity activity = new Activity();
    private final Helper helper = new Helper();
    private boolean ready = true, bonded, rejectBond;
    private int pairRequests;
    private final Result result = new Result();

    // PRODUCTION_METHODS

    private boolean canUseGesture() { return ready; }
    private boolean prepareGestureBond(int mode) {
        if (bonded) return false;
        pairRequests++;
        if (rejectBond) throw new IllegalStateException("synthetic pairing failure");
        gestureBondReceiver = new Object();
        gestureDeadline = () -> rollbackGesturePairing("PAIR_TIMEOUT", "pair timeout");
        main.postDelayed(gestureDeadline, 30_000L);
        return true;
    }
    private void begin(int mode) { writeGesture(Map.of("mode", mode), result); }
    private void ack(int mode) { onGestureMode(mode, gesture.generation()); }
    private static void require(boolean ok, String text) {
        if (!ok) throw new AssertionError(text);
    }
    public static void main(String[] args) {
        var h = new CoolWearGesturePairingHarness();
        h.begin(1);
        require(h.helper.modes.equals(List.of(1)), "scene must precede OS bond");
        require(h.pairRequests == 0 && !h.result.done, "no pairing or success before ACK");
        h.ack(2);
        require(h.pairRequests == 0, "wrong ACK cannot request pairing");
        h.ack(1);
        require(h.pairRequests == 1 && !h.result.done, "ACK starts pairing, not success");
        require(h.main.waiters.size() == 1, "old scene timeout must be retired before pairing");
        h.rollbackGesturePairing("CANCELLED", "cancelled");
        require(h.helper.modes.equals(List.of(1, 0)) && !h.result.done,
                "cancel sends close and waits for its ACK");
        h.ack(1);
        require(!h.result.done, "late enable ACK cannot confirm close");
        h.ack(0);
        require("CANCELLED".equals(h.result.error) && h.gesture.confirmedMode() == 0,
                "cancel remains failure and close is actually confirmed");
        require(h.main.waiters.isEmpty() && h.gestureBondReceiver == null,
                "terminal must clear pairing receiver/timers");

        h = new CoolWearGesturePairingHarness(); h.begin(0); h.ack(0);
        require(h.result.success && h.pairRequests == 0, "close never requests pairing");
        h = new CoolWearGesturePairingHarness(); h.bonded = true; h.begin(1); h.ack(1);
        require(h.result.success && h.pairRequests == 0, "existing OS bond is preserved");
        h = new CoolWearGesturePairingHarness(); h.begin(1);
        h.gestureDeadline.run();
        require(h.gesture.requiresReconnect() && h.pairRequests == 0 && !h.result.success,
                "missing scene ACK cannot request pairing or claim success");
        h = new CoolWearGesturePairingHarness(); h.begin(1); h.ack(1);
        h.gestureDeadline.run();
        require(h.helper.modes.equals(List.of(1, 0)) && !h.result.done,
                "OS timeout must start bounded close cleanup");
        h.gestureDeadline.run();
        require(h.gesture.requiresReconnect() && h.gesture.confirmedMode() == null
                && !h.result.success, "lost close ACK stays uncertain");
        h = new CoolWearGesturePairingHarness(); h.rejectBond = true; h.begin(1); h.ack(1);
        require(h.helper.modes.equals(List.of(1, 0)), "pairing exception closes same scene");
        h.ack(0); require(!h.result.success, "pairing exception is never successful");
        h = new CoolWearGesturePairingHarness(); h.begin(1); h.ack(1); h.ready = false;
        h.rollbackGesturePairing("RETIRED", "retired");
        require(h.helper.modes.equals(List.of(1)) && !h.result.success,
                "lost connection cannot send cleanup to another target");
        h = new CoolWearGesturePairingHarness(); h.begin(1);
        long generation = h.gesture.generation(); h.resetGesture("RETIRED", "retired");
        h.onGestureMode(1, generation);
        require(h.pairRequests == 0, "retired ACK cannot request pairing");
        System.out.println("Production gesture pairing PASS");
    }
    private static final class Main {
        final Set<Runnable> waiters = new HashSet<>();
        void removeCallbacks(Runnable value) { waiters.remove(value); }
        void postDelayed(Runnable value, long delay) { waiters.add(value); }
    }
    private static final class Activity { void unregisterReceiver(Object value) { } }
    private static final class Helper {
        final List<Integer> modes = new ArrayList<>();
        Helper getSendBlueData() { return this; }
        void sendGestureConfig(int mode) { modes.add(mode); }
    }
    private static final class MethodChannel {
        interface Result {
            void success(Object value);
            void error(String code, String message, Object details);
        }
    }
    private static final class Result implements MethodChannel.Result {
        boolean done, success;
        String error;
        public void success(Object value) { done = true; success = true; }
        public void error(String code, String message, Object details) { done = true; error = code; }
    }
}
