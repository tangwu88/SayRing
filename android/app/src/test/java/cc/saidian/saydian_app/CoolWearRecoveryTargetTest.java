package cc.saidian.saydian_app;

import org.junit.Test;
import static org.junit.Assert.*;

/** SDK 安装缓存与业务绑定分开；这些是宿主协议测试，不替代实体戒指验收。 */
public class CoolWearRecoveryTargetTest {
    private static final class FakeSdk implements CoolWearRecoveryTarget.Sdk {
        String ram = "old-target", stored = "old-target";
        final String businessBinding = "owner-target", bond = "system-bond";
        final int healthRecords = 134, reminderInterval = 30;
        int clears, writes, disconnects;
        boolean clearFails, writeFails;
        Runnable onDisconnect;

        @Override public void clearTarget() {
            clears++;
            if (clearFails) throw new IllegalStateException("cache unavailable");
            ram = "";
            stored = "";
        }
        @Override public void setTarget(String target) {
            writes++;
            if (writeFails) throw new IllegalStateException("cache unavailable");
            ram = target;
            stored = target;
        }
        @Override public void disconnect() {
            disconnects++;
            ram = ""; // 对照原 AAR：普通 disConnect 只清 RAM，不清持久地址。
            if (onDisconnect != null) onDisconnect.run();
        }
        boolean vendorTimerCanRestore() { return !ram.isEmpty() || !stored.isEmpty(); }
    }

    @Test public void idleInitializationRemovesOnlyVendorRecoveryTarget() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.initializeIdle(sdk);
        assertFalse(sdk.vendorTimerCanRestore());
        assertEquals(0, sdk.disconnects);
        assertEquals("owner-target", sdk.businessBinding);
        assertEquals("system-bond", sdk.bond);
        assertEquals(134, sdk.healthRecords);
        assertEquals(30, sdk.reminderInterval);
    }

    @Test public void ordinaryPausePreventsVendorTimerFromRestoringOldTarget() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        long before = state.generation();
        state.pause(sdk);
        assertFalse(state.isActive());
        assertFalse(state.isCurrent(before));
        assertFalse(sdk.vendorTimerCanRestore());
        assertEquals(1, sdk.disconnects);
    }

    @Test public void pauseRevokesBeforeSynchronousDisconnectCallback() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        sdk.onDisconnect = () -> {
            assertFalse(state.isActive());
            assertFalse(state.acceptCallback(state.generation(), false, sdk));
        };
        state.pause(sdk);
        assertEquals(1, sdk.disconnects);
        assertFalse(sdk.vendorTimerCanRestore());
    }

    @Test public void activeNaturalDisconnectRetainsAuthorizedRecovery() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        assertTrue(state.acceptCallback(state.generation(), false, sdk));
        assertTrue(state.isActive());
        assertEquals("authorized-A", sdk.stored);
        assertEquals(0, sdk.clears);
        assertEquals(0, sdk.disconnects);
    }

    @Test public void lateInactiveConnectionCannotRepopulateInstallationTarget() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        state.pause(sdk);
        // 模拟暂停前已读出旧地址的厂商 timer 晚到一次；不能重新获得授权。
        sdk.ram = "old-target";
        sdk.stored = "old-target";
        assertFalse(state.acceptCallback(state.generation(), true, sdk));
        assertFalse(sdk.vendorTimerCanRestore());
        assertEquals(2, sdk.disconnects);
    }

    @Test public void inactiveDisconnectedCallbackClearsCacheWithoutDisconnectLoop() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        assertFalse(state.acceptCallback(state.generation(), false, sdk));
        assertFalse(sdk.vendorTimerCanRestore());
        assertEquals(0, sdk.disconnects);
    }

    @Test public void queuedOldCallbackNeverDisconnectsNewAuthorizedTarget() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        long old = state.generation();
        state.pause(sdk);
        state.activate("authorized-B", sdk);
        int clears = sdk.clears, disconnects = sdk.disconnects;
        assertFalse(state.acceptCallback(old, true, sdk));
        assertFalse(state.acceptCallback(old, false, sdk));
        assertEquals("authorized-B", sdk.stored);
        assertEquals(clears, sdk.clears);
        assertEquals(disconnects, sdk.disconnects);
        assertTrue(state.acceptCallback(state.generation(), true, sdk));
    }

    @Test public void scanAndCapabilityQueriesDoNotRevokeActiveTarget() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        long generation = state.generation();
        state.initializeIdle(sdk);
        state.initializeIdle(sdk);
        assertEquals("authorized-A", sdk.stored);
        assertEquals(0, sdk.clears);
        assertEquals(generation, state.generation());
    }

    @Test public void explicitNewConnectWorksBeforeOldTimerWouldHaveRun() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        state.pause(sdk);
        state.initializeIdle(sdk);
        state.activate("authorized-B", sdk);
        assertTrue(sdk.vendorTimerCanRestore());
        assertEquals("authorized-B", sdk.ram);
        assertEquals("authorized-B", sdk.stored);
        assertTrue(state.acceptCallback(state.generation(), true, sdk));
    }

    @Test public void cacheFailureStillDisconnectsAndKeepsLeaseRevoked() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        state.activate("authorized-A", sdk);
        sdk.clearFails = true;
        try { state.pause(sdk); fail("failure must remain observable"); }
        catch (IllegalStateException expected) { /* 不能伪造已清理。 */ }
        assertFalse(state.isActive());
        assertEquals(1, sdk.disconnects);
    }

    @Test public void failedOrEmptyActivationNeverAuthorizesCallbacks() {
        CoolWearRecoveryTarget state = new CoolWearRecoveryTarget();
        FakeSdk sdk = new FakeSdk();
        long before = state.generation();
        try { state.activate("", sdk); fail("empty target"); }
        catch (IllegalArgumentException expected) { }
        assertFalse(state.isActive());
        assertEquals(0, sdk.writes);
        sdk.writeFails = true;
        try { state.activate("authorized-A", sdk); fail("failed cache write"); }
        catch (IllegalStateException expected) { }
        assertFalse(state.isActive());
        assertFalse(state.isCurrent(before));
    }
}
