package cc.saidian.saydian_app;

import com.oudmon.ble.base.communication.req.BaseReqCmd;
import com.oudmon.ble.base.communication.req.BloodOxygenSettingReq;
import com.oudmon.ble.base.communication.req.HeartRateSettingReq;
import com.oudmon.ble.base.communication.req.PressureSettingReq;
import com.oudmon.ble.base.communication.req.SugarLipidsSettingReq;
import com.oudmon.ble.base.communication.rsp.BaseRspCmd;
import com.oudmon.ble.base.communication.rsp.BloodOxygenSettingRsp;
import com.oudmon.ble.base.communication.rsp.BloodSugarLipidsSettingRsp;
import com.oudmon.ble.base.communication.rsp.HeartRateSettingRsp;
import com.oudmon.ble.base.communication.rsp.PressureSettingRsp;
import com.oudmon.ble.base.communication.rsp.MixtureRsp;
import java.util.HashMap;
import java.util.Map;

/** Independent firmware settings. Missing interval fields never become defaults. */
public final class QRingMonitoringSetting {
    public final boolean enabled;
    public final int minutes, minimum;

    private QRingMonitoringSetting(boolean enabled, int minutes, int minimum) {
        this.enabled = enabled;
        this.minutes = minutes;
        this.minimum = minimum;
    }

    public boolean hasInterval() {
        return minimum >= 1 && minimum <= 255 && minutes >= minimum && minutes <= 255;
    }

    public static QRingMonitoringSetting read(String type, BaseRspCmd response) {
        if (response == null || response.getStatus() != BaseRspCmd.RESULT_OK) return null;
        if (response instanceof MixtureRsp && ((MixtureRsp) response).getAction() != MixtureRsp.ACTION_READ) return null;
        switch (type) {
            case "heartRate":
                if (!(response instanceof HeartRateSettingRsp)) return null;
                HeartRateSettingRsp heart = (HeartRateSettingRsp) response;
                return new QRingMonitoringSetting(heart.isEnable(), heart.getHeartInterval(), heart.getStartInterval());
            case "bloodOxygen":
                if (!(response instanceof BloodOxygenSettingRsp)) return null;
                BloodOxygenSettingRsp oxygen = (BloodOxygenSettingRsp) response;
                return new QRingMonitoringSetting(oxygen.isEnable(), oxygen.getInterval() & 0xff, 1);
            case "stress":
                if (!(response instanceof PressureSettingRsp)) return null;
                PressureSettingRsp pressure = (PressureSettingRsp) response;
                return new QRingMonitoringSetting(pressure.isEnable(), pressure.getInterval(),
                        pressure.isIntervalSettingSupported() ? pressure.getMinInterval() : 0);
            case "bodyTemperature":
                if (!(response instanceof BloodSugarLipidsSettingRsp)) return null;
                BloodSugarLipidsSettingRsp temperature = (BloodSugarLipidsSettingRsp) response;
                if (!temperature.isRead() || temperature.getType() != SugarLipidsSettingReq.TYPE_TEMPERATURE) return null;
                return new QRingMonitoringSetting(temperature.isEnable(), temperature.getInterval(), temperature.getStartInterval());
            default: return null;
        }
    }

    public Map<String, Object> intervalMap() {
        if (!hasInterval()) return null;
        Map<String, Object> value = new HashMap<>();
        value.put("minutes", minutes);
        value.put("stepMinutes", 1);
        value.put("minMinutes", minimum);
        value.put("maxMinutes", 255);
        value.put("canModify", true);
        return value;
    }

    public BaseReqCmd write(String type, Integer requestedMinutes, Boolean requestedEnabled) {
        if (requestedMinutes != null && (!hasInterval() || !enabled
                || requestedMinutes < minimum || requestedMinutes > 255)) {
            throw new IllegalArgumentException("Unsupported monitoring interval");
        }
        boolean nextEnabled = requestedEnabled == null ? enabled : requestedEnabled;
        int nextMinutes = requestedMinutes == null ? minutes : requestedMinutes;
        switch (type) {
            case "heartRate":
                if (!hasInterval()) throw new IllegalArgumentException("Missing heart interval");
                return HeartRateSettingReq.getWriteInstance(nextEnabled, nextMinutes);
            case "bloodOxygen":
                return hasInterval() ? BloodOxygenSettingReq.getWriteInstance(nextEnabled, (byte) nextMinutes)
                        : BloodOxygenSettingReq.getWriteInstance(nextEnabled);
            case "stress":
                synchronized (PressureSettingReq.class) {
                    // SDK caches these globally. Scope both setup and cleanup to this one encoder.
                    PressureSettingReq.clearCachedIntervalSettings();
                    try {
                        if (hasInterval()) PressureSettingReq.cacheIntervalSettings(minimum, nextMinutes);
                        return PressureSettingReq.getWriteInstance(nextEnabled);
                    } finally { PressureSettingReq.clearCachedIntervalSettings(); }
                }
            case "bodyTemperature":
                return hasInterval() ? SugarLipidsSettingReq.getWriteTemperatureInstance(nextEnabled, nextMinutes)
                        : SugarLipidsSettingReq.getWriteTemperatureInstance(nextEnabled);
            default: throw new IllegalArgumentException("Unsupported monitoring type");
        }
    }
}
