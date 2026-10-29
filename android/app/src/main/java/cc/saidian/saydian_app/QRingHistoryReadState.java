package cc.saidian.saydian_app;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;

/** Tracks acknowledgements, not health values, for one serial history request. */
final class QRingHistoryReadState {
    static final class Ticket {
        final long generation;
        final String metric;
        Ticket(long generation, String metric) {
            this.generation = generation;
            this.metric = metric;
        }
    }

    private static final class Reads {
        int received;
        boolean failed;
        boolean hasData;
    }

    private final Map<String, Reads> reads = new LinkedHashMap<>();
    private long generation;
    private int expectedDays;
    private Ticket active;

    void begin(Collection<String> metrics, int days) {
        cancel();
        reads.clear();
        expectedDays = days;
        for (String metric : metrics) reads.put(metric, new Reads());
    }

    Ticket open(String metric) {
        if (active != null) throw new IllegalStateException("History reads must be serial");
        if (!reads.containsKey(metric)) reads.put(metric, new Reads());
        active = new Ticket(generation, metric);
        return active;
    }

    boolean accept(Ticket ticket, boolean succeeded, boolean hasData) {
        if (ticket == null || ticket != active || ticket.generation != generation) return false;
        active = null;
        Reads value = reads.get(ticket.metric);
        value.received++;
        value.failed |= !succeeded;
        value.hasData |= succeeded && hasData;
        return true;
    }

    Map<String, String> statuses() {
        Map<String, String> result = new LinkedHashMap<>();
        for (Map.Entry<String, Reads> entry : reads.entrySet()) {
            Reads value = entry.getValue();
            result.put(entry.getKey(), value.failed || value.received != expectedDays
                    ? "failed" : value.hasData ? "complete" : "no_data");
        }
        return result;
    }

    void cancel() {
        generation++;
        active = null;
    }
}
