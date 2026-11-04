package cc.saidian.saydian_app;

import java.util.Objects;

import ce.com.cenewbluesdk.CEBC;
import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.entity.k6.K6_CESyncTime;

/** 原厂公开请求帧边界：普通读取不得借用会打包缓存设置的“同步”方法。 */
final class CoolWearReadRequests {
    private CoolWearReadRequests() { }

    enum Kind {
        DEVICE_INFO(CEBC.K6.DATA_TYPE_DEVINFO),
        BATTERY(CEBC.K6.DATA_TYPE_BATTERY_INFO),
        MIXED_INFO(CEBC.K6.DATA_TYPE_DEV_SYNC),
        CAPABILITIES(CEBC.K6.DATA_TYPE_FUNCTION_CONTROL),
        TIME(CEBC.K6.DATA_TYPE_TIME),
        SEDENTARY(CEBC.K6.DATA_TYPE_SITTING_REMIND),
        DRINKING(CEBC.K6.DATA_TYPE_DRINK_ALARM),
        AUTO_MONITORING(CEBC.K6.DATA_TYPE_HEART_AUTO_SWITCH);

        final int dataType;
        Kind(int dataType) { this.dataType = dataType; }
    }

    static CEDevData query(Kind kind) {
        Objects.requireNonNull(kind, "read kind");
        // 与原 AAR getDevInfo/sendGetSittingRemind 使用相同的 REQUEST 编码，
        // 只设置公开类型，不附加资料、目标、提醒、绑定或缓存混合设置。
        CEDevData request = new CEDevData();
        request.setCmd(CEBC.K6.CMD_TYPE_REQUEST);
        request.setDataType(kind.dataType);
        return request;
    }

    static CEDevData connectionClockUpdate(K6_CESyncTime phone, int format, int mdFormat) {
        Objects.requireNonNull(phone, "phone time");
        if ((format != 0 && format != 1) || (mdFormat != 0 && mdFormat != 1)) {
            throw new IllegalArgumentException("Unconfirmed device time format");
        }
        // 校时是独立、明确的连接动作。使用本轮真实回读的显示格式，不把
        // SDK 安装缓存的 12/24 小时或月日顺序覆盖到戒指，也不改其它设置。
        // phone 是调用方刚创建的时钟对象；不经 SDK 接收构造器重新解码时间，
        // 避免接收构造器的字节重排改变本来正确的出站时间戳。
        phone.setFormat(format);
        phone.setMdFormat(mdFormat);
        return phone.toCEDevData();
    }
}
