package cc.saidian.saydian_app;

import com.oudmon.ble.base.log.SdkLog;

/** Keep the SDK's new log sinks closed before any Bluetooth initialization. */
final class QRingSdkPrivacy {
    private QRingSdkPrivacy() {}

    static void disableLogs() {
        SdkLog.setConsoleLogEnabled(false);
        SdkLog.setFileLogEnabled(false);
        SdkLog.setFileRawDataEnabled(false);
        SdkLog.setPacketUuidEnabled(false);
    }
}
