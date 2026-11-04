package cc.saidian.saydian_app;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/** Exact batch accounting: remaining(u16 LE), count(u8), fixed-size records.
 * Only an explicit terminal and every unique record can prove completion.
 */
final class CoolWearHistoryBatch {
    private int expected;
    private boolean terminal, malformed;
    private final Set<Row> rows = new HashSet<>();
    boolean accept(byte[] payload) {
        // Some firmware returns an empty query response before its real upload.
        // It proves neither empty history nor a malformed historical batch.
        if (payload == null || payload.length == 0) return false;
        if (payload.length < 3) { malformed = true; return false; }
        int beforeRows = rows.size(), beforeExpected = expected;
        boolean beforeTerminal = terminal;
        int remaining = (payload[0] & 255) | ((payload[1] & 255) << 8);
        int count = payload[2] & 255;
        int body = payload.length - 3;
        if (count == 0 ? body != 0 : body == 0 || body % count != 0) {
            malformed = true; return false;
        }
        if (remaining + count > 16384) { malformed = true; return false; }
        expected = Math.max(expected, remaining + count);
        terminal |= remaining == 0;
        if (count > 0) {
            int size = body / count;
            for (int index = 0; index < count; index++) {
                rows.add(new Row(Arrays.copyOfRange(payload, 3 + index * size, 3 + (index + 1) * size)));
            }
        }
        if (rows.size() > expected) malformed = true;
        return !malformed && (beforeRows != rows.size() || beforeExpected != expected || beforeTerminal != terminal);
    }
    boolean complete() { return !malformed && terminal && rows.size() == expected; }
    String status() { return complete() ? (rows.isEmpty() ? "no_data" : "complete") : rows.isEmpty() ? "not_received" : "partial"; }
    private static final class Row {
        final byte[] bytes;
        Row(byte[] bytes) { this.bytes = bytes; }
        @Override public int hashCode() { return Arrays.hashCode(bytes); }
        @Override public boolean equals(Object other) { return other instanceof Row && Arrays.equals(bytes, ((Row) other).bytes); }
    }
}
