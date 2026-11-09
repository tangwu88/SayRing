package cc.saidian.saydian_app;

import java.util.HashMap;
import java.util.Map;

/** Exercises production initialization decisions with synthetic SDK responses. */
public final class QRingInitializationHarness {
    static final class MethodChannel {
        interface Result { void success(Object value); void error(String code, String message, Object details); }
    }
    static final class Reply implements MethodChannel.Result {
        int calls;
        String error;
        public void success(Object value) { calls++; }
        public void error(String code, String message, Object details) { calls++; error = code; }
    }
    static final class MethodCall {
        final Map<String, Object> values = new HashMap<>();
        @SuppressWarnings("unchecked") <T> T argument(String key) { return (T) values.get(key); }
    }
    static final class Handler {
        int delays;
        void post(Runnable action) { action.run(); }
        void postDelayed(Runnable action, long delay) { delays++; }
        void removeCallbacks(Runnable action) { }
    }
    static class BaseRspCmd {
        static final int RESULT_OK = 0;
        int getStatus() { return RESULT_OK; }
    }
    interface ICommandResponse<T> { void onResponse(T value); }
    static final class TargetSettingReq {
        final boolean write;
        final int[] values;
        TargetSettingReq(boolean write, int... values) { this.write = write; this.values = values; }
        static TargetSettingReq getReadInstance() { return new TargetSettingReq(false); }
        static TargetSettingReq getWriteInstance(int step, int calorie, int distance, int sport, int sleep) {
            return new TargetSettingReq(true, step, calorie, distance, sport, sleep);
        }
    }
    static final class TargetSettingRsp extends BaseRspCmd {
        static final int ACTION_READ = 0;
        final int[] values;
        TargetSettingRsp(int[] values) { this.values = values.clone(); }
        int getAction() { return ACTION_READ; }
        int getStep() { return values[0]; }
        int getCalorie() { return values[1]; }
        int getDistance() { return values[2]; }
        int getmSport() { return values[3]; }
        int getmSleep() { return values[4]; }
    }
    static final class CommandHandle {
        static CommandHandle instance;
        int reads, writes;
        int[] values = {8000, 350, 10, 30, 480};
        boolean badProfileRead, badGoalRead, badProfileFlags;
        static CommandHandle getInstance() { return instance; }
        void executeReqCmd(TargetSettingReq request, ICommandResponse<TargetSettingRsp> callback) {
            if (request.write) { writes++; values = request.values.clone(); }
            else reads++;
            int[] readback=values.clone();
            if (badGoalRead && !request.write && writes>0) readback[1]++;
            callback.onResponse(new TargetSettingRsp(readback));
        }
        void executeReqCmd(TimeFormatReq request, ICommandResponse<TimeFormatRsp> callback) {
            TimeFormatRsp reply=new TimeFormatRsp();reply.valid=!badProfileFlags;
            callback.onResponse(badProfileRead ? null : reply);
        }
    }
    static final class TimeFormatReq {static TimeFormatReq getReadInstance(){return new TimeFormatReq();}}
    static final class TimeFormatRsp extends BaseRspCmd {
        static final int ACTION_READ=0;
        boolean valid=true;
        int getAction(){return ACTION_READ;} boolean is24(){return valid;} boolean isMetric(){return valid;}
    }
    final Handler main = new Handler();
    String connectedId = "synthetic-ring", recoveryTargetId, recoveryTargetName, recoveryContext = "synthetic-owner";
    Map<String, Object> pendingProfile, recoveryProfile;
    Integer factoryResetGeneration, factoryInitializingGeneration;
    Runnable recoveryRetry;
    int phase, connectionGeneration = 4, profileWrites, emitted;
    long cutoff;
    boolean failPersistence;
    boolean cancellingConnection, recoveryConnecting;
    boolean resolved() { return connectedId != null; }
    boolean isValidBluetoothAddress(String id) { return "synthetic-ring".equals(id); }
    boolean isQRingName(String name) { return "R21".equals(name); }
    int factoryInitialization(String id, String context) { return phase; }
    long factorySyncNotBefore() {return cutoff;}
    boolean factoryInitializationPending(){return !QRingInitializationPolicy.complete(phase, cutoff);}
    boolean completeFactorySetup(String id,String context,int expected) {
        check(currentFactoryTarget(4,id,context));
        if (failPersistence || phase!=expected) return false;
        phase=QRingInitializationPolicy.completedPhase(expected);
        if(phase==13)cutoff=1234567890000L;
        return true;
    }
    void updateFactoryInitialization(String id, String context, int bits) { check(currentFactoryTarget(4, id, context)); phase |= bits; }
    boolean currentFactoryTarget(int generation, String id, String context) {
        return generation == connectionGeneration && id.equals(connectedId) && context.equals(recoveryContext);
    }
    int profileInt(String name, int fallback, int min, int max) { return 9000; }
    void disconnectWithResult(MethodChannel.Result result) { result.success(null); }
    void startAutomaticRecovery() { }
    void emit(String name, Map<String, Object> data) { emitted++; }
    void emitFactoryInitialization() { }
    Map<String, Object> capabilities() { return new HashMap<>(); }
    void writeProfileWithCompletion(Runnable completion) { profileWrites++; initializeFactoryTarget(completion); }

