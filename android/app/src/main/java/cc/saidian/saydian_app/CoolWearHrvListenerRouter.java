package cc.saidian.saydian_app;

import java.util.ArrayList;

import ce.com.cenewbluesdk.entity.k6.K6_Action;
import ce.com.cenewbluesdk.entity.k6.k6_RRI_HRV_DATA;
import ce.com.cenewbluesdk.proxy.interfaces.IK6AnalysiDevRcvDataManager;
import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.AnalysisReceiveDataHelper.BlueProcessBean.BaseK6AnalysiDevData;

/** 将 SDK 共用回调名称的实时 RRI(60) 与历史 RRI(61) 分开。 */
final class CoolWearHrvListenerRouter {
    private CoolWearHrvListenerRouter() { }

    @SuppressWarnings({"rawtypes", "unchecked"}) // SDK 公开查找接口返回原始泛型。
    static boolean install(
            IK6AnalysiDevRcvDataManager manager,
            K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>> history,
            K6BleDataResult<ArrayList<k6_RRI_HRV_DATA>> live) {
        // 当前原厂 SDK 用同一字符串注册 60、61，先全部设为被动历史。
        // 不能直接把这个公共 key 绑定成手动测量，否则历史会冒充本轮新测量。
        manager.addBleDataResultListener(K6_Action.RCVD.RCVD_DATA_TYPE_RRI_HRV, history);
        BaseK6AnalysiDevData processor = manager.getResultListenerByDataTypeStr(
                K6_Action.RCVD.RCVD_DATA_TYPE_RRI_HRV);
        // 只使用 SDK 公开接口，并校验实际类型；SDK 顺序/实现变化时保留历史，
        // 不动其它 listener，也不允许未证实的实时源完成测量。
        if (processor == null || !processor.isMy(60) || processor.isMy(61)) return false;
        processor.setMK6BleDataResult(live);
        return true;
    }
}
