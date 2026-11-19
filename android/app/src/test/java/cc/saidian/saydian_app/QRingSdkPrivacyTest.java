package cc.saidian.saydian_app;

import com.oudmon.ble.base.log.SdkLog;
import org.junit.Test;
import static org.junit.Assert.*;

public class QRingSdkPrivacyTest {
    @Test public void closesActualSdkLogSinksEvenAfterTheyWereEnabled() {
        try {
            SdkLog.setConsoleLogEnabled(true);
            SdkLog.setFileLogEnabled(true);
            SdkLog.setFileRawDataEnabled(true);
            SdkLog.setPacketUuidEnabled(true);
            assertTrue(SdkLog.isConsoleLogEnabled());
            assertTrue(SdkLog.isFileLogEnabled());
            assertTrue(SdkLog.isFileRawDataEnabled());
            assertTrue(SdkLog.isPacketUuidEnabled());
        } finally {
            QRingSdkPrivacy.disableLogs();
        }
        assertFalse(SdkLog.isConsoleLogEnabled());
        assertFalse(SdkLog.isFileLogEnabled());
        assertFalse(SdkLog.isFileRawDataEnabled());
        assertFalse(SdkLog.isPacketUuidEnabled());
    }
}
