package cc.saidian.saydian_app;

/** A system bond event is useful only for this pending operation's exact ring. */
final class RingGestureBondPolicy {
    private RingGestureBondPolicy() { }
    static boolean accepts(String expected, long expectedEpoch, String received,
            long currentEpoch, boolean pending) {
        return pending && expected != null && !expected.isEmpty() && received != null
                && expectedEpoch == currentEpoch && expected.equalsIgnoreCase(received);
    }
}
