package cc.saidian.saydian_app;

/** Phone notification relay is separate from a firmware notification switch. */
final class CoolWearNotificationPolicy {
    private CoolWearNotificationPolicy() { }

    static boolean canRelay(String model, boolean connected, boolean deviceInfo,
            boolean functionControl, boolean reminderPacket) {
        if (!connected || !deviceInfo || !functionControl || !reminderPacket) return false;
        return "R7Pro".equals(model) || "R7Ultra".equals(model) || "HR05".equals(model);
    }
}
