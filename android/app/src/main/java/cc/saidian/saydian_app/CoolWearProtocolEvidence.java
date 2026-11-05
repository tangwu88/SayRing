package cc.saidian.saydian_app;

/** Structural diagnostics only; never used to grant capabilities or emit records. */
final class CoolWearProtocolEvidence {
    private CoolWearProtocolEvidence() { }

    static String describe(int type, int itemLength, int itemCount, byte[] data) {
        if (type != 22 && type != 60 && type != 61 && type != 62) return null;
        String result = "protocol envelope; type=" + type + ",bytes=" + (data == null ? -1 : data.length)
                + ",itemLength=" + itemLength + ",itemCount=" + itemCount;
        if (type == 22) {
            // Original OEM capability constructor: byte 3 bit 1 = touch,
            // bit 2 = gesture music. R7U also returns a compact four-byte
            // standalone response with zero item tags; do not guess other shapes.
            boolean full = data != null && data.length == 8 && itemLength == 8 && itemCount == 1;
            boolean compact = data != null && data.length == 4 && itemLength == 0 && itemCount == 0;
            if (full || compact) {
                result += ",extendedTouch=" + ((data[3] & 2) != 0)
                        + ",gestureMusic=" + ((data[3] & 4) != 0);
            } else result += ",extensions=unconfirmed";
        }
        return result;
    }
}
