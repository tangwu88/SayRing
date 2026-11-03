package cc.saidian.saydian_app;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.entity.k6.K6_Action;
import ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_RRI_HRV;
import ce.com.cenewbluesdk.entity.k6.k6_RRI_HRV_DATA;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.BaseK6AnalysiDevData;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.K6AnalysiDevRcvDataManager;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.ProcessDATA_TYPE_RRI_HRV;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.ProcessDATA_TYPE_RRI_HRV_HISTORY;

/** 原 AAR 的解析器/回调路由回归；仅使用合成数据，不连接设备。 */
public final class CoolWearHrvSdkTest {
    private static final Field CALLBACK;
    static {
        try {
            CALLBACK = BaseK6AnalysiDevData.class.getDeclaredField("mMK6BleDataResult");
            CALLBACK.setAccessible(true);
        } catch (ReflectiveOperationException error) { throw new ExceptionInInitializerError(error); }
    }

    public static void main(String[] args) throws Exception {
        CEDevData open = new K6_DATA_TYPE_REAL_RRI_HRV(1).toCEDevData();
        CEDevData stop = new K6_DATA_TYPE_REAL_RRI_HRV(0).toCEDevData();
        require(open.getCmd() == 1 && open.getDataType() == 62
                && Arrays.equals(open.getData(), new byte[]{1}), "start is not command 62/1");
        require(stop.getCmd() == 1 && stop.getDataType() == 62
                && Arrays.equals(stop.getData(), new byte[]{0}), "stop is not command 62/0");
        ProcessDATA_TYPE_RRI_HRV live = new ProcessDATA_TYPE_RRI_HRV(null);
        ProcessDATA_TYPE_RRI_HRV_HISTORY history = new ProcessDATA_TYPE_RRI_HRV_HISTORY(null);
        OtherProcessor other = new OtherProcessor();
        K6AnalysiDevRcvDataManager manager = registry(List.of(live, history, other));
        int[] counts = new int[2];
        K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>> passive = values -> { counts[0]++; return true; };
        K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>> current = values -> { counts[1]++; return true; };
        K6BleDataResult<Object> unchanged = value -> true;
        other.setMK6BleDataResult(unchanged);

        // 首先证明修复前公共 key 的真实行为：60/61 都绑定同一个测量 listener。
        manager.addBleDataResultListener(K6_Action.RCVD.RCVD_DATA_TYPE_RRI_HRV, current);
        require(CALLBACK.get(live) == current && CALLBACK.get(history) == current,
                "SDK alias changed; re-audit the protocol before adapting this test");
        require(CoolWearHrvListenerRouter.install(manager, passive, current), "live split unavailable");
        require(CALLBACK.get(live) == current && CALLBACK.get(history) == passive,
                "production router mixes real-time and history");
        require(CALLBACK.get(other) == unchanged, "unrelated listener was replaced");

        byte[] payload = syntheticPayload();
        List<k6_RRI_HRV_DATA> samples = live.realProcess(payload);
        k6_RRI_HRV_DATA sample = samples.get(0);
        require(sample.getSdnn() == 42 && sample.getRmssd() == 51 && sample.getRri() == 800
                && sample.getQuality() == 2 && sample.getValid_count() == 80,
                "actual 16-byte RRI fields no longer match the documented schema");
        dispatch(history, history.realProcess(payload));
        require(counts[0] == 1 && counts[1] == 0, "history completed a live measurement");
        dispatch(live, samples);
        require(counts[0] == 1 && counts[1] == 1, "real-time packet did not reach live listener");

        // 原厂升级改变列表顺序时不能把第一个历史解析器当作实时解析器。
        require(!CoolWearHrvListenerRouter.install(registry(List.of(history, live, other)), passive, current),
                "history-first registry bypassed exact-type guard");
        require(CALLBACK.get(live) == passive && CALLBACK.get(history) == passive,
                "failed guard must preserve only passive RRI history");
        require(CALLBACK.get(other) == unchanged, "failed guard changed another listener");
        require(!CoolWearHrvListenerRouter.install(registry(List.of(other)), passive, current),
                "missing live processor accepted");
        require(CALLBACK.get(other) == unchanged, "missing-processor guard changed another listener");
        System.out.println("Actual bundled AAR PASS: 62 start/stop, real 16-byte fields, reproduced old 60/61 alias, production routing split, reversed/missing parser fail closed, unrelated listener preserved.");
    }

    private static byte[] syntheticPayload() {
        byte[] payload = new byte[19];
        payload[2] = 1;
        payload[7] = 0x20; payload[8] = 3;
        payload[9] = 42; payload[11] = 51;
        payload[13] = 10; payload[14] = 75;
        payload[15] = 80; payload[16] = 1;
        payload[17] = 2; payload[18] = (byte) 128;
        return payload;
    }

    @SuppressWarnings("unchecked") // 测试仅读回刚由生产 router 绑定的相同元素类型。
    private static void dispatch(BaseK6AnalysiDevData<?> parser, List<k6_RRI_HRV_DATA> values)
            throws IllegalAccessException {
        // SDK preProcessResult 后面还会发送 Android Handler 消息；这里仅调用
        // 原解析器上真正安装的回调，不构建手机运行时/蓝牙代理。
        K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>> callback =
                (K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>>) CALLBACK.get(parser);
        callback.bleDataResult(new ArrayList<>(values));
    }

    private static K6AnalysiDevRcvDataManager registry(List<?> processors) throws Exception {
        // 仅测试夹具：全 SDK 构造还依赖 Android/Fastjson；隔离 registry 避免
        // 初始化蓝牙、下载依赖。实际公开注册/查找方法和解析器仍来自原始 AAR。
        Class<?> unsafeType = Class.forName("sun.misc.Unsafe");
        Field field = unsafeType.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Object unsafe = field.get(null);
        K6AnalysiDevRcvDataManager manager = (K6AnalysiDevRcvDataManager)
                unsafeType.getMethod("allocateInstance", Class.class)
                        .invoke(unsafe, K6AnalysiDevRcvDataManager.class);
        Field all = K6AnalysiDevRcvDataManager.class.getDeclaredField("allProcess");
        all.setAccessible(true);
        all.set(manager, processors);
        return manager;
    }

    private static final class OtherProcessor extends BaseK6AnalysiDevData<Object> {
        OtherProcessor() { super(null); setDataTypeStr("synthetic_unrelated"); addDataType(99); }
        @Override protected Object realProcess(byte[] value) { return value; }
        @Override protected boolean processResult(Object value) { return false; }
        @Override protected boolean sendMsg(Object value) { return false; }
    }

    private static void require(boolean passed, String message) {
        if (!passed) throw new AssertionError(message);
    }
}