    // PRODUCTION_METHODS

    static int checks;
    static void check(boolean value) { if (!value) throw new AssertionError("Initialization assertion failed at " + checks); checks++; }
    static QRingInitializationHarness fresh(int phase) {
        CommandHandle.instance = new CommandHandle();
        QRingInitializationHarness value = new QRingInitializationHarness(); value.phase = phase; return value;
    }
    public static void main(String[] args) {
        MethodCall call = new MethodCall(); call.values.put("id", "synthetic-ring");
        call.values.put("name", "R21"); call.values.put("context", "synthetic-owner");
        for (int phase : new int[] {0, 2, 4, 5, 6, 7, -1, 11}) {
            QRingInitializationHarness b = fresh(phase); Reply reply = new Reply();
            b.configureRecoveryTarget(call, reply);
            check(reply.calls == 1 && reply.error == null && b.profileWrites == 0 && b.phase == phase);
            check(CommandHandle.instance.reads == 0 && CommandHandle.instance.writes == 0 && b.main.delays == 0);
            final int[] finished = {0}; b.initializeFactoryTarget(() -> finished[0]++);
            check(finished[0] == 1 && b.phase == phase && b.main.delays == 0);
            check(CommandHandle.instance.reads == 0 && CommandHandle.instance.writes == 0);
        }
        QRingInitializationHarness b = fresh(3); Reply reply = new Reply();
        b.configureRecoveryTarget(call, reply);
        check(reply.calls == 1 && reply.error == null && b.profileWrites == 1 && b.phase == 7);
        check(CommandHandle.instance.reads == 2 && CommandHandle.instance.writes == 1);
        check(CommandHandle.instance.values[0] == 9000 && CommandHandle.instance.values[1] == 350
                && CommandHandle.instance.values[2] == 10 && CommandHandle.instance.values[3] == 30
                && CommandHandle.instance.values[4] == 480);
        check(b.factoryInitializingGeneration == null);
        b = fresh(3); b.factoryResetGeneration = 4; reply = new Reply(); b.configureRecoveryTarget(call, reply);
        check(reply.calls == 1 && b.profileWrites == 0 && b.phase == 3);
        b = fresh(3); b.connectedId = "other-ring"; reply = new Reply(); b.configureRecoveryTarget(call, reply);
        check(reply.calls == 1 && b.profileWrites == 0 && b.phase == 3);
        b=fresh(1);reply=new Reply();b.configureRecoveryTarget(call,reply);
        check(b.phase==13 && b.cutoff>0 && b.profileWrites==1 && (b.phase&2)==0);
        long fixed=b.cutoff;int writes=CommandHandle.instance.writes;
        b.configureRecoveryTarget(call,new Reply());b.initializeFactoryTarget(()->{});
        check(b.cutoff==fixed && CommandHandle.instance.writes==writes && b.profileWrites==1);
        b=fresh(1);b.factoryResetGeneration=4;b.configureRecoveryTarget(call,new Reply());
        check(b.phase==1 && b.profileWrites==0 && CommandHandle.instance.writes==0);
        b=fresh(1);CommandHandle.instance.badProfileRead=true;b.configureRecoveryTarget(call,new Reply());
        check(b.phase==1 && b.cutoff==0);
        b=fresh(1);CommandHandle.instance.badGoalRead=true;b.configureRecoveryTarget(call,new Reply());
        check(b.phase==1 && b.cutoff==0);
        b=fresh(1);CommandHandle.instance.badProfileFlags=true;b.configureRecoveryTarget(call,new Reply());
        check(b.phase==1 && b.cutoff==0);
        b=fresh(1);b.failPersistence=true;b.configureRecoveryTarget(call,new Reply());
        check(b.phase==1 && b.cutoff==0);
        System.out.println("Production Android initialization assertions: " + checks);
    }
}
