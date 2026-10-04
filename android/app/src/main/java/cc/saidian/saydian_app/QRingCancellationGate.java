package cc.saidian.saydian_app;

/** Cancellation is complete only for the current target after real SDK teardown. */
final class QRingCancellationGate {
    private QRingCancellationGate() { }

    static boolean canFinish(boolean currentGeneration, boolean sameTarget,
            boolean cancelling, boolean sdkConnected, boolean sdkConnecting,
            boolean hasTargetGatt) {
        return currentGeneration && sameTarget && cancelling
                && !sdkConnected && !sdkConnecting && !hasTargetGatt;
    }
}
