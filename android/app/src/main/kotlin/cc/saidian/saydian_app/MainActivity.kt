package cc.saidian.saydian_app

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.location.LocationManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.inuker.bluetooth.library.Code
import com.inuker.bluetooth.library.Constants
import com.inuker.bluetooth.library.connect.response.BleNotifyResponse
import com.inuker.bluetooth.library.connect.response.BleWriteResponse
import com.inuker.bluetooth.library.jieli.RcspAuthManager
import com.inuker.bluetooth.library.jieli.dial.JLWatchFaceManager
import com.inuker.bluetooth.library.jieli.dial.JLWatchHolder
import com.inuker.bluetooth.library.jieli.dial.WatchManager
import com.inuker.bluetooth.library.jieli.dial.WatchInfo
import com.inuker.bluetooth.library.jieli.response.RcspAuthResponse
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.jieli.jl_fatfs.model.FatFile
import com.jieli.jl_rcsp.interfaces.watch.OnWatchOpCallback
import com.jieli.jl_rcsp.model.base.BaseError
import com.alipay.sdk.app.PayTask
import com.tencent.mm.opensdk.constants.Build as WechatBuild
import com.tencent.mm.opensdk.modelpay.PayReq
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.customui.WatchUIType
import com.veepoo.protocol.listener.IHealthRemindListener
import com.veepoo.protocol.listener.IMiniCheckupOptListener
import com.veepoo.protocol.listener.base.IABleConnectStatusListener
import com.veepoo.protocol.listener.base.IBleNotifyResponse
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.IAutoMeasureSettingDataListener
import com.veepoo.protocol.listener.data.IAlarm2DataListListener
import com.veepoo.protocol.listener.data.IBatteryDataListener
import com.veepoo.protocol.listener.data.IBPDetectDataListener
import com.veepoo.protocol.listener.data.IBPSettingDataListener
import com.veepoo.protocol.listener.data.IBloodComponentDetectListener
import com.veepoo.protocol.listener.data.IBloodGlucoseChangeListener
import com.veepoo.protocol.listener.data.IBodyComponentDetectListener
import com.veepoo.protocol.listener.data.ICameraDataListener
import com.veepoo.protocol.listener.data.IContactOptListener
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceBTInfoListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IFindDevicelistener
import com.veepoo.protocol.listener.data.IFunSwitchListener
import com.veepoo.protocol.listener.data.IHeartDataListener
import com.veepoo.protocol.listener.data.IHrvDetectListener
import com.veepoo.protocol.listener.data.IECGDetectListener
import com.veepoo.protocol.listener.data.IHealthAlarmIntervalListener
import com.veepoo.protocol.listener.data.ILongSeatDataListener
import com.veepoo.protocol.listener.data.IMtuChangeListener
import com.veepoo.protocol.listener.data.INightTurnWristeDataListener
import com.veepoo.protocol.listener.data.IOriginData3Listener
import com.veepoo.protocol.listener.data.IOriginDataListener
import com.veepoo.protocol.listener.data.IPersonInfoDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISleepDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.listener.data.IScreenLightListener
import com.veepoo.protocol.listener.data.IScreenLightTimeListener
import com.veepoo.protocol.listener.data.ISpo2hDataListener
import com.veepoo.protocol.listener.data.ISportModelOriginListener
import com.veepoo.protocol.listener.data.ISportModelStateListener
import com.veepoo.protocol.listener.data.ISportControlOptListener
import com.veepoo.protocol.listener.data.ITemptureDetectDataListener
import com.veepoo.protocol.listener.data.ITextAlarmDataListener
import com.veepoo.protocol.listener.data.IWeatherStatusDataListener
import com.veepoo.protocol.listener.data.IWorldClockOptListener
import com.veepoo.protocol.listener.data.IUIBaseInfoListener
import com.veepoo.protocol.model.datas.BTInfo
import com.veepoo.protocol.model.datas.BatteryData
import com.veepoo.protocol.model.datas.BpData
import com.veepoo.protocol.model.datas.BpSettingData
import com.veepoo.protocol.model.datas.BloodComponent
import com.veepoo.protocol.model.datas.BodyComponent
import com.veepoo.protocol.model.datas.AutoMeasureData
import com.veepoo.protocol.model.datas.Contact
import com.veepoo.protocol.model.datas.EcgDetectInfo
import com.veepoo.protocol.model.datas.EcgDetectResult
import com.veepoo.protocol.model.datas.EcgDetectState
import com.veepoo.protocol.model.datas.EcgDiagnosis
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.FunSwitchFlags
import com.veepoo.protocol.model.datas.HRVOriginData
import com.veepoo.protocol.util.EcgUtil
import com.veepoo.protocol.model.datas.HeartData
import com.veepoo.protocol.model.datas.HealthAlarmInterval
import com.veepoo.protocol.model.datas.HealthRemind
import com.veepoo.protocol.model.datas.MiniCheckupDetailData
import com.veepoo.protocol.model.datas.MiniCheckupResultData
import com.veepoo.protocol.model.datas.OriginData
import com.veepoo.protocol.model.datas.OriginData3
import com.veepoo.protocol.model.datas.OriginHalfHourData
import com.veepoo.protocol.model.datas.PersonInfoData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.Spo2hOriginData
import com.veepoo.protocol.model.datas.Spo2hData
import com.veepoo.protocol.model.datas.SportModelGPSWatchOriginHeadData
import com.veepoo.protocol.model.datas.SportModelOriginHeadData
import com.veepoo.protocol.model.datas.SportModelOriginItemData
import com.veepoo.protocol.model.datas.SportModelStateData
import com.veepoo.protocol.model.datas.SportControlDataInfo
import com.veepoo.protocol.model.datas.TemptureDetectData
import com.veepoo.protocol.model.datas.TextAlarmData
import com.veepoo.protocol.model.datas.TimeData
import com.veepoo.protocol.model.datas.UIDataCustom
import com.veepoo.protocol.model.datas.WorldClock
import com.veepoo.protocol.model.datas.UICustomSetData
import com.veepoo.protocol.model.datas.weather.WeatherData
import com.veepoo.protocol.model.datas.weather.WeatherEvery3Hour
import com.veepoo.protocol.model.datas.weather.WeatherEveryDay
import com.veepoo.protocol.model.enums.EBPDetectModel
import com.veepoo.protocol.model.enums.EBPDetectStatus
import com.veepoo.protocol.model.enums.EBPStatus
import com.veepoo.protocol.model.enums.EBloodComponentDetectState
import com.veepoo.protocol.model.enums.EBloodGlucoseRiskLevel
import com.veepoo.protocol.model.enums.EBloodGlucoseStatus
import com.veepoo.protocol.model.enums.DetectState
import com.veepoo.protocol.model.enums.EAutoMeasureType
import com.veepoo.protocol.model.enums.ECameraStatus
import com.veepoo.protocol.model.enums.EContactOpt
import com.veepoo.protocol.model.enums.ECustomStatus
import com.veepoo.protocol.model.enums.EDeviceStatus
import com.veepoo.protocol.model.enums.EFunctionStatus
import com.veepoo.protocol.model.enums.EHealthAlarmType
import com.veepoo.protocol.model.enums.EHeartStatus
import com.veepoo.protocol.model.enums.EUIFromType
import com.veepoo.protocol.model.enums.EWatchUIType
import com.veepoo.protocol.model.enums.EMiniCheckupTestErrorCode
import com.veepoo.protocol.model.enums.EMultiAlarmOprate
import com.veepoo.protocol.model.enums.EOprateStauts
import com.veepoo.protocol.model.enums.EPwdStatus
import com.veepoo.protocol.model.enums.ESex
import com.veepoo.protocol.model.enums.ESPO2HStatus
import com.veepoo.protocol.model.enums.ESportType
import com.veepoo.protocol.model.enums.ESportControlType
import com.veepoo.protocol.model.enums.EWeatherOprateStatus
import com.veepoo.protocol.model.enums.EWeatherType
import com.veepoo.protocol.model.enums.EWatchUIElementPosition
import com.veepoo.protocol.model.enums.HealthRemindType
import com.veepoo.protocol.model.enums.HrvDetectState
import com.veepoo.protocol.model.settings.Alarm2Setting
import com.veepoo.protocol.model.settings.BpSetting
import com.veepoo.protocol.model.settings.CustomSetting
import com.veepoo.protocol.model.settings.CustomSettingData
import com.veepoo.protocol.model.settings.LongSeatSetting
import com.veepoo.protocol.model.settings.NightTurnWristSetting
import com.veepoo.protocol.model.settings.ScreenSetting
import com.veepoo.protocol.model.settings.TextAlarm2Setting
import com.veepoo.protocol.model.settings.WeatherStatusSetting
import com.veepoo.protocol.shareprence.SpUtil
import com.veepoo.protocol.shareprence.SputilVari
import com.veepoo.protocol.shareprence.VpSpGetUtil
import com.veepoo.protocol.util.TextAlarmSp
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.io.File
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var adapter: VeepooWearableAdapter
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionCall: Pair<MethodCall, MethodChannel.Result>? = null
    private var pendingBluetoothCall: Pair<MethodCall, MethodChannel.Result>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!::adapter.isInitialized) adapter = VeepooWearableAdapter(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // FlutterActivity may configure the engine from super.onCreate before
        // this Activity's onCreate body resumes.
        if (!::adapter.isInitialized) adapter = VeepooWearableAdapter(applicationContext)
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHODS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            prepareCall(call, result)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PAYMENTS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            handlePaymentMethod(call, result)
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENTS_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    adapter.setEventListener { payload ->
                        mainHandler.post { eventSink?.success(payload) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    adapter.setEventListener(null)
                }
            },
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != BLE_PERMISSION_REQUEST) return
        val pending = pendingPermissionCall ?: return
        pendingPermissionCall = null
        if (hasBlePermissions()) {
            prepareCall(pending.first, pending.second)
        } else {
            pending.second.error("BLE_PERMISSION_DENIED", "允许相关权限后使用", null)
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BLE_ENABLE_REQUEST) return
        val pending = pendingBluetoothCall ?: return
        pendingBluetoothCall = null
        if (resultCode == Activity.RESULT_OK && isBluetoothEnabled()) {
            prepareCall(pending.first, pending.second)
        } else {
            pending.second.error("BLUETOOTH_DISABLED", "请开启手机蓝牙后再扫描设备", null)
        }
    }

    private fun prepareCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in BLE_PERMISSION_METHODS) {
            dispatch(call, result)
            return
        }
        if (!hasBlePermissions()) {
            pendingPermissionCall = call to result
            ActivityCompat.requestPermissions(this, requiredBlePermissions(), BLE_PERMISSION_REQUEST)
            return
        }
        if (!isBluetoothEnabled()) {
            if (pendingBluetoothCall != null) {
                result.error("BLUETOOTH_ENABLE_IN_PROGRESS", "正在等待开启蓝牙", null)
                return
            }
            pendingBluetoothCall = call to result
            try {
                startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), BLE_ENABLE_REQUEST)
            } catch (error: Throwable) {
                pendingBluetoothCall = null
                Log.w("SaidianMain", "Unable to open Bluetooth settings", error)
                result.error("BLUETOOTH_ENABLE_FAILED", "无法打开系统蓝牙开关，请手动开启", null)
            }
            return
        }
        if (call.method == "scanDevices" &&
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.R &&
            !isLocationServiceEnabled()
        ) {
            result.error("LOCATION_SERVICE_DISABLED", "请开启手机定位后再查找手表", null)
            return
        }
        dispatch(call, result)
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        // The official Veepoo demo calls VPOperateManager from the Activity
        // thread. Dart serializes watch operations, so keep that thread affinity.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            handleMethod(call, result)
        } else {
            mainHandler.post { handleMethod(call, result) }
        }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        val callback = FlutterResultCallback<Any?>(result, mainHandler)
        if (call.method == "saveReportImage") {
            adapter.saveReportImage(
                call.argument<ByteArray>("bytes"),
                call.argument<String>("fileName"),
                callback,
            )
            return
        }
        if (call.method == "saveGalleryImage") {
            adapter.saveGalleryImage(
                call.argument<ByteArray>("bytes"),
                call.argument<String>("fileName"),
                call.argument<String>("mimeType"),
                callback,
            )
            return
        }
        val feature = call.argument<String>("feature").orEmpty()
        adapter.prepareForOperation(call.method, feature) {
            try {
                when (call.method) {
                    "scanDevices" -> adapter.scanDevices(callback)
                    "stopScan" -> adapter.stopScan(callback.unit())
                    "connect" ->
                        adapter.connect(
                            call.argument<String>("deviceId").orEmpty(),
                            WearableProfile.from(call.argument<Map<*, *>>("profile")),
                            callback.unit(),
                        )
                    "restoreConnection" ->
                        adapter.restoreConnection(
                            WearableProfile.from(call.argument<Map<*, *>>("profile")),
                            callback,
                        )
                    "disconnect" -> adapter.disconnect(callback.unit())
                    "getDeviceDetails" -> callback.success(adapter.getDeviceDetails())
                    "getWatchFaceProfile" -> adapter.getWatchFaceProfile(callback)
                    "getCapabilities" -> callback.success(adapter.getCapabilities())
                    "syncHealthData" -> adapter.syncHealthData(call.argument<String>("cursor"), callback)
                    "startMeasurement" ->
                        adapter.startMeasurement(call.argument<String>("metric").orEmpty(), callback.unit())
                    "stopMeasurement" ->
                        adapter.stopMeasurement(call.argument<String>("metric").orEmpty(), callback.unit())
                    "startSport" ->
                        adapter.startSport(call.argument<String>("mode").orEmpty(), callback.unit())
                    "stopSport" -> adapter.stopSport(callback.unit())
                    "readSportRecords" -> adapter.readSportRecords(callback)
                    "readAutoMeasureSettings" -> adapter.readAutoMeasureSettings(callback)
                    "readAutoMeasureIntervals" -> adapter.readAutoMeasureIntervals(callback)
                    "setAutoMeasureSetting" ->
                        adapter.setAutoMeasureSetting(
                            call.argument<String>("type").orEmpty(),
                            call.argument<Boolean>("enabled") == true,
                            callback.unit(),
                        )
                    "setAutoMeasureInterval" ->
                        adapter.setAutoMeasureInterval(
                            call.argument<String>("type").orEmpty(),
                            call.argument<Int>("minutes") ?: 0,
                            callback.unit(),
                        )
                    "readHeartRateWarning" -> adapter.readHeartRateWarning(callback)
                    "setHeartRateWarning" ->
                        adapter.setHeartRateWarning(
                            call.argument<Int>("value") ?: 120,
                            callback.unit(),
                        )
                    "readDeviceFeature" -> adapter.readDeviceFeature(feature, callback)
                    "writeDeviceFeature" ->
                        adapter.writeDeviceFeature(
                            feature,
                            call.argument<Map<*, *>>("values"),
                            callback.unit(),
                        )
                    "triggerDeviceAction" ->
                        adapter.triggerDeviceAction(
                            feature,
                            call.argument<Boolean>("enabled") != false,
                            callback.unit(),
                        )
                    else -> callback.notImplemented()
                }
            } catch (error: Throwable) {
                Log.e(
                    "SaidianMain",
                    "Wearable method failed method=${call.method} feature=$feature",
                    error,
                )
                callback.error("WEARABLE_ERROR", error.message ?: "设备通信失败")
            }
        }
    }

    private fun hasBlePermissions(): Boolean =
        requiredBlePermissions().all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }

    private fun requiredBlePermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun isBluetoothEnabled(): Boolean {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return bluetoothManager?.adapter?.isEnabled == true
    }

    private fun isLocationServiceEnabled(): Boolean {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            locationManager.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    private fun handlePaymentMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startWechatPay" -> startWechatPay(call.arguments, result)
            "takeWechatPayResult" -> result.success(AppPaymentStore.takeWechatResult(this))
            "startAlipay" -> startAlipay(call.argument<String>("orderInfo").orEmpty(), result)
            else -> result.notImplemented()
        }
    }

    private fun startWechatPay(arguments: Any?, result: MethodChannel.Result) {
        val values = (arguments as? Map<*, *>).orEmpty()
        fun value(vararg keys: String): String {
            for (key in keys) {
                val current = values[key]
                if (current != null && "$current".trim().isNotEmpty()) return "$current".trim()
            }
            return ""
        }
        val appId = value("appId", "appid")
        val partnerId = value("partnerId", "partnerid", "partner_id", "mch_id")
        val prepayId = value("prepayId", "prepayid", "prepay_id")
        val packageValue = value("packageValue", "package", "package_value").ifEmpty { "Sign=WXPay" }
        val nonceStr = value("nonceStr", "noncestr", "nonce_str")
        val timeStamp = value("timeStamp", "timestamp", "time_stamp")
        val sign = value("sign", "paySign", "pay_sign")
        if (listOf(appId, partnerId, prepayId, nonceStr, timeStamp, sign).any { it.isEmpty() }) {
            result.error("WECHAT_PAY_CONFIG_INVALID", "后台返回的微信 APP 支付参数不完整", null)
            return
        }
        val api = WXAPIFactory.createWXAPI(this, appId, true)
        if (!api.registerApp(appId)) {
            result.error("WECHAT_REGISTER_FAILED", "微信支付应用注册失败", null)
            return
        }
        if (!api.isWXAppInstalled) {
            result.error("WECHAT_NOT_INSTALLED", "请先安装微信后再支付", null)
            return
        }
        if (api.wxAppSupportAPI < WechatBuild.PAY_SUPPORTED_SDK_INT) {
            result.error("WECHAT_VERSION_UNSUPPORTED", "当前微信版本不支持 APP 支付，请升级微信", null)
            return
        }
        AppPaymentStore.saveWechatAppId(this, appId)
        AppPaymentStore.clearWechatResult(this)
        val request =
            PayReq().apply {
                this.appId = appId
                this.partnerId = partnerId
                this.prepayId = prepayId
                this.packageValue = packageValue
                this.nonceStr = nonceStr
                this.timeStamp = timeStamp
                this.sign = sign
            }
        if (api.sendReq(request)) result.success(true)
        else result.error("WECHAT_PAY_SEND_FAILED", "无法调起微信支付，请稍后重试", null)
    }

    private fun startAlipay(orderInfo: String, result: MethodChannel.Result) {
        if (orderInfo.isBlank()) {
            result.error("ALIPAY_CONFIG_INVALID", "后台未返回支付宝签名订单", null)
            return
        }
        Thread {
            try {
                val payResult = PayTask(this).payV2(orderInfo, true)
                mainHandler.post { result.success(payResult) }
            } catch (error: Throwable) {
                Log.e("SaidianPayment", "Alipay invocation failed", error)
                mainHandler.post {
                    result.error("ALIPAY_FAILED", error.message ?: "支付宝支付调起失败", null)
                }
            }
        }.start()
    }

    override fun onDestroy() {
        if (::adapter.isInitialized) adapter.close(preserveConnection = true)
        super.onDestroy()
    }

    companion object {
        private const val METHODS_CHANNEL = "cc.saidian/wearable_methods"
        private const val EVENTS_CHANNEL = "cc.saidian/wearable_events"
        private const val PAYMENTS_CHANNEL = "cc.saidian/app_payments"
        private const val BLE_PERMISSION_REQUEST = 7001
        private const val BLE_ENABLE_REQUEST = 7002
        private val BLE_PERMISSION_METHODS =
            setOf(
                "scanDevices",
                "connect",
                "restoreConnection",
                "getDeviceDetails",
                "getWatchFaceProfile",
                "startSport",
                "stopSport",
                "readSportRecords",
                "readAutoMeasureSettings",
                "readAutoMeasureIntervals",
                "setAutoMeasureSetting",
                "setAutoMeasureInterval",
                "readHeartRateWarning",
                "setHeartRateWarning",
                "readDeviceFeature",
                "writeDeviceFeature",
                "triggerDeviceAction",
            )
    }
}

private interface ResultCallback<in T> {
    fun success(value: T)
    fun error(code: String, message: String)
}

private class FlutterResultCallback<T>(
    private val result: MethodChannel.Result,
    private val handler: Handler,
) : ResultCallback<T> {
    private val completed = AtomicBoolean(false)

    override fun success(value: T) = finish { result.success(value) }

    override fun error(code: String, message: String) = finish { result.error(code, message, null) }

    fun notImplemented() = finish { result.notImplemented() }

    fun unit(): ResultCallback<Unit> =
        object : ResultCallback<Unit> {
            override fun success(value: Unit) = finish { result.success(null) }
            override fun error(code: String, message: String) = this@FlutterResultCallback.error(code, message)
        }

    private fun finish(block: () -> Unit) {
        if (completed.compareAndSet(false, true)) handler.post(block)
    }
}

private data class WearableProfile(
    val gender: Int,
    val heightCm: Int,
    val weightKg: Int,
    val age: Int,
    val targetSteps: Int,
) {
    companion object {
        fun from(value: Map<*, *>?): WearableProfile =
            WearableProfile(
                gender = (value?.get("gender") as? Number)?.toInt()?.coerceIn(1, 2) ?: 1,
                heightCm = (value?.get("heightCm") as? Number)?.toInt()?.coerceIn(80, 240) ?: 175,
                weightKg = (value?.get("weightKg") as? Number)?.toInt()?.coerceIn(20, 250) ?: 70,
                age = (value?.get("age") as? Number)?.toInt()?.coerceIn(5, 120) ?: 30,
                targetSteps =
                    (value?.get("targetSteps") as? Number)?.toInt()?.coerceIn(1000, 100000)
                        ?: 8000,
            )
    }
}

private class VeepooWearableAdapter(context: android.content.Context) {
    private val appContext = context.applicationContext
    private val manager: VPOperateManager
    private val connectionHandler = Handler(Looper.getMainLooper())
    private val devices = linkedMapOf<String, SearchResult>()
    @Volatile private var activeScanCallback: ResultCallback<List<Map<String, Any?>>>? = null
    @Volatile private var scanGeneration = 0
    @Volatile private var connectionGeneration = 0
    @Volatile private var activeConnectionCallback: ResultCallback<Unit>? = null
    @Volatile private var activeTransportConnected = false
    private var connectionTimeoutTask: Runnable? = null
    private var personSyncTimeoutTask: Runnable? = null
    @Volatile private var healthSyncGeneration = 0
    @Volatile private var activeHealthSyncCallback: ResultCallback<List<Map<String, Any?>>>? = null
    @Volatile private var activeHealthSyncRecords: MutableList<Map<String, Any?>>? = null
    @Volatile private var jlWatchFaceSessionActive = false
    private val availableWatchFacePaths = linkedSetOf<String>()
    private var activeHealthSyncDeviceId = ""
    private var activeHealthSyncProgress = 0.0
    private var healthSyncTimeoutTask: Runnable? = null
    private var connectStatusListener: IABleConnectStatusListener? = null
    private var connectStatusAddress = ""
    private var connectingDeviceId = ""
    private var eventListener: ((Map<String, Any?>) -> Unit)? = null
    private var connectedDeviceId = ""
    private var connectedDeviceName = ""
    private var firmwareVersion = ""
    private var batteryPercent: Int? = null
    private var batteryReadInFlight = false
    private var watchFaceDeviceNumber = 0
    private var watchFaceDeviceTestVersion = ""
    private var watchFaceDialShape = 0
    private var watchFaceScreenWidth = 0
    private var watchFaceScreenHeight = 0
    private var watchDataDays = 3
    private var capabilities = defaultCapabilities()
    private var legacyFunctionData: FunctionDeviceSupportData? = null
    private var functionPackage1: DeviceFunctionPackage1? = null
    private var functionPackage2: DeviceFunctionPackage2? = null
    private var functionPackage3: DeviceFunctionPackage3? = null
    private var functionPackage4: DeviceFunctionPackage4? = null
    private var functionPackage5: DeviceFunctionPackage5? = null
    private var socialFunctionData: FunctionSocailMsgData? = null
    private var lastCustomSettingData: CustomSettingData? = null
    private var capabilityUpdateTask: Runnable? = null
    private var activeMetric: String? = null
    private var activeControlledSportType: ESportType? = null
    private var activeSportUsesAppControl = false
    private var measurementResultTimeoutTask: Runnable? = null
    private var ecgSampleFrequency = DEFAULT_ECG_SAMPLE_FREQUENCY
    private var activeEcgType = 0
    private var latestEcgHeartRate = 0
    private var latestEcgHrv = 0
    private var lastEcgAdcLogAt = 0L
    private var lastEcgStateLogAt = 0L
    private var activeHrvUsesEcg = false
    private var activeHrvUsesMiniCheckup = false
    private var directHrvMeasurementSupported = false
    private var hrvMiniCheckupSupported = false
    private var bloodGlucoseMeasurementSupported = false
    private var temperatureRetryUsed = false
    private var bloodPressureStartGeneration = 0
    private var pendingBloodPressureStart: ResultCallback<Unit>? = null
    private var bloodPressureWearTimeoutTask: Runnable? = null
    private var bloodPressureModeTimeoutTask: Runnable? = null
    private var activeBloodPressureMode = EBPDetectModel.DETECT_MODEL_PUBLIC
    private var activeBloodPressureUsesMiniCheckup = false
    private var pendingGlucoseCalibration: ResultCallback<Unit>? = null
    private val autoMeasureSettings = mutableMapOf<String, AutoMeasureData>()
    private val connectionPreferences =
        appContext.getSharedPreferences(CONNECTION_PREFERENCES, Context.MODE_PRIVATE)
    private var lastScreenSetting: ScreenSetting? = null
    private var lastSocialMsgSetting: FunctionSocailMsgData? = null
    private val cachedContacts = mutableListOf<Contact>()
    private var currentSosContactId: Int? = null
    private val cachedHealthReminders = linkedMapOf<HealthRemindType, HealthRemind>()
    private val cachedWorldClocks = mutableListOf<WorldClock>()
    private var weatherCrc = 0
    private var lastWeatherCity = ""
    private var lastWeatherUpdatedAt = 0L
    private val cameraListener =
        object : ICameraDataListener {
            override fun OnCameraDataChange(status: ECameraStatus) {
                if (status == ECameraStatus.TAKEPHOTO_CAN) {
                    emit("cameraShutter", mapOf("deviceId" to connectedDeviceId))
                }
            }
        }

    init {
        // init() can replace the SDK singleton on first use. Re-read it after
        // initialization so scan, connect and protocol operations share state.
        VPOperateManager.getInstance().init(appContext)
        manager = VPOperateManager.getInstance()
        // Keep the watch's BLE data link and the phone Bluetooth/audio link in
        // sync. The vendor SDK only establishes the latter automatically when
        // this switch is enabled.
        manager.setAutoConnectBTBySdk(true)
        manager.setCameraListener(cameraListener)
        manager.listenDeviceCallbackData(
            object : IBleNotifyResponse() {
                override fun onNotify(service: UUID, characteristic: UUID, value: ByteArray) {
                    onRawDeviceCallback(value)
                }
            },
        )
    }

    fun setEventListener(listener: ((Map<String, Any?>) -> Unit)?) {
        eventListener = listener
    }

    fun prepareForOperation(_method: String, _feature: String, operation: () -> Unit) {
        // HBand requires JieLi authentication only once for the lifetime of the
        // app/device connection. Releasing it between ordinary device commands
        // leaves the BLE link alive but makes a later authentication time out.
        // Flutter already serializes commands, so retain the session until the
        // watch disconnects or this adapter closes.
        operation()
    }

    private fun releaseJLWatchFaceSession() {
        availableWatchFacePaths.clear()
        if (!jlWatchFaceSessionActive) return
        jlWatchFaceSessionActive = false
        runCatching { manager.releaseJLSDK() }
            .onFailure { Log.w(LOG_TAG, "JL watch-face session release failed", it) }
    }

    fun scanDevices(callback: ResultCallback<List<Map<String, Any?>>>) {
        // The Veepoo SDK caches its Bluetooth state and may briefly report
        // `false` after Android's adapter has already entered STATE_ON. The
        // system adapter is authoritative here; permissions were verified by
        // MainActivity before this method was dispatched.
        if (!isSystemBluetoothEnabled()) {
            callback.error("BLUETOOTH_DISABLED", "请开启手机蓝牙后再扫描设备")
            return
        }
        manager.stopScanDevice()
        finishScan()
        synchronized(devices) { devices.clear() }
        val generation =
            synchronized(this) {
                scanGeneration += 1
                activeScanCallback = callback
                scanGeneration
            }
        emit("state", mapOf("value" to "scanning"))
        manager.startScanDevice(
            12,
            object : SearchResponse {
                override fun onSearchStarted() = Unit

                override fun onDeviceFounded(device: SearchResult) {
                    if (generation != scanGeneration || activeScanCallback == null) return
                    val payload =
                        synchronized(devices) {
                            devices[device.address] = device
                            scanDevicePayload(device)
                        }
                    emit("scanDevice", payload)
                }

                override fun onSearchStopped() = finishScan(generation)

                override fun onSearchCanceled() = finishScan(generation)
            },
        )
    }

    fun stopScan(callback: ResultCallback<Unit>) {
        manager.stopScanDevice()
        finishScan()
        callback.success(Unit)
    }

    private fun finishScan(expectedGeneration: Int? = null) {
        val callback =
            synchronized(this) {
                if (expectedGeneration != null && expectedGeneration != scanGeneration) {
                    return@synchronized null
                }
                val current = activeScanCallback
                activeScanCallback = null
                current
            } ?: return
        val result =
            synchronized(devices) {
                devices.values
                    .sortedByDescending { it.rssi }
                    .map(::scanDevicePayload)
            }
        emit("state", mapOf("value" to "disconnected"))
        callback.success(result)
    }

    private fun scanDevicePayload(device: SearchResult): Map<String, Any?> =
        mapOf(
            "id" to device.address,
            "name" to (device.name?.takeIf { it.isNotBlank() } ?: "未命名设备"),
            "model" to (device.name?.takeIf { it.isNotBlank() } ?: "Veepoo"),
            "rssi" to device.rssi,
        )

    fun connect(
        deviceId: String,
        profile: WearableProfile,
        callback: ResultCallback<Unit>,
    ) {
        val device = synchronized(devices) { devices[deviceId] }
        if (device == null) {
            callback.error("DEVICE_NOT_FOUND", "设备已离开扫描范围，请重新扫描")
            return
        }
        manager.stopScanDevice()
        finishScan()
        val advertisedName = device.name.orEmpty()
        val sdkCurrentAddress = VPOperateManager.getCurrentDeviceAddress().orEmpty()
        val connectedAddress =
            when {
                sdkCurrentAddress.isNotBlank() &&
                    manager.isDeviceConnected(sdkCurrentAddress) ->
                    sdkCurrentAddress
                manager.isDeviceConnected(deviceId) -> deviceId
                else -> ""
            }
        if (connectedAddress.equals(deviceId, ignoreCase = true) &&
            connectedDeviceId.equals(deviceId, ignoreCase = true)
        ) {
            emit("state", mapOf("value" to "ready"))
            callback.success(Unit)
            return
        }

        val generation = beginConnectionAttempt(deviceId, callback)
        emit("state", mapOf("value" to "connecting"))
        if (connectedAddress.isNotBlank()) {
            // connectDevice silently returns for an already connected address.
            // Reset any stale/current SDK session and wait for its real state.
            releaseJLWatchFaceSession()
            unregisterConnectStatusListener()
            manager.disconnectWatch { code ->
                connectionHandler.post {
                    if (!isConnectionAttemptActive(generation, callback)) return@post
                    if (code == Code.REQUEST_SUCCESS) {
                        waitForSdkDisconnect(
                            generation,
                            connectedAddress,
                            deviceId,
                            advertisedName,
                            profile,
                            callback,
                        )
                    } else {
                        failConnection(
                            generation,
                            callback,
                            "RECONNECT_RESET_FAILED",
                            "已有连接未能断开，请关闭手表其他手机的连接后重试",
                        )
                    }
                }
            }
            return
        }
        startSdkConnection(generation, deviceId, advertisedName, profile, callback)
    }

    fun restoreConnection(
        profile: WearableProfile,
        callback: ResultCallback<Any?>,
    ) {
        val deviceId = connectionPreferences.getString(LAST_DEVICE_ID, "").orEmpty().trim()
        val deviceName = connectionPreferences.getString(LAST_DEVICE_NAME, "").orEmpty().trim()
        if (deviceId.isEmpty()) {
            callback.success(null)
            return
        }
        val completion =
            object : ResultCallback<Unit> {
                override fun success(value: Unit) {
                    callback.success(deviceDetailsPayload(deviceId, deviceName))
                }

                override fun error(code: String, message: String) {
                    callback.error(code, message)
                }
            }
        val generation = beginConnectionAttempt(deviceId, completion)
        emit("state", mapOf("value" to "connecting"))
        val currentAddress = VPOperateManager.getCurrentDeviceAddress().orEmpty()
        val connectedAddress =
            when {
                manager.isDeviceConnected(deviceId) -> deviceId
                currentAddress.isNotBlank() && manager.isDeviceConnected(currentAddress) -> currentAddress
                else -> ""
            }
        if (connectedAddress.equals(deviceId, ignoreCase = true)) {
            activeTransportConnected = true
            manager.setDeviceShowConfirm(true)
            registerConnectStatusListener(deviceId, generation)
            authenticate(generation, deviceId, deviceName, profile, completion)
        } else {
            startSdkConnection(generation, deviceId, deviceName, profile, completion)
        }
    }

    private fun beginConnectionAttempt(
        deviceId: String,
        callback: ResultCallback<Unit>,
    ): Int {
        cancelActiveHealthSync(
            "HEALTH_SYNC_CANCELLED",
            "连接设备已切换，历史数据同步已取消",
            emitError = false,
        )
        cancelActiveConnectionAttempt(
            "CONNECT_SUPERSEDED",
            "已有连接任务被新的连接操作替代",
            emitError = true,
        )
        firmwareVersion = ""
        watchFaceDialShape = 0
        watchFaceScreenWidth = 0
        watchFaceScreenHeight = 0
        watchDataDays = 3
        capabilities = defaultCapabilities()
        legacyFunctionData = null
        functionPackage1 = null
        functionPackage2 = null
        functionPackage3 = null
        functionPackage4 = null
        functionPackage5 = null
        socialFunctionData = null
        lastCustomSettingData = null
        capabilityUpdateTask?.let(connectionHandler::removeCallbacks)
        capabilityUpdateTask = null
        directHrvMeasurementSupported = false
        hrvMiniCheckupSupported = false
        bloodGlucoseMeasurementSupported = false
        val generation =
            synchronized(this) {
                connectionGeneration += 1
                activeConnectionCallback = callback
                activeTransportConnected = false
                connectionGeneration
            }
        val timeout =
            Runnable {
                failConnection(
                    generation,
                    callback,
                    "CONNECT_TIMEOUT",
                    "设备连接超时，请确认手表未连接其他手机后重试",
                )
            }
        connectionTimeoutTask = timeout
        connectionHandler.postDelayed(timeout, CONNECTION_FLOW_TIMEOUT_MS)
        connectingDeviceId = deviceId
        connectedDeviceId = ""
        return generation
    }

    private fun waitForSdkDisconnect(
        generation: Int,
        addressToWait: String,
        deviceId: String,
        advertisedName: String,
        profile: WearableProfile,
        callback: ResultCallback<Unit>,
        remainingChecks: Int = STALE_DISCONNECT_CHECKS,
    ) {
        if (!isConnectionAttemptActive(generation, callback)) return
        if (!manager.isDeviceConnected(addressToWait)) {
            startSdkConnection(generation, deviceId, advertisedName, profile, callback)
            return
        }
        if (remainingChecks <= 0) {
            failConnection(
                generation,
                callback,
                "RECONNECT_RESET_TIMEOUT",
                "已有蓝牙连接未能完全断开，请关闭手表蓝牙后重试",
            )
            return
        }
        connectionHandler.postDelayed(
            {
                waitForSdkDisconnect(
                    generation,
                    addressToWait,
                    deviceId,
                    advertisedName,
                    profile,
                    callback,
                    remainingChecks - 1,
                )
            },
            STALE_DISCONNECT_POLL_MS,
        )
    }

    private fun startSdkConnection(
        generation: Int,
        deviceId: String,
        advertisedName: String,
        profile: WearableProfile,
        callback: ResultCallback<Unit>,
    ) {
        if (!isConnectionAttemptActive(generation, callback)) return
        val displayName = advertisedName.ifBlank { "未命名设备" }
        manager.setDeviceShowConfirm(true)
        registerConnectStatusListener(deviceId, generation)
        val authenticationStarted = AtomicBoolean(false)
        val connectResponse =
            IConnectResponse { code, _, _ ->
                connectionHandler.post {
                    if (!isConnectionAttemptActive(generation, callback)) return@post
                    if (code == Code.REQUEST_SUCCESS) {
                        activeTransportConnected = true
                    } else {
                        failConnection(
                            generation,
                            callback,
                            "CONNECT_FAILED",
                            "设备连接失败，请保持手表靠近手机后重试",
                        )
                    }
                }
            }
        val notifyResponse =
            INotifyResponse { code ->
                connectionHandler.post {
                    if (!isConnectionAttemptActive(generation, callback)) return@post
                    if (code == Code.REQUEST_SUCCESS &&
                        authenticationStarted.compareAndSet(false, true)
                    ) {
                        activeTransportConnected = true
                        authenticate(generation, deviceId, displayName, profile, callback)
                    } else if (code != Code.REQUEST_SUCCESS) {
                        failConnection(
                            generation,
                            callback,
                            "NOTIFY_FAILED",
                            "设备连接失败，请保持手表靠近手机后重试",
                        )
                    }
                }
            }
        if (advertisedName.isBlank()) {
            manager.connectDevice(deviceId, connectResponse, notifyResponse)
        } else {
            manager.connectDevice(deviceId, advertisedName, connectResponse, notifyResponse)
        }
    }

    private fun authenticate(
        generation: Int,
        deviceId: String,
        deviceName: String,
        profile: WearableProfile,
        callback: ResultCallback<Unit>,
    ) {
        if (!isConnectionAttemptActive(generation, callback)) return
        emit("state", mapOf("value" to "authenticating"))
        val passwordStarted = AtomicBoolean(false)
        manager.confirmDevicePwd(
            IBleWriteResponse { code ->
                connectionHandler.post {
                    if (!isConnectionAttemptActive(generation, callback)) return@post
                    if (code != Code.REQUEST_SUCCESS) {
                        failConnection(
                            generation,
                            callback,
                            "PASSWORD_WRITE_FAILED",
                            "设备确认失败，请重新连接并在手表上确认",
                        )
                    }
                }
            },
            object : IPwdDataListener {
                override fun onPwdDataChange(data: PwdData) {
                    connectionHandler.post {
                        if (!isConnectionAttemptActive(generation, callback)) return@post
                        data.deviceVersion
                            ?.trim()
                            ?.takeIf(String::isNotEmpty)
                            ?.let { firmwareVersion = it }
                        watchFaceDeviceNumber = data.deviceNumber
                        watchFaceDeviceTestVersion = data.deviceTestVersion?.trim().orEmpty()
                        Log.i(
                            LOG_TAG,
                            "Password state=${data.getmStatus()} firmwarePresent=${firmwareVersion.isNotBlank()}",
                        )
                        if (data.getmStatus() in
                            setOf(EPwdStatus.CHECK_SUCCESS, EPwdStatus.CHECK_AND_TIME_SUCCESS) &&
                            passwordStarted.compareAndSet(false, true)
                        ) {
                            syncPersonInfo(
                                generation,
                                deviceId,
                                deviceName,
                                profile,
                                callback,
                            )
                        } else if (data.getmStatus() == EPwdStatus.CHECK_FAIL) {
                            failConnection(
                                generation,
                                callback,
                                "PASSWORD_FAILED",
                                "设备密码校验失败",
                            )
                        }
                    }
                }

                override fun onConnectionConfirmTimeout() {
                    connectionHandler.post {
                        if (!isConnectionAttemptActive(generation, callback)) return@post
                        // The SDK requires an explicit disconnect after this callback.
                        failConnection(
                            generation,
                            callback,
                            "CONFIRM_TIMEOUT",
                            "设备端连接确认超时，请在手表上确认连接",
                        )
                    }
                }
            },
            object : IDeviceFuctionDataListener {
                override fun onFunctionSupportDataChange(data: FunctionDeviceSupportData) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        watchDataDays = data.getWathcDay().coerceAtLeast(1)
                        legacyFunctionData = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }

                override fun onDeviceFunctionPackage1Report(data: DeviceFunctionPackage1) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        functionPackage1 = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }

                override fun onDeviceFunctionPackage2Report(data: DeviceFunctionPackage2) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        functionPackage2 = data
                        watchDataDays = data.watchDataDayNumber.coerceAtLeast(1)
                        scheduleCapabilitiesUpdate(generation)
                    }
                }

                override fun onDeviceFunctionPackage3Report(data: DeviceFunctionPackage3) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        functionPackage3 = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }

                override fun onDeviceFunctionPackage4Report(data: DeviceFunctionPackage4) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        functionPackage4 = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }

                override fun onDeviceFunctionPackage5Report(data: DeviceFunctionPackage5) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        functionPackage5 = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }
            },
            object : ISocialMsgDataListener {
                override fun onSocialMsgSupportDataChange(data: FunctionSocailMsgData) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        socialFunctionData = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }

                override fun onSocialMsgSupportDataChange2(data: FunctionSocailMsgData) {
                    onSocialMsgSupportDataChange(data)
                }
            },
            object : ICustomSettingDataListener {
                override fun OnSettingDataChange(data: CustomSettingData) {
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        lastCustomSettingData = data
                        scheduleCapabilitiesUpdate(generation)
                    }
                }
            },
            "0000",
            true,
        )
    }

    private fun syncPersonInfo(
        generation: Int,
        deviceId: String,
        deviceName: String,
        profile: WearableProfile,
        callback: ResultCallback<Unit>,
    ) {
        if (!isConnectionAttemptActive(generation, callback)) return
        emit("state", mapOf("value" to "syncing"))
        val sex = if (profile.gender == 2) ESex.WOMEN else ESex.MAN
        val person =
            PersonInfoData(
                sex,
                profile.heightCm,
                profile.weightKg,
                profile.age,
                profile.targetSteps,
            )
        val timeout =
            Runnable {
                completeConnection(generation, callback, deviceId, deviceName)
            }
        personSyncTimeoutTask?.let(connectionHandler::removeCallbacks)
        personSyncTimeoutTask = timeout
        connectionHandler.postDelayed(timeout, PERSON_SYNC_TIMEOUT_MS)
        manager.syncPersonInfo(
            IBleWriteResponse { code ->
                connectionHandler.post {
                    if (!isConnectionAttemptActive(generation, callback)) return@post
                    if (code != Code.REQUEST_SUCCESS) {
                        completeConnection(generation, callback, deviceId, deviceName)
                    }
                }
            },
            IPersonInfoDataListener {
                connectionHandler.post {
                    if (!isConnectionAttemptActive(generation, callback)) return@post
                    // Password verification establishes protocol readiness. Some
                    // older firmware rejects this profile write; keep the link ready.
                    completeConnection(generation, callback, deviceId, deviceName)
                }
            },
            person,
        )
    }

    private fun isConnectionAttemptActive(
        generation: Int,
        callback: ResultCallback<Unit>,
    ): Boolean =
        synchronized(this) {
            connectionGeneration == generation && activeConnectionCallback === callback
        }

    private fun activeConnectionFor(generation: Int): ResultCallback<Unit>? =
        synchronized(this) {
            activeConnectionCallback?.takeIf { connectionGeneration == generation }
        }

    private fun finishConnectionAttempt(
        generation: Int,
        callback: ResultCallback<Unit>,
    ): Boolean {
        val claimed =
            synchronized(this) {
                if (connectionGeneration != generation ||
                    activeConnectionCallback !== callback
                ) {
                    false
                } else {
                    activeConnectionCallback = null
                    activeTransportConnected = false
                    true
                }
            }
        if (claimed) cancelConnectionTimers()
        return claimed
    }

    private fun completeConnection(
        generation: Int,
        callback: ResultCallback<Unit>,
        deviceId: String,
        deviceName: String,
    ) {
        if (!finishConnectionAttempt(generation, callback)) return
        refreshFirmwareVersionFromSdkCache()
        connectingDeviceId = ""
        connectedDeviceId = deviceId
        connectedDeviceName = deviceName
        connectionPreferences.edit()
            .putString(LAST_DEVICE_ID, deviceId)
            .putString(LAST_DEVICE_NAME, deviceName)
            .apply()
        emit("deviceDetails", deviceDetailsPayload(deviceId, deviceName))
        emit("state", mapOf("value" to "ready"))
        callback.success(Unit)
        connectionHandler.postDelayed(
            {
                if (connectionGeneration == generation && capabilities["resolved"] == true) {
                    emit("capabilitiesUpdated", capabilities)
                }
            },
            250L,
        )
        connectionHandler.postDelayed({ refreshBatteryLevel() }, 1_200L)
    }

    private fun refreshFirmwareVersionFromSdkCache() {
        if (firmwareVersion.isNotBlank()) return
        val cached =
            runCatching {
                SpUtil.getString(
                    appContext,
                    SputilVari.INFO_DEVICE_VERSION_RELEASE,
                    "",
                ).orEmpty().trim()
            }.getOrDefault("")
        if (FIRMWARE_VERSION_PATTERN.matches(cached)) firmwareVersion = cached
    }

    private fun deviceDetailsPayload(
        deviceId: String = connectedDeviceId,
        deviceName: String = connectedDeviceName,
    ): Map<String, Any?> =
        buildMap {
            put("id", deviceId)
            put("name", deviceName.ifBlank { "Veepoo wearable" })
            put("model", deviceName.ifBlank { "Veepoo" })
            put("hardwareAddress", deviceId)
            firmwareVersion.takeIf { it.isNotBlank() }?.let { put("firmwareVersion", it) }
            batteryPercent?.let { put("batteryPercent", it) }
        }

    private fun refreshBatteryLevel() {
        val deviceId = connectedDeviceId.trim()
        if (deviceId.isEmpty() || batteryReadInFlight) return
        if (!runCatching { manager.isDeviceConnected(deviceId) }.getOrDefault(false)) return
        batteryReadInFlight = true
        manager.readBattery(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) batteryReadInFlight = false
            },
            object : IBatteryDataListener {
                override fun onDataChange(data: BatteryData) {
                    connectionHandler.post {
                        batteryReadInFlight = false
                        if (!connectedDeviceId.equals(deviceId, ignoreCase = true)) return@post
                        val reported = data.batteryPercent
                        if (reported in 0..100) {
                            batteryPercent = reported
                            emit("deviceDetails", deviceDetailsPayload(deviceId))
                        }
                    }
                }
            },
        )
    }

    private fun failConnection(
        generation: Int,
        callback: ResultCallback<Unit>,
        code: String,
        message: String,
    ) {
        if (!finishConnectionAttempt(generation, callback)) return
        connectingDeviceId = ""
        connectedDeviceId = ""
        clearMeasurementSessionState()
        releaseJLWatchFaceSession()
        unregisterConnectStatusListener()
        runCatching { manager.disconnectWatch { } }
        fail(callback, code, message)
    }

    private fun cancelActiveConnectionAttempt(
        code: String,
        message: String,
        emitError: Boolean,
    ) {
        val callback =
            synchronized(this) {
                val current = activeConnectionCallback
                activeConnectionCallback = null
                activeTransportConnected = false
                connectionGeneration += 1
                current
            }
        cancelConnectionTimers()
        if (callback != null) {
            if (emitError) emit("error", mapOf("code" to code, "message" to message))
            callback.error(code, message)
        }
    }

    private fun cancelConnectionTimers() {
        connectionTimeoutTask?.let(connectionHandler::removeCallbacks)
        connectionTimeoutTask = null
        personSyncTimeoutTask?.let(connectionHandler::removeCallbacks)
        personSyncTimeoutTask = null
    }

    fun disconnect(callback: ResultCallback<Unit>) {
        cancelActiveHealthSync(
            "HEALTH_SYNC_CANCELLED",
            "设备已断开，历史数据同步已取消",
            emitError = false,
        )
        cancelActiveConnectionAttempt(
            "CONNECT_CANCELLED",
            "连接任务已取消",
            emitError = false,
        )
        connectingDeviceId = ""
        releaseJLWatchFaceSession()
        unregisterConnectStatusListener()
        manager.disconnectWatch { code ->
            connectionHandler.post {
                if (code == Code.REQUEST_SUCCESS) {
                    connectionPreferences.edit().clear().apply()
                    connectedDeviceId = ""
                    clearMeasurementSessionState()
                    emit("disconnected", emptyMap())
                    callback.success(Unit)
                } else {
                    callback.error("DISCONNECT_FAILED", "设备断开失败")
                }
            }
        }
    }

    fun saveReportImage(
        bytes: ByteArray?,
        requestedName: String?,
        callback: ResultCallback<Any?>,
    ) = saveGalleryImage(bytes, requestedName, "image/png", callback)

    fun saveGalleryImage(
        bytes: ByteArray?,
        requestedName: String?,
        requestedMimeType: String?,
        callback: ResultCallback<Any?>,
    ) {
        if (bytes == null || bytes.isEmpty()) {
            callback.error("INVALID_GALLERY_IMAGE", "照片生成失败，请重试")
            return
        }
        val mimeType =
            requestedMimeType
                ?.takeIf { it == "image/png" || it == "image/jpeg" }
                ?: "image/png"
        val extension = if (mimeType == "image/jpeg") ".jpg" else ".png"
        val safeName =
            requestedName
                ?.replace(Regex("[^0-9A-Za-z._-]"), "_")
                ?.takeIf {
                    it.endsWith(extension, ignoreCase = true) ||
                        (mimeType == "image/jpeg" && it.endsWith(".jpeg", ignoreCase = true))
                }
                ?: "saidian-image-${System.currentTimeMillis()}$extension"
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values =
                    ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, safeName)
                        put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                        put(
                            MediaStore.Images.Media.RELATIVE_PATH,
                            "${Environment.DIRECTORY_PICTURES}/赛电",
                        )
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                val uri =
                    appContext.contentResolver.insert(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        values,
                    )
                        ?: error("MediaStore insert failed")
                appContext.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: error("MediaStore stream failed")
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                appContext.contentResolver.update(uri, values, null, null)
            } else {
                @Suppress("DEPRECATION")
                val directory =
                    File(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                        "赛电",
                    ).apply { mkdirs() }
                val file = File(directory, safeName)
                file.outputStream().use { it.write(bytes) }
                MediaScannerConnection.scanFile(
                    appContext,
                    arrayOf(file.absolutePath),
                    arrayOf(mimeType),
                    null,
                )
            }
        }.onSuccess {
            callback.success(mapOf("saved" to true, "fileName" to safeName))
        }.onFailure { error ->
            Log.e("SaidianMain", "Gallery image save failed", error)
            callback.error("GALLERY_IMAGE_SAVE_FAILED", "照片保存失败，请检查相册权限后重试")
        }
    }

    fun getDeviceDetails(): Map<String, Any?>? {
        val deviceId = connectedDeviceId.trim()
        if (deviceId.isEmpty()) return null
        if (!runCatching { manager.isDeviceConnected(deviceId) }.getOrDefault(false)) {
            clearStaleConnection(deviceId)
            return null
        }
        refreshFirmwareVersionFromSdkCache()
        connectionHandler.postDelayed({ refreshBatteryLevel() }, 200L)
        return deviceDetailsPayload(deviceId)
    }

    fun getWatchFaceProfile(callback: ResultCallback<Any?>) {
        ensureConnected(callback) ?: return
        if (!manager.isJLCPUPlatform) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持在线表盘")
            return
        }
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    callback.error("READ_TIMEOUT", "手表屏幕规格读取超时，请重新连接后重试")
                }
            }
        fun finish(profile: Map<String, Any?>? = null, message: String? = null) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            if (profile != null) callback.success(profile)
            else callback.error("READ_FAILED", message ?: "手表屏幕规格读取失败，请重新连接后重试")
        }
        connectionHandler.postDelayed(timeout, WATCH_FACE_PROFILE_TIMEOUT_MS)
        manager.readWatchUiInfo(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    connectionHandler.post {
                        finish(message = "手表屏幕规格读取失败，请重新连接后重试")
                    }
                }
            },
            EUIFromType.CUSTOM,
            object : IUIBaseInfoListener<UIDataCustom> {
                override fun onBaseUiInfo(data: UIDataCustom) {
                    connectionHandler.post {
                        val uiType = data.customUIType
                        val ui = runCatching { WatchUIType.getInstance(uiType) }.getOrNull()
                        val width = ui?.bigBitmapWidth ?: 0
                        val height = ui?.bigBitmapHeight ?: 0
                        val dialShape = resolveWatchUiTypeCode(uiType)
                        if (dialShape <= 0 || width <= 0 || height <= 0) {
                            finish(message = "手表返回的屏幕规格无效，请重新连接后重试")
                            return@post
                        }
                        watchFaceDialShape = dialShape
                        watchFaceScreenWidth = width
                        watchFaceScreenHeight = height
                        Log.i(
                            LOG_TAG,
                            "Watch-face profile type=${uiType.name} dialShape=$dialShape size=${width}x$height",
                        )
                        finish(watchFaceProfilePayload())
                    }
                }
            },
        )
    }

    private fun resolveWatchUiTypeCode(type: EWatchUIType): Int {
        val cached =
            runCatching { VpSpGetUtil.getVpSpVariInstance(appContext).watchuiCoustom }
                .getOrDefault(0)
        if (cached > 0 &&
            runCatching { EWatchUIType.getEWatchUIType(cached) == type }.getOrDefault(false)
        ) {
            return cached
        }
        for (code in 0..255) {
            if (runCatching { EWatchUIType.getEWatchUIType(code) == type }.getOrDefault(false)) {
                return code
            }
        }
        return if (runCatching { EWatchUIType.getEWatchUIType(0xFF01) == type }.getOrDefault(false)) {
            0xFF01
        } else {
            0
        }
    }

    private fun watchFaceProfilePayload(): Map<String, Any?> {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        val cachedShape = runCatching { preferences.watchuiCoustom }.getOrDefault(0)
        val dialShape =
            watchFaceDialShape.takeIf { it > 0 }
                ?: cachedShape.takeIf { it > 0 }
                ?: 58
        val cachedUi =
            runCatching {
                WatchUIType.getInstance(EWatchUIType.getEWatchUIType(dialShape))
            }.getOrNull()
        val width =
            watchFaceScreenWidth.takeIf { it > 0 }
                ?: cachedUi?.bigBitmapWidth?.takeIf { it > 0 }
                ?: 410
        val height =
            watchFaceScreenHeight.takeIf { it > 0 }
                ?: cachedUi?.bigBitmapHeight?.takeIf { it > 0 }
                ?: 502
        val deviceNumber =
            watchFaceDeviceNumber.takeIf { it > 0 }
                ?: runCatching { preferences.deviceNumber.toIntOrNull() }.getOrNull()
                ?: 6702
        val testVersion =
            watchFaceDeviceTestVersion.takeIf { it.isNotBlank() }
                ?: runCatching { preferences.testVersion.trim() }.getOrDefault("")
                    .takeIf { it.isNotBlank() }
                ?: "11.95.01.00"
        val maxLength =
            runCatching { preferences.allLength }.getOrDefault(0).takeIf { it > 0 }
                ?: 614_733
        return mapOf(
            "deviceNumber" to deviceNumber,
            "deviceTestVersion" to testVersion,
            "dialShape" to dialShape,
            "binProtocol" to 2,
            "maxLength" to maxLength,
            "screenWidth" to width,
            "screenHeight" to height,
        )
    }

    private fun clearStaleConnection(deviceId: String) {
        cancelActiveHealthSync(
            "HEALTH_SYNC_CANCELLED",
            "设备连接已断开，历史数据同步已取消",
            emitError = false,
        )
        connectingDeviceId = ""
        connectedDeviceId = ""
        connectedDeviceName = ""
        clearMeasurementSessionState()
        firmwareVersion = ""
        watchFaceDialShape = 0
        watchFaceScreenWidth = 0
        watchFaceScreenHeight = 0
        batteryPercent = null
        batteryReadInFlight = false
        releaseJLWatchFaceSession()
        unregisterConnectStatusListener()
        emit("disconnected", mapOf("deviceId" to deviceId))
    }

    fun getCapabilities(): Map<String, Any?> = capabilities

    fun readDeviceFeature(
        feature: String,
        callback: ResultCallback<Any?>,
    ) {
        ensureConnected(callback) ?: return
        when (feature) {
            "watch_faces", "photo_watch_face" -> readWatchFaces(callback)
            "screen_display" -> readScreenDisplay(callback)
            "phone_calls" -> readPhoneCalls(callback)
            "contacts" -> readContacts(callback)
            "notifications" -> readNotifications(callback)
            "alarms" -> readAlarms(callback)
            "weather" -> readWeather(callback)
            "world_clock" -> readWorldClocks(callback)
            "health_reminders" -> readHealthReminders(callback)
            "health_assessment" -> readHealthAssessment(callback)
            else -> callback.error("FEATURE_UNAVAILABLE", "此功能暂时无法使用，请稍后再试")
        }
    }

    private fun readScreenDisplay(callback: ResultCallback<Any?>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        if (!preferences.isSupportScreenlight &&
            !preferences.isSupportScreenlightTime &&
            !preferences.isSupportNightturnSetting
        ) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val values =
            mutableMapOf<String, Any?>(
                "brightness" to 1,
                "maximumBrightness" to 1,
                "automaticBrightness" to false,
                "brightnessSupported" to preferences.isSupportScreenlight,
                "raiseToWakeSupported" to preferences.isSupportNightturnSetting,
            )

        fun readRaiseToWake() {
            if (!preferences.isSupportNightturnSetting) {
                callback.success(values)
                return
            }
            val completed = AtomicBoolean(false)
            fun finish(success: Boolean) {
                if (!completed.compareAndSet(false, true)) return
                if (success) callback.success(values)
                else callback.error("READ_FAILED", "抬腕亮屏设置读取失败，请稍后重试")
            }
            manager.readNightTurnWriste(
                IBleWriteResponse { code -> if (code != Code.REQUEST_SUCCESS) finish(false) },
                INightTurnWristeDataListener { data ->
                    if (data.oprateStauts?.name != "SUCCESS") {
                        finish(false)
                        return@INightTurnWristeDataListener
                    }
                    values["raiseToWakeEnabled"] = data.isNightTureWirsteStatusOpen
                    values["raiseToWakeCustomTimeSupported"] = data.isSupportCustomSettingTime
                    values["raiseToWakeStartMinutes"] =
                        (data.startTime?.hour ?: 0) * 60 + (data.startTime?.minute ?: 0)
                    values["raiseToWakeEndMinutes"] =
                        (data.endTime?.hour ?: 0) * 60 + (data.endTime?.minute ?: 0)
                    values["raiseToWakeSensitivity"] = data.level.coerceIn(1, 10)
                    finish(true)
                },
            )
        }

        fun readDuration() {
            if (!preferences.isSupportScreenlightTime) {
                readRaiseToWake()
                return
            }
            val completed = AtomicBoolean(false)
            fun finish(success: Boolean) {
                if (!completed.compareAndSet(false, true)) return
                if (success) readRaiseToWake()
                else callback.error("READ_FAILED", "亮屏时长读取失败，请稍后重试")
            }
            manager.readScreenLightTime(
                IBleWriteResponse { code -> if (code != Code.REQUEST_SUCCESS) finish(false) },
                IScreenLightTimeListener { data ->
                    if (data.screenLightState?.name != "READ_SUCCESS") {
                        finish(false)
                        return@IScreenLightTimeListener
                    }
                    values["durationSeconds"] = data.currentDuration
                    values["minimumDurationSeconds"] = data.minDuration
                    values["maximumDurationSeconds"] = data.maxDuration
                    finish(true)
                },
            )
        }

        if (!preferences.isSupportScreenlight) {
            readDuration()
            return
        }
        val completed = AtomicBoolean(false)
        fun finishBrightness(success: Boolean) {
            if (!completed.compareAndSet(false, true)) return
            if (success) readDuration()
            else callback.error("READ_FAILED", "屏幕亮度读取失败，请稍后重试")
        }
        manager.readScreenLight(
            IBleWriteResponse { code -> if (code != Code.REQUEST_SUCCESS) finishBrightness(false) },
            IScreenLightListener { data ->
                val setting = data?.screenSetting
                if (setting == null || data.status?.name != "READ_SUCCESS") {
                    finishBrightness(false)
                    return@IScreenLightListener
                }
                lastScreenSetting = setting
                // Older W9S firmware omits maxLevel (returns 0) even though
                // ScreenSetting and the protocol use four brightness levels.
                // Keep the SDK default instead of collapsing the UI to 1/1.
                val maximum = setting.maxLevel.takeIf { it >= 2 } ?: 4
                val brightness =
                    setting.otherLeverl.takeIf { it in 1..maximum }
                        ?: setting.level.takeIf { it in 1..maximum }
                        ?: 1
                values["brightness"] = brightness
                values["maximumBrightness"] = maximum
                values["automaticBrightness"] = setting.auto == 1
                finishBrightness(true)
            },
        )
    }

    fun writeDeviceFeature(
        feature: String,
        values: Map<*, *>?,
        callback: ResultCallback<Unit>,
    ) {
        ensureConnected(callback) ?: return
        when (feature) {
            "watch_faces", "photo_watch_face" -> writeWatchFaces(feature, values, callback)
            "screen_display" -> writeScreenDisplay(values, callback)
            "phone_calls" -> writePhoneCalls(values, callback)
            "contacts" -> writeContact(values, callback)
            "notifications" -> writeNotifications(values, callback)
            "alarms" -> writeAlarm(values, callback)
            "weather" -> writeWeather(values, callback)
            "world_clock" -> writeWorldClock(values, callback)
            "health_reminders" -> writeHealthReminder(values, callback)
            "health_assessment" -> writeHealthAssessment(values, callback)
            "health_monitoring" -> writeHealthMonitoring(values, callback)
            else -> callback.error("FEATURE_UNAVAILABLE", "此功能暂时无法使用，请稍后再试")
        }
    }

    private fun writeHealthMonitoring(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        when (values?.get("operation")?.toString()) {
            "bp_calibration" -> {
                val enabled = values["enabled"] == true
                val high = (values["systolic"] as? Number)?.toInt() ?: 0
                val low = (values["diastolic"] as? Number)?.toInt() ?: 0
                if (enabled && (high !in 60..300 || low !in 20..200 || high <= low)) {
                    callback.error("INVALID_ARGUMENT", "请输入有效的收缩压和舒张压")
                    return
                }
                val completed = AtomicBoolean(false)
                fun finish(success: Boolean, message: String = "血压校准保存失败") {
                    if (!completed.compareAndSet(false, true)) return
                    if (success) callback.success(Unit) else callback.error("WRITE_FAILED", message)
                }
                manager.settingDetectBP(
                    IBleWriteResponse { code ->
                        if (code != Code.REQUEST_SUCCESS) finish(false)
                    },
                    object : IBPSettingDataListener {
                        override fun onDataChange(data: BpSettingData) {
                            finish(
                                data.status == EBPStatus.SETTING_PRIVATE_SUCCESS ||
                                    (!enabled && data.status == EBPStatus.SETTING_NORMAL_SUCCESS),
                            )
                        }
                    },
                    BpSetting(enabled, if (enabled) high else 0, if (enabled) low else 0),
                )
            }
            "glucose_calibration" -> {
                val enabled = values["enabled"] == true
                val value = (values["value"] as? Number)?.toFloat() ?: 0f
                if (enabled && (value < 1.0f || value > 30.0f)) {
                    callback.error("INVALID_ARGUMENT", "血糖校准值需在 1.0–30.0 mmol/L")
                    return
                }
                pendingGlucoseCalibration?.error("WRITE_CANCELLED", "新的校准操作已开始")
                pendingGlucoseCalibration = callback
                manager.setBloodGlucoseAdjustingData(
                    value,
                    enabled,
                    IBleWriteResponse { code ->
                        if (code != Code.REQUEST_SUCCESS) {
                            completeGlucoseCalibration(false, "血糖校准指令发送失败")
                        }
                    },
                    bloodGlucoseListener,
                )
            }
            else -> callback.error("INVALID_ARGUMENT", "请选择要校准的健康指标")
        }
    }

    private fun completeGlucoseCalibration(success: Boolean, message: String = "血糖校准保存失败") {
        val callback = pendingGlucoseCalibration ?: return
        pendingGlucoseCalibration = null
        if (success) callback.success(Unit) else callback.error("WRITE_FAILED", message)
    }

    private fun readWatchFaces(callback: ResultCallback<Any?>) {
        if (!manager.isJLCPUPlatform) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val completed = AtomicBoolean(false)
        val authenticationStarted = AtomicBoolean(false)
        val rawFallbackStarted = AtomicBoolean(false)
        var rawFallbackTimeout: Runnable? = null
        lateinit var loadRawDialList: () -> Unit
        val timeout =
            Runnable {
                if (completed.get()) return@Runnable
                Log.w(LOG_TAG, "JL categorized watch-face read timed out; trying raw list")
                loadRawDialList()
            }
        fun fail(code: String, message: String, cause: Any? = null) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            rawFallbackTimeout?.let(connectionHandler::removeCallbacks)
            Log.w(LOG_TAG, "JL watch-face session failed: $cause")
            callback.error(code, message)
        }
        loadRawDialList = {
            if (!completed.get() && rawFallbackStarted.compareAndSet(false, true)) {
                connectionHandler.removeCallbacks(timeout)
                runCatching { JLWatchFaceManager.getInstance().release() }
                    .onFailure { Log.w(LOG_TAG, "JL watch-face reader reset failed", it) }
                emit(
                    "deviceFeatureProgress",
                    mapOf("feature" to "watch_faces", "progress" to 60),
                )
                val fallbackTimeout =
                    Runnable {
                        fail(
                            "READ_TIMEOUT",
                            "表盘连接超时，请保持手表亮屏并靠近手机后重试",
                        )
                    }
                rawFallbackTimeout = fallbackTimeout
                connectionHandler.postDelayed(
                    fallbackTimeout,
                    WATCH_FACE_RAW_FALLBACK_TIMEOUT_MS,
                )
                runCatching {
                    WatchManager.getInstance().listWatchFileList(
                        object : OnWatchOpCallback<java.util.ArrayList<WatchInfo>> {
                            override fun onSuccess(result: java.util.ArrayList<WatchInfo>?) {
                                connectionHandler.post {
                                    if (!completed.compareAndSet(false, true)) return@post
                                    rawFallbackTimeout?.let(connectionHandler::removeCallbacks)
                                    val watchInfos = result.orEmpty()
                                    val files = watchInfos.mapNotNull { it.fatFile }
                                    val currentPath =
                                        watchInfos.firstOrNull {
                                            it.status == WatchInfo.WATCH_STATUS_USING
                                        }?.fatFile?.path.orEmpty()
                                    val items =
                                        files.mapIndexed { index, file ->
                                            val info = watchInfos.firstOrNull { it.fatFile?.path == file.path }
                                            watchFacePayload(
                                                file,
                                                "other",
                                                index,
                                                currentPath,
                                                info?.bitmapUri,
                                            )
                                        }
                                    availableWatchFacePaths.clear()
                                    files.mapTo(availableWatchFacePaths) { it.path }
                                    emit(
                                        "deviceFeatureProgress",
                                        mapOf("feature" to "watch_faces", "progress" to 100),
                                    )
                                    callback.success(
                                        buildMap {
                                            put("items", items)
                                            put("hasPhotoWatchFace", false)
                                            putAll(watchFaceProfilePayload())
                                        },
                                    )
                                }
                            }

                            override fun onFailed(error: BaseError) {
                                connectionHandler.post {
                                    fail(
                                        "READ_FAILED",
                                        "表盘读取失败，请保持手表靠近手机后重试",
                                        error,
                                    )
                                }
                            }
                        },
                    )
                }.onFailure { error ->
                    connectionHandler.post {
                        fail(
                            "READ_FAILED",
                            "表盘读取失败，请保持手表靠近手机后重试",
                            error,
                        )
                    }
                }
            }
        }
        lateinit var loadDialList: () -> Unit
        lateinit var authenticate: () -> Unit
        loadDialList = {
            if (!completed.get()) {
                manager.listJLWatchList(
                    object : JLWatchFaceManager.OnWatchDialInfoGetListener {
                        override fun onGettingWatchDialInfo() {
                            emit(
                                "deviceFeatureProgress",
                                mapOf("feature" to "watch_faces", "progress" to 5),
                            )
                        }

                        override fun onWatchDialInfoGetStart() {
                            emit(
                                "deviceFeatureProgress",
                                mapOf("feature" to "watch_faces", "progress" to 10),
                            )
                        }

                        override fun onWatchDialInfoGetComplete() = Unit

                        override fun onWatchDialInfoGetSuccess(
                            systemFatFiles: MutableList<FatFile>,
                            serverFatFiles: MutableList<FatFile>,
                            picFatFile: FatFile?,
                        ) {
                            val faceManager = JLWatchFaceManager.getInstance()
                            val currentReadFinished = AtomicBoolean(false)
                            val allWatchFiles = mutableListOf<FatFile>()
                            val watchInfoByPath = mutableMapOf<String, WatchInfo>()
                            fun completeWithCurrent(current: FatFile?) {
                                connectionHandler.post {
                                    if (!currentReadFinished.compareAndSet(false, true)) return@post
                                    if (!completed.compareAndSet(false, true)) return@post
                                    connectionHandler.removeCallbacks(timeout)
                                    rawFallbackTimeout?.let(connectionHandler::removeCallbacks)
                                    if (current != null) faceManager.currentFatFile = current
                                    val currentPath = current?.path.orEmpty()
                                    val items = mutableListOf<Map<String, Any?>>()
                                    systemFatFiles.forEachIndexed { index, file ->
                                        items +=
                                            watchFacePayload(
                                                file,
                                                "system",
                                                index,
                                                currentPath,
                                                watchInfoByPath[file.path]?.bitmapUri,
                                            )
                                    }
                                    serverFatFiles.forEachIndexed { index, file ->
                                        items +=
                                            watchFacePayload(
                                                file,
                                                "downloaded",
                                                index,
                                                currentPath,
                                                watchInfoByPath[file.path]?.bitmapUri,
                                            )
                                    }
                                    if (picFatFile != null) {
                                        items +=
                                            watchFacePayload(
                                                picFatFile,
                                                "photo",
                                                0,
                                                currentPath,
                                                watchInfoByPath[picFatFile.path]?.bitmapUri,
                                            )
                                    }
                                    Log.i(
                                        LOG_TAG,
                                        "All watch faces: ${allWatchFiles.joinToString { it.path }}",
                                    )
                                    allWatchFiles
                                        .filter { file ->
                                            file.name?.startsWith("WATCH", ignoreCase = true) == true &&
                                                items.none { it["id"] == file.path }
                                        }.forEachIndexed { index, file ->
                                            val type = if (file.path == currentPath) "current" else "other"
                                            items +=
                                                watchFacePayload(
                                                    file,
                                                    type,
                                                    index,
                                                    currentPath,
                                                    watchInfoByPath[file.path]?.bitmapUri,
                                                )
                                        }
                                    if (current != null && items.none { it["id"] == currentPath }) {
                                        items +=
                                            watchFacePayload(
                                                current,
                                                "current",
                                                0,
                                                currentPath,
                                                watchInfoByPath[current.path]?.bitmapUri,
                                            )
                                    }
                                    availableWatchFacePaths.clear()
                                    items.mapNotNullTo(availableWatchFacePaths) {
                                        it["id"]?.toString()?.takeIf(String::isNotBlank)
                                    }
                                    emit(
                                        "deviceFeatureProgress",
                                        mapOf("feature" to "watch_faces", "progress" to 100),
                                    )
                                    callback.success(
                                        buildMap {
                                            put("items", items)
                                            put("hasPhotoWatchFace", picFatFile != null)
                                            putAll(watchFaceProfilePayload())
                                        },
                                    )
                                }
                            }
                            fun queryCurrentWatchFace() {
                                WatchManager.getInstance().getCurrentWatchInfo(
                                    object : OnWatchOpCallback<FatFile> {
                                        override fun onSuccess(result: FatFile?) {
                                            Log.i(LOG_TAG, "Current watch face: ${result?.path}")
                                            completeWithCurrent(result)
                                        }

                                        override fun onFailed(error: BaseError) {
                                            Log.w(LOG_TAG, "Current watch face read failed: $error")
                                            completeWithCurrent(null)
                                        }
                                    },
                                )
                            }
                            connectionHandler.postDelayed(
                                {
                                    if (currentReadFinished.get()) return@postDelayed
                                    Log.w(LOG_TAG, "Current watch face read timed out")
                                    completeWithCurrent(null)
                                },
                                WATCH_FACE_CURRENT_READ_TIMEOUT_MS,
                            )
                            connectionHandler.postDelayed(
                                {
                                    WatchManager.getInstance().listWatchFileList(
                                        object : OnWatchOpCallback<java.util.ArrayList<WatchInfo>> {
                                            override fun onSuccess(result: java.util.ArrayList<WatchInfo>?) {
                                                connectionHandler.post {
                                                    allWatchFiles.clear()
                                                    watchInfoByPath.clear()
                                                    result.orEmpty().forEach { info ->
                                                        val file = info.fatFile ?: return@forEach
                                                        allWatchFiles += file
                                                        watchInfoByPath[file.path] = info
                                                    }
                                                    queryCurrentWatchFace()
                                                }
                                            }

                                            override fun onFailed(error: BaseError) {
                                                Log.w(LOG_TAG, "Complete watch face list read failed: $error")
                                                connectionHandler.post { queryCurrentWatchFace() }
                                            }
                                        },
                                    )
                                },
                                WATCH_FACE_CURRENT_READ_DELAY_MS,
                            )
                        }

                        override fun onWatchDialInfoGetFailed(error: BaseError) {
                            Log.w(LOG_TAG, "Categorized watch-face read failed; trying raw list: $error")
                            connectionHandler.post { loadRawDialList() }
                        }
                    },
                )
            }
        }
        authenticate = {
            if (!completed.get() && authenticationStarted.compareAndSet(false, true)) {
                if (RcspAuthManager.getInstance().isAuthPass) {
                    loadDialList()
                } else {
                    emit(
                        "deviceFeatureProgress",
                        mapOf("feature" to "watch_faces", "progress" to 3),
                    )
                    manager.startJLDeviceAuth(
                        object : RcspAuthResponse {
                            override fun onRcspAuthStart() = Unit

                            override fun onRcspAuthSuccess() {
                                connectionHandler.post { loadDialList() }
                            }

                            override fun onRcspAuthFailed() {
                                connectionHandler.post {
                                    fail(
                                        "AUTH_FAILED",
                                        "手表未完成表盘连接，请保持手表亮屏后重试",
                                    )
                                }
                            }
                        },
                    )
                }
            }
        }
        jlWatchFaceSessionActive = true
        connectionHandler.postDelayed(timeout, WATCH_FACE_READ_TIMEOUT_MS)
        emit("deviceFeatureProgress", mapOf("feature" to "watch_faces", "progress" to 1))
        if (manager.isJLNotifyOpened) {
            authenticate()
        } else {
            manager.openJLDataNotify(
                object : BleNotifyResponse {
                    override fun onNotify(service: UUID, characteristic: UUID, value: ByteArray) = Unit

                    override fun onResponse(code: Int) {
                        connectionHandler.post {
                            if (completed.get()) return@post
                            if (code != Code.REQUEST_SUCCESS) {
                                fail("NOTIFY_FAILED", "手表未完成表盘连接，请稍后重试", code)
                                return@post
                            }
                            val mtuCompleted = AtomicBoolean(false)
                            val continueAfterMtu = {
                                if (mtuCompleted.compareAndSet(false, true)) authenticate()
                            }
                            manager.changeMTU(
                                JL_REQUESTED_MTU,
                                IMtuChangeListener { connectionHandler.post(continueAfterMtu) },
                            )
                            // Some Android Bluetooth stacks apply the request but
                            // omit the MTU callback. Authentication can still use
                            // the negotiated/default payload size in that case.
                            connectionHandler.postDelayed(continueAfterMtu, JL_MTU_CALLBACK_GRACE_MS)
                        }
                    }
                },
            )
        }
    }

    private fun watchFacePayload(
        file: FatFile,
        type: String,
        index: Int,
        currentPath: String,
        previewPath: String? = null,
    ): Map<String, Any?> {
        val displayName =
            when (type) {
                "system" -> "系统表盘 ${index + 1}"
                "downloaded" -> "已安装表盘 ${index + 1}"
                "photo" -> "照片表盘"
                "other" -> "手表表盘 ${index + 1}"
                else -> "当前表盘"
            }
        return buildMap {
            put("id", file.path)
            put("name", displayName)
            put("fileName", file.name)
            put("type", type)
            put("index", index)
            put("isCurrent", currentPath.isNotBlank() && file.path == currentPath)
            previewPath?.trim()?.takeIf(String::isNotEmpty)?.let { put("previewPath", it) }
        }
    }

    private fun writeWatchFaces(
        feature: String,
        values: Map<*, *>?,
        callback: ResultCallback<Unit>,
    ) {
        if (!manager.isJLCPUPlatform) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        when (values?.get("operation")?.toString()) {
            "switch" -> switchWatchFace(values, callback)
            "upload_photo" -> uploadPhotoWatchFace(feature, values, callback)
            "upload_network" -> uploadNetworkWatchFace(feature, values, callback)
            else -> callback.error("INVALID_ARGUMENT", "请选择要使用的表盘")
        }
    }

    /**
     * The JL watch-face APIs are a second protocol layered on the same BLE
     * connection.  A normal Veepoo connection is not enough: notification,
     * MTU negotiation and RCSP authentication must finish before any transfer.
     * The mini-program performs these three steps before every dial operation.
     */
    private fun prepareJLWatchFaceSession(
        onReady: () -> Unit,
        onError: (String, String) -> Unit,
    ) {
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    onError("JL_SESSION_TIMEOUT", "表盘连接超时，请保持手表亮屏并靠近手机后重试")
                }
            }
        fun fail(code: String, message: String) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            onError(code, message)
        }
        fun ready() {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            jlWatchFaceSessionActive = true
            onReady()
        }
        lateinit var authenticate: () -> Unit
        authenticate = {
            if (RcspAuthManager.getInstance().isAuthPass) {
                ready()
            } else {
                manager.startJLDeviceAuth(
                    object : RcspAuthResponse {
                        override fun onRcspAuthStart() = Unit

                        override fun onRcspAuthSuccess() {
                            connectionHandler.post { ready() }
                        }

                        override fun onRcspAuthFailed() {
                            connectionHandler.post {
                                fail("JL_AUTH_FAILED", "手表未完成表盘认证，请保持手表亮屏后重试")
                            }
                        }
                    },
                )
            }
        }
        connectionHandler.postDelayed(timeout, JL_SESSION_PREPARE_TIMEOUT_MS)
        if (manager.isJLNotifyOpened) {
            authenticate()
            return
        }
        manager.openJLDataNotify(
            object : BleNotifyResponse {
                override fun onNotify(service: UUID, characteristic: UUID, value: ByteArray) = Unit

                override fun onResponse(code: Int) {
                    connectionHandler.post {
                        if (code != Code.REQUEST_SUCCESS) {
                            fail("JL_NOTIFY_FAILED", "手表未完成表盘连接，请稍后重试")
                            return@post
                        }
                        val mtuCompleted = AtomicBoolean(false)
                        val continueAfterMtu = {
                            if (mtuCompleted.compareAndSet(false, true)) authenticate()
                        }
                        manager.changeMTU(
                            JL_REQUESTED_MTU,
                            IMtuChangeListener { connectionHandler.post(continueAfterMtu) },
                        )
                        connectionHandler.postDelayed(continueAfterMtu, JL_MTU_CALLBACK_GRACE_MS)
                    }
                }
            },
        )
    }

    private fun uploadNetworkWatchFace(
        feature: String,
        values: Map<*, *>?,
        callback: ResultCallback<Unit>,
    ) {
        val path = values?.get("filePath")?.toString().orEmpty()
        val expectedWidth = (values?.get("screenWidth") as? Number)?.toInt() ?: 0
        val expectedHeight = (values?.get("screenHeight") as? Number)?.toInt() ?: 0
        val requestedMaxLength = (values?.get("maxLength") as? Number)?.toLong() ?: 0L
        val deviceMaxLength = (watchFaceProfilePayload()["maxLength"] as? Number)?.toLong() ?: 0L
        val maxLength =
            requestedMaxLength.takeIf { it > 0 }
                ?: deviceMaxLength.takeIf { it > 0 }
                ?: 614_733L
        val file = java.io.File(path)
        if (!file.isFile || file.length() <= 100 || file.length() > maxLength) {
            callback.error("INVALID_ARGUMENT", "表盘文件无效，请重新下载")
            return
        }
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    Log.w(LOG_TAG, "Network watch face upload timed out")
                    callback.error("WRITE_TIMEOUT", "表盘传送超时，请保持手表靠近手机后重试")
                }
            }
        fun finish(success: Boolean, message: String? = null) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            if (success) callback.success(Unit)
            else callback.error("TRANSFER_FAILED", message ?: "表盘设置失败，请稍后重试")
        }
        connectionHandler.postDelayed(timeout, WATCH_FACE_UPLOAD_TIMEOUT_MS)
        val startTransfer = {
            prepareJLWatchFaceSession(
                onReady = {
                    val upload =
                        Runnable {
                            JLWatchHolder.getInstance().updateJLWatchServerDial(
                                file.absolutePath,
                                object : JLWatchHolder.OnSetJLWatchDialListener {
                                    override fun onStart() {
                                        emit(
                                            "deviceFeatureProgress",
                                            mapOf("feature" to feature, "progress" to 0),
                                        )
                                    }

                                    override fun onProgress(progress: Int) {
                                        emit(
                                            "deviceFeatureProgress",
                                            mapOf(
                                                "feature" to feature,
                                                "progress" to progress.coerceIn(0, 100),
                                            ),
                                        )
                                    }

                                    override fun onComplete(path: String?) {
                                        emit(
                                            "deviceFeatureProgress",
                                            mapOf("feature" to feature, "progress" to 100),
                                        )
                                        val installedPath = path?.trim().orEmpty()
                                        if (installedPath.isBlank()) {
                                            connectionHandler.post {
                                                finish(false, "表盘已传输，但没有取得手表中的表盘位置")
                                            }
                                            return
                                        }
                                        // JLWatchHolder refreshes the FAT list and invokes its own
                                        // callback-less switch before onComplete. W9S can ignore that
                                        // shortcut while still accepting the upload. Select the exact
                                        // installed FAT path with a real callback and verify it before
                                        // telling Flutter that the operation succeeded.
                                        connectionHandler.postDelayed(
                                            {
                                                runCatching {
                                                    WatchManager.getInstance().setCurrentWatchInfo(
                                                        installedPath,
                                                        object : OnWatchOpCallback<FatFile> {
                                                            override fun onSuccess(result: FatFile?) {
                                                                connectionHandler.postDelayed(
                                                                    {
                                                                        WatchManager.getInstance()
                                                                            .getCurrentWatchInfo(
                                                                                object : OnWatchOpCallback<FatFile> {
                                                                                    override fun onSuccess(
                                                                                        current: FatFile?,
                                                                                    ) {
                                                                                        connectionHandler.post {
                                                                                            if (current != null) {
                                                                                                JLWatchFaceManager
                                                                                                    .getInstance()
                                                                                                    .currentFatFile = current
                                                                                            }
                                                                                            val active =
                                                                                                current?.path?.equals(
                                                                                                    installedPath,
                                                                                                    ignoreCase = true,
                                                                                                ) == true
                                                                                            if (active) {
                                                                                                Log.i(
                                                                                                    LOG_TAG,
                                                                                                    "Network watch face active: $installedPath",
                                                                                                )
                                                                                            }
                                                                                            finish(
                                                                                                active,
                                                                                                "表盘已传输，但手表未确认启用，请在表盘中心重试",
                                                                                            )
                                                                                        }
                                                                                    }

                                                                                    override fun onFailed(
                                                                                        error: BaseError,
                                                                                    ) {
                                                                                        Log.w(
                                                                                            LOG_TAG,
                                                                                            "Network watch face verification failed: $error",
                                                                                        )
                                                                                        connectionHandler.post {
                                                                                            finish(
                                                                                                false,
                                                                                                "表盘已传输，但无法确认是否启用，请在表盘中心重试",
                                                                                            )
                                                                                        }
                                                                                    }
                                                                                },
                                                                            )
                                                                    },
                                                                    WATCH_FACE_VERIFY_DELAY_MS,
                                                                )
                                                            }

                                                            override fun onFailed(error: BaseError) {
                                                                Log.w(
                                                                    LOG_TAG,
                                                                    "Network watch face activation failed: $error",
                                                                )
                                                                connectionHandler.post {
                                                                    finish(
                                                                        false,
                                                                        "表盘已传输，但启用失败，请在表盘中心重试",
                                                                    )
                                                                }
                                                            }
                                                        },
                                                    )
                                                }.onFailure { error ->
                                                    Log.w(
                                                        LOG_TAG,
                                                        "Network watch face activation crashed",
                                                        error,
                                                    )
                                                    finish(
                                                        false,
                                                        "表盘已传输，但启用失败，请在表盘中心重试",
                                                    )
                                                }
                                            },
                                            WATCH_FACE_SWITCH_SETTLE_MS,
                                        )
                                    }

                                    override fun onFiled(code: Int, message: String?) {
                                        Log.w(
                                            LOG_TAG,
                                            "Network watch face failed: code=$code message=$message",
                                        )
                                        connectionHandler.post {
                                            val detail = message?.trim().orEmpty()
                                            val userMessage =
                                                when (code) {
                                                    20 -> "手表表盘空间不足，请删除已安装表盘后重试"
                                                    12545 -> "手表正在忙，请退出手表当前功能后重试"
                                                    else ->
                                                        buildString {
                                                            append("表盘传输失败（错误码 ")
                                                            append(code)
                                                            append('）')
                                                            if (detail.isNotBlank()) {
                                                                append('：')
                                                                append(detail)
                                                            }
                                                        }
                                                }
                                            finish(false, userMessage)
                                        }
                                    }
                                },
                            )
                        }
                    prepareNetworkWatchFaceSlot(
                        onReady = { upload.run() },
                        onError = { message -> finish(false, message) },
                    )
                },
                onError = { _, message -> finish(false, message) },
            )
        }
        if (expectedWidth <= 0 || expectedHeight <= 0) {
            startTransfer()
            return
        }
        manager.readWatchUiInfo(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    connectionHandler.post { finish(false, "无法读取手表屏幕规格，请重新连接后重试") }
                }
            },
            EUIFromType.CUSTOM,
            object : IUIBaseInfoListener<UIDataCustom> {
                override fun onBaseUiInfo(data: UIDataCustom) {
                    val ui = WatchUIType.getInstance(data.customUIType)
                    if (ui.bigBitmapWidth != expectedWidth || ui.bigBitmapHeight != expectedHeight) {
                        finish(
                            false,
                            "该表盘为 ${expectedWidth}×${expectedHeight}，与当前手表 ${ui.bigBitmapWidth}×${ui.bigBitmapHeight} 不匹配",
                        )
                    } else {
                        startTransfer()
                    }
                }
            },
        )
    }

    private fun prepareNetworkWatchFaceSlot(
        onReady: () -> Unit,
        onError: (String) -> Unit,
    ) {
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    Log.w(LOG_TAG, "Watch-face slot inspection timed out; continuing upload")
                    onReady()
                }
            }
        fun proceed() {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            onReady()
        }
        fun fail(message: String) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            onError(message)
        }
        connectionHandler.postDelayed(timeout, WATCH_FACE_SLOT_PREPARE_TIMEOUT_MS)
        runCatching {
            manager.listJLWatchList(
                object : JLWatchFaceManager.OnWatchDialInfoGetListener {
                    override fun onGettingWatchDialInfo() = Unit

                    override fun onWatchDialInfoGetStart() = Unit

                    override fun onWatchDialInfoGetComplete() = Unit

                    override fun onWatchDialInfoGetSuccess(
                        systemFatFiles: MutableList<FatFile>,
                        serverFatFiles: MutableList<FatFile>,
                        picFatFile: FatFile?,
                    ) {
                        if (completed.get() || serverFatFiles.isEmpty() || systemFatFiles.isEmpty()) {
                            proceed()
                            return
                        }
                        WatchManager.getInstance().getCurrentWatchInfo(
                            object : OnWatchOpCallback<FatFile> {
                                override fun onSuccess(current: FatFile?) {
                                    if (completed.get()) return
                                    val currentPath = current?.path.orEmpty()
                                    val currentIsServer =
                                        serverFatFiles.any {
                                            it.path.equals(currentPath, ignoreCase = true)
                                        }
                                    if (!currentIsServer) {
                                        proceed()
                                        return
                                    }
                                    val systemPath = systemFatFiles.first().path
                                    Log.i(
                                        LOG_TAG,
                                        "Switching from active server dial $currentPath to $systemPath",
                                    )
                                    WatchManager.getInstance().setCurrentWatchInfo(
                                        systemPath,
                                        object : OnWatchOpCallback<FatFile> {
                                            override fun onSuccess(result: FatFile?) {
                                                connectionHandler.postDelayed(
                                                    { proceed() },
                                                    WATCH_FACE_REPLACE_SETTLE_MS,
                                                )
                                            }

                                            override fun onFailed(error: BaseError) {
                                                Log.w(
                                                    LOG_TAG,
                                                    "Could not leave active server dial: $error",
                                                )
                                                fail("无法暂时切换到系统表盘，请稍后重试")
                                            }
                                        },
                                    )
                                }

                                override fun onFailed(error: BaseError) {
                                    Log.w(LOG_TAG, "Current watch face read failed before upload: $error")
                                    proceed()
                                }
                            },
                        )
                    }

                    override fun onWatchDialInfoGetFailed(error: BaseError) {
                        Log.w(LOG_TAG, "Watch-face list unavailable before upload: $error")
                        proceed()
                    }
                },
            )
        }.onFailure { error ->
            Log.w(LOG_TAG, "Watch-face slot inspection failed", error)
            proceed()
        }
    }

    private fun switchWatchFace(values: Map<*, *>, callback: ResultCallback<Unit>) {
        val targetPath = values["id"]?.toString()?.trim().orEmpty()
        val faceManager = JLWatchFaceManager.getInstance()
        val allowedPaths =
            buildSet {
                faceManager.systemFatFiles.orEmpty().mapTo(this) { it.path }
                faceManager.serverFatFiles.orEmpty().mapTo(this) { it.path }
                faceManager.picFatFile?.path?.let(::add)
                faceManager.currentFatFile?.path?.let(::add)
                WatchManager.getInstance().devFatFileList.orEmpty().mapTo(this) { it.path }
                addAll(availableWatchFacePaths)
            }
        if (targetPath.isBlank() || !allowedPaths.contains(targetPath)) {
            callback.error("INVALID_ARGUMENT", "请选择要使用的表盘")
            return
        }
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    callback.error("WRITE_TIMEOUT", "表盘切换超时，请保持手表靠近手机后重试")
                }
            }
        fun finish(success: Boolean) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            if (success) callback.success(Unit)
            else callback.error("WRITE_FAILED", "表盘切换失败，请保持手表靠近手机后重试")
        }
        fun verifyCurrentFace() {
            WatchManager.getInstance().getCurrentWatchInfo(
                object : OnWatchOpCallback<FatFile> {
                    override fun onSuccess(result: FatFile?) {
                        connectionHandler.post {
                            if (result != null) faceManager.currentFatFile = result
                            finish(result?.path == targetPath)
                        }
                    }

                    override fun onFailed(error: BaseError) {
                        Log.w(LOG_TAG, "Watch face verification failed: $error")
                        connectionHandler.post { finish(false) }
                    }
                },
            )
        }
        connectionHandler.postDelayed(timeout, WATCH_FACE_SWITCH_TIMEOUT_MS)
        WatchManager.getInstance().setCurrentWatchInfo(
            targetPath,
            object : OnWatchOpCallback<FatFile> {
                override fun onSuccess(result: FatFile?) {
                    connectionHandler.postDelayed(
                        { verifyCurrentFace() },
                        WATCH_FACE_VERIFY_DELAY_MS,
                    )
                }

                override fun onFailed(error: BaseError) {
                    Log.w(LOG_TAG, "Watch face switch failed: $error")
                    connectionHandler.post { finish(false) }
                }
            },
        )
    }

    private fun uploadPhotoWatchFace(
        feature: String,
        values: Map<*, *>?,
        callback: ResultCallback<Unit>,
    ) {
        val path = values?.get("imagePath")?.toString().orEmpty()
        val file = java.io.File(path)
        if (!file.isFile || file.length() <= 100) {
            callback.error("INVALID_ARGUMENT", "请选择一张有效照片")
            return
        }
        prepareJLWatchFaceSession(
            onReady = {
                preparePhotoWatchFaceImage(
                    sourcePath = path,
                    onReady = { preparedPath ->
                        manager.setJLWatchPhotoDial(
                            preparedPath,
                            object : JLWatchFaceManager.JLTransferPicDialListener {
                        override fun onLowPower() {
                            callback.error("LOW_POWER", "手表电量较低，请充电后再设置表盘")
                        }

                        override fun onJLTransferPicDialStart() {
                            emit("deviceFeatureProgress", mapOf("feature" to feature, "progress" to 0))
                        }

                        override fun onTransferPicDialProgress(progress: Int) {
                            emit(
                                "deviceFeatureProgress",
                                mapOf("feature" to feature, "progress" to progress.coerceIn(0, 100)),
                            )
                        }

                        override fun onScaleBGPFileTransferComplete() = Unit

                        override fun onAIPreviewTransferComplete() = Unit

                        override fun onBigBGPFileTransferComplete() = Unit

                        override fun onTransferComplete() {
                            emit("deviceFeatureProgress", mapOf("feature" to feature, "progress" to 100))
                            applyPhotoWatchFaceLayout(values, callback)
                        }

                        override fun onTransferError(code: Int, errorMsg: String) {
                            Log.w(LOG_TAG, "Photo watch face failed: code=$code message=$errorMsg")
                            callback.error("TRANSFER_FAILED", "照片表盘设置失败，请保持手表靠近手机后重试")
                        }
                            },
                        )
                    },
                    onError = { code, message -> callback.error(code, message) },
                )
            },
            onError = { code, message -> callback.error(code, message) },
        )
    }

    private fun preparePhotoWatchFaceImage(
        sourcePath: String,
        onReady: (String) -> Unit,
        onError: (String, String) -> Unit,
    ) {
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    onError("PHOTO_SIZE_TIMEOUT", "手表表盘尺寸读取超时，请保持连接后重试")
                }
            }
        fun fail(code: String, message: String) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            onError(code, message)
        }
        connectionHandler.postDelayed(timeout, PHOTO_LAYOUT_TIMEOUT_MS)
        manager.readWatchUiInfo(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    connectionHandler.post {
                        fail("PHOTO_SIZE_READ_FAILED", "无法读取手表表盘尺寸，请重新连接后重试")
                    }
                }
            },
            EUIFromType.CUSTOM,
            object : IUIBaseInfoListener<UIDataCustom> {
                override fun onBaseUiInfo(data: UIDataCustom) {
                    if (!completed.compareAndSet(false, true)) return
                    connectionHandler.removeCallbacks(timeout)
                    val watchUiType = WatchUIType.getInstance(data.customUIType)
                    val targetWidth = watchUiType.bigBitmapWidth
                    val targetHeight = watchUiType.bigBitmapHeight
                    if (targetWidth <= 0 || targetHeight <= 0) {
                        onError("PHOTO_SIZE_INVALID", "手表返回的表盘尺寸无效，请重新连接后重试")
                        return
                    }
                    Thread {
                        runCatching {
                            cropPhotoForWatchFace(sourcePath, targetWidth, targetHeight)
                        }.onSuccess { preparedPath ->
                            connectionHandler.post { onReady(preparedPath) }
                        }.onFailure { error ->
                            Log.w(LOG_TAG, "Photo watch face crop failed", error)
                            connectionHandler.post {
                                onError("PHOTO_CROP_FAILED", "照片处理失败，请重新选择后重试")
                            }
                        }
                    }.start()
                }
            },
        )
    }

    private fun cropPhotoForWatchFace(
        sourcePath: String,
        targetWidth: Int,
        targetHeight: Int,
    ): String {
        val source = BitmapFactory.decodeFile(sourcePath) ?: error("Unable to decode source image")
        val output = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
        try {
            val scale =
                maxOf(
                    targetWidth.toFloat() / source.width.toFloat(),
                    targetHeight.toFloat() / source.height.toFloat(),
                )
            val matrix = Matrix()
            matrix.setScale(scale, scale)
            matrix.postTranslate(
                (targetWidth - source.width * scale) / 2f,
                (targetHeight - source.height * scale) / 2f,
            )
            Canvas(output).drawBitmap(
                source,
                matrix,
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
            )
            val prepared =
                java.io.File(
                    appContext.cacheDir,
                    "photo_watch_face_${targetWidth}x${targetHeight}.png",
                )
            java.io.FileOutputStream(prepared).use { stream ->
                check(output.compress(Bitmap.CompressFormat.PNG, 100, stream))
            }
            Log.i(
                LOG_TAG,
                "Photo watch face prepared source=${source.width}x${source.height} target=${targetWidth}x$targetHeight path=${prepared.absolutePath}",
            )
            return prepared.absolutePath
        } finally {
            source.recycle()
            output.recycle()
        }
    }

    private fun readHealthAssessment(callback: ResultCallback<Any?>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportHealthAssessment) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        manager.readFunSwitchState(
            BleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    callback.error("READ_FAILED", "辅助评估设置读取失败，请稍后重试")
                }
            },
            IFunSwitchListener { _, states ->
                val items =
                    states.entries
                        .filter { it.value.isHaveFunction }
                        .sortedBy { it.key }
                        .map { (flag, status) ->
                            mapOf(
                                "id" to flag,
                                "label" to healthAssessmentLabel(flag),
                                "enabled" to status.isOpen,
                            )
                        }
                callback.success(mapOf("items" to items))
            },
        )
    }

    private fun writeHealthAssessment(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportHealthAssessment) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val flag = (values?.get("id") as? Number)?.toInt()
        if (flag == null) {
            callback.error("INVALID_ARGUMENT", "请选择需要设置的辅助评估")
            return
        }
        val expected =
            if (values["enabled"] == true) EFunctionStatus.SUPPORT_OPEN
            else EFunctionStatus.SUPPORT_CLOSE
        manager.setFunSwitchState(
            BleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    callback.error("WRITE_FAILED", "辅助评估设置保存失败，请稍后重试")
                }
            },
            IFunSwitchListener { _, states ->
                val saved = states[flag]
                if (saved == expected || saved?.isOpen == expected.isOpen) callback.success(Unit)
                else callback.error("WRITE_FAILED", "辅助评估设置保存失败，请稍后重试")
            },
            flag,
            expected,
        )
    }

    private fun healthAssessmentLabel(flag: Int): String =
        when (flag) {
            FunSwitchFlags.BLOOD_GLUCOSE -> "血糖趋势评估"
            FunSwitchFlags.BLOOD_PRESSURE -> "血压趋势评估"
            FunSwitchFlags.BLOOD_OXYGEN -> "血氧趋势评估"
            FunSwitchFlags.BODY_TEMPERATURE -> "体温趋势评估"
            FunSwitchFlags.HRV -> "心率变异性评估"
            FunSwitchFlags.STRESS -> "压力评估"
            FunSwitchFlags.MET -> "活动强度评估"
            FunSwitchFlags.BLOOD_COMPONENT -> "血液成分评估"
            FunSwitchFlags.BODY_COMPONENT -> "身体成分评估"
            FunSwitchFlags.MICRO_PHYSICAL_EXAMINATION -> "综合健康评估"
            FunSwitchFlags.EMOTION -> "情绪评估"
            FunSwitchFlags.FATIGUE -> "疲劳评估"
            FunSwitchFlags.FALLING_REMINDER -> "跌倒提醒"
            FunSwitchFlags.SKIN_ELECTRIC_TEST -> "皮肤状态评估"
            else -> "健康辅助功能"
        }

    private fun writeScreenDisplay(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)

        fun writeRaiseToWake() {
            if (!preferences.isSupportNightturnSetting) {
                callback.success(Unit)
                return
            }
            val setting =
                NightTurnWristSetting(
                    values?.get("raiseToWakeEnabled") == true,
                    minutesToTimeData((values?.get("raiseToWakeStartMinutes") as? Number)?.toInt() ?: 0),
                    minutesToTimeData((values?.get("raiseToWakeEndMinutes") as? Number)?.toInt() ?: 0),
                    (values?.get("raiseToWakeSensitivity") as? Number)?.toInt()?.coerceIn(1, 10) ?: 5,
                )
            val completed = AtomicBoolean(false)
            fun finish(success: Boolean) {
                if (!completed.compareAndSet(false, true)) return
                if (success) callback.success(Unit)
                else callback.error("WRITE_FAILED", "抬腕亮屏设置保存失败，请稍后重试")
            }
            manager.settingNightTurnWriste(
                IBleWriteResponse { code -> if (code != Code.REQUEST_SUCCESS) finish(false) },
                INightTurnWristeDataListener { data -> finish(data.oprateStauts?.name == "SUCCESS") },
                setting,
            )
        }

        fun writeDuration() {
            if (!preferences.isSupportScreenlightTime || values?.get("durationSeconds") !is Number) {
                writeRaiseToWake()
                return
            }
            val duration =
                (values["durationSeconds"] as Number).toInt().coerceIn(
                    (values["minimumDurationSeconds"] as? Number)?.toInt() ?: 1,
                    (values["maximumDurationSeconds"] as? Number)?.toInt() ?: 60,
                )
            val completed = AtomicBoolean(false)
            fun finish(success: Boolean) {
                if (!completed.compareAndSet(false, true)) return
                if (success) writeRaiseToWake()
                else callback.error("WRITE_FAILED", "亮屏时长保存失败，请稍后重试")
            }
            manager.setScreenLightTime(
                IBleWriteResponse { code -> if (code != Code.REQUEST_SUCCESS) finish(false) },
                IScreenLightTimeListener { data ->
                    finish(data.screenLightState?.name == "SETTING_SUCCESS")
                },
                duration,
            )
        }

        if (!preferences.isSupportScreenlight) {
            writeDuration()
            return
        }
        val setting = lastScreenSetting
        if (setting == null) {
            callback.error("READ_REQUIRED", "请先刷新屏幕设置后再保存")
            return
        }
        val maximum = setting.maxLevel.takeIf { it >= 2 } ?: 4
        val level = (values?.get("brightness") as? Number)?.toInt()?.coerceIn(1, maximum) ?: 1
        setting.otherLeverl = level
        setting.level = level
        setting.auto = if (values?.get("automaticBrightness") == true) 1 else 2
        val completed = AtomicBoolean(false)
        fun finishBrightness(success: Boolean) {
            if (!completed.compareAndSet(false, true)) return
            if (success) writeDuration()
            else callback.error("WRITE_FAILED", "屏幕亮度保存失败，请稍后重试")
        }
        manager.settingScreenLight(
            IBleWriteResponse { code -> if (code != Code.REQUEST_SUCCESS) finishBrightness(false) },
            IScreenLightListener { data ->
                finishBrightness(data?.status?.name == "SETTING_SUCCESS")
            },
            setting,
        )
    }

    private fun readPhoneCalls(callback: ResultCallback<Any?>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        if (!preferences.isSupportBTFunction) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        manager.readBTInfo(
            writeResponse(callback, "通话设置读取失败，请稍后重试"),
            object : IDeviceBTInfoListener {
                override fun onDeviceBTFunctionNotSupport() {
                    callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
                }

                override fun onDeviceBTInfoSettingSuccess(info: BTInfo) = Unit

                override fun onDeviceBTInfoSettingFailed() = Unit

                override fun onDeviceBTInfoReadSuccess(info: BTInfo) {
                    callback.success(phoneCallPayload(info))
                }

                override fun onDeviceBTInfoReadFailed() {
                    callback.error("READ_FAILED", "通话设置读取失败，请稍后重试")
                }

                override fun onDeviceBTInfoReport(info: BTInfo) = Unit
            },
        )
    }

    private fun writePhoneCalls(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportBTFunction) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        manager.setBTStatus(
            values?.get("autoConnect") != false,
            values?.get("enabled") != false,
            values?.get("audioEnabled") != false,
            false,
            IBleWriteResponse { code ->
                if (code == Code.REQUEST_SUCCESS) callback.success(Unit)
                else callback.error("WRITE_FAILED", "通话设置保存失败，请稍后重试")
            },
        )
    }

    private fun phoneCallPayload(info: BTInfo): Map<String, Any?> =
        mapOf(
            "enabled" to info.isBTOpen,
            "autoConnect" to info.isAutoCon,
            "audioEnabled" to info.isAudioOpen,
            "paired" to info.isHavePairInfo,
            "connectionStatus" to info.status.name.lowercase(Locale.ROOT),
        )

    private fun readNotifications(callback: ResultCallback<Any?>) {
        manager.readSocialMsg(
            writeResponse(callback, "消息通知设置读取失败，请稍后重试"),
            object : ISocialMsgDataListener {
                override fun onSocialMsgSupportDataChange(data: FunctionSocailMsgData) {
                    finishSocialRead(data, callback)
                }

                override fun onSocialMsgSupportDataChange2(data: FunctionSocailMsgData) {
                    finishSocialRead(data, callback)
                }
            },
        )
    }

    private fun finishSocialRead(
        data: FunctionSocailMsgData,
        callback: ResultCallback<Any?>,
    ) {
        lastSocialMsgSetting = data
        callback.success(socialPayload(data))
    }

    private fun socialPayload(data: FunctionSocailMsgData): Map<String, Any?> {
        val supported = mutableListOf<String>()
        fun value(key: String, status: EFunctionStatus?): Boolean {
            if (status?.isHaveFunction == true) supported += key
            return status?.isOpen == true
        }
        return mapOf(
            "incomingCall" to value("incomingCall", data.phone),
            "sms" to value("sms", data.msg),
            "wechat" to value("wechat", data.wechat),
            "qq" to value("qq", data.qq),
            "whatsapp" to value("whatsapp", data.whats),
            "dingtalk" to value("dingtalk", data.dingding),
            "wecom" to value("wecom", data.wxWork),
            "tiktok" to value("tiktok", data.tikTok),
            "telegram" to value("telegram", data.telegram),
            "otherApps" to value("otherApps", data.other),
            "supportedKeys" to supported,
            "notificationAccess" to
                NotificationManagerCompat.getEnabledListenerPackages(appContext)
                    .contains(appContext.packageName),
        )
    }

    private fun writeNotifications(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val setting = lastSocialMsgSetting
        if (setting == null) {
            callback.error("READ_REQUIRED", "请先刷新消息通知设置后再保存")
            return
        }
        fun enabled(key: String, current: EFunctionStatus?): EFunctionStatus =
            if (current?.isHaveFunction == true) {
                if (values?.get(key) == true) EFunctionStatus.SUPPORT_OPEN
                else EFunctionStatus.SUPPORT_CLOSE
            } else {
                current ?: EFunctionStatus.UNSUPPORT
            }
        setting.phone = enabled("incomingCall", setting.phone)
        setting.msg = enabled("sms", setting.msg)
        setting.wechat = enabled("wechat", setting.wechat)
        setting.qq = enabled("qq", setting.qq)
        setting.whats = enabled("whatsapp", setting.whats)
        setting.dingding = enabled("dingtalk", setting.dingding)
        setting.wxWork = enabled("wecom", setting.wxWork)
        setting.tikTok = enabled("tiktok", setting.tikTok)
        setting.telegram = enabled("telegram", setting.telegram)
        setting.other = enabled("otherApps", setting.other)
        manager.settingSocialMsg(
            writeResponse(callback, "消息通知设置保存失败，请稍后重试"),
            object : ISocialMsgDataListener {
                override fun onSocialMsgSupportDataChange(data: FunctionSocailMsgData) {
                    lastSocialMsgSetting = data
                    saveNotificationPreferences(values)
                    callback.success(Unit)
                }

                override fun onSocialMsgSupportDataChange2(data: FunctionSocailMsgData) {
                    lastSocialMsgSetting = data
                    saveNotificationPreferences(values)
                    callback.success(Unit)
                }
            },
            setting,
        )
    }

    private fun saveNotificationPreferences(values: Map<*, *>?) {
        val editor =
            appContext.getSharedPreferences(NOTIFICATION_PREFS, Context.MODE_PRIVATE).edit()
        NOTIFICATION_KEYS.forEach { key -> editor.putBoolean(key, values?.get(key) == true) }
        editor.apply()
    }

    private fun readAlarms(callback: ResultCallback<Any?>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        when {
            preferences.isSupportTextAlarm ->
                readTextAlarmList(
                    onSuccess = { items ->
                        callback.success(mapOf("items" to items.map(::alarmPayload)))
                    },
                    onFailure = { callback.error("READ_FAILED", "闹钟读取失败，请稍后重试") },
                )
            preferences.isSupportMultiAlarm ->
                readSceneAlarmList(
                    onSuccess = { items ->
                        callback.success(mapOf("items" to items.map(::alarmPayload)))
                    },
                    onFailure = { callback.error("READ_FAILED", "闹钟读取失败，请稍后重试") },
                )
            else -> callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
        }
    }

    private fun readSceneAlarmList(
        onSuccess: (List<Alarm2Setting>) -> Unit,
        onFailure: () -> Unit,
    ) {
        val completed = AtomicBoolean(false)
        fun complete(items: List<Alarm2Setting>) {
            if (completed.compareAndSet(false, true)) onSuccess(items)
        }
        fun fail() {
            if (completed.compareAndSet(false, true)) onFailure()
        }
        manager.readAlarm2(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    fail()
                    return@IBleWriteResponse
                }
                // The SDK may either omit the callback or report SAME_CRC with
                // an empty callback list. In both cases its documented source
                // of truth is getAlarm2List().
                connectionHandler.postDelayed(
                    { complete(manager.getAlarm2List().orEmpty()) },
                    ALARM_CACHE_FALLBACK_MS,
                )
            },
            IAlarm2DataListListener { data ->
                when (data.oprate) {
                    EMultiAlarmOprate.READ_SUCCESS,
                    EMultiAlarmOprate.READ_SUCCESS_SAVE,
                    -> {
                        val items = data.alarm2SettingList.orEmpty()
                        if (items.isNotEmpty()) complete(items)
                    }
                    EMultiAlarmOprate.READ_SUCCESS_NULL -> complete(emptyList())
                    EMultiAlarmOprate.READ_SUCCESS_SAME_CRC -> Unit
                    else -> fail()
                }
            },
        )
    }

    private fun readTextAlarmList(
        onSuccess: (List<TextAlarm2Setting>) -> Unit,
        onFailure: () -> Unit,
    ) {
        val completed = AtomicBoolean(false)
        fun complete(items: List<TextAlarm2Setting>) {
            if (completed.compareAndSet(false, true)) onSuccess(items)
        }
        fun fail() {
            if (completed.compareAndSet(false, true)) onFailure()
        }
        // TextAlarmSp appends records instead of replacing the current device's
        // list. Remove only this watch's stale local entries so a full device
        // read cannot resurrect alarms deleted on the watch.
        connectedDeviceId.takeIf { it.isNotBlank() }?.let { address ->
            TextAlarmSp.getInstance(appContext).deleteAllAlarmMac(address)
        }
        manager.readTextAlarm(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    fail()
                    return@IBleWriteResponse
                }
                connectionHandler.postDelayed(
                    { complete(manager.getTextAlarmList().orEmpty()) },
                    ALARM_CACHE_FALLBACK_MS,
                )
            },
            object : ITextAlarmDataListener {
                override fun onAlarmDataChangeListListener(data: TextAlarmData?) {
                    if (data == null) {
                        fail()
                        return
                    }
                    when (data.oprate) {
                        EMultiAlarmOprate.READ_SUCCESS,
                        EMultiAlarmOprate.READ_SUCCESS_SAVE,
                        EMultiAlarmOprate.READ_SUCCESS_SAME_CRC,
                        -> connectionHandler.postDelayed(
                            { complete(manager.getTextAlarmList().orEmpty()) },
                            ALARM_CACHE_SETTLE_MS,
                        )
                        EMultiAlarmOprate.READ_SUCCESS_NULL -> complete(emptyList())
                        else -> fail()
                    }
                }
            },
        )
    }

    private fun writeAlarm(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        when {
            preferences.isSupportTextAlarm -> writeTextAlarm(values, callback)
            preferences.isSupportMultiAlarm -> writeSceneAlarm(values, callback)
            else -> callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
        }
    }

    private fun writeSceneAlarm(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val operation = values?.get("operation")?.toString().orEmpty()
        val setting = Alarm2Setting().apply {
            alarmId = (values?.get("id") as? Number)?.toInt() ?: 0
            alarmHour = (values?.get("hour") as? Number)?.toInt()?.coerceIn(0, 23) ?: 8
            alarmMinute = (values?.get("minute") as? Number)?.toInt()?.coerceIn(0, 59) ?: 0
            isOpen = values?.get("enabled") != false
            val repeatDays =
                (values?.get("repeatDays") as? List<*>)
                    .orEmpty()
                    .mapNotNull { (it as? Number)?.toInt() }
                    .toSet()
            // The protocol stores Sunday at the left and Monday at the right.
            repeatStatus = (7 downTo 1).joinToString("") { if (repeatDays.contains(it)) "1" else "0" }
            unRepeatDate =
                if (repeatDays.isEmpty()) nextAlarmDate(alarmHour, alarmMinute)
                else "0000-00-00"
            scene = 0
        }
        val completed = AtomicBoolean(false)
        fun complete() {
            if (completed.compareAndSet(false, true)) callback.success(Unit)
        }
        fun fail(code: String, message: String) {
            if (completed.compareAndSet(false, true)) callback.error(code, message)
        }
        fun matches(item: Alarm2Setting): Boolean =
            item.alarmHour == setting.alarmHour &&
                item.alarmMinute == setting.alarmMinute &&
                item.isOpen == setting.isOpen &&
                item.repeatStatus.orEmpty() == setting.repeatStatus.orEmpty()
        fun verifyWrite() {
            if (completed.get()) return
            readSceneAlarmList(
                onSuccess = { items ->
                    val verified =
                        when (operation) {
                            "delete" -> items.none { it.alarmId == setting.alarmId }
                            "update" -> items.any { it.alarmId == setting.alarmId && matches(it) }
                            else -> items.any(::matches)
                        }
                    if (verified) complete()
                    else fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                },
                onFailure = { fail("WRITE_FAILED", "闹钟保存失败，请稍后重试") },
            )
        }
        val listener =
            IAlarm2DataListListener { data ->
                val success =
                    when (operation) {
                        "delete" -> data.oprate == EMultiAlarmOprate.CLEAR_SUCCESS
                        else -> data.oprate == EMultiAlarmOprate.SETTING_SUCCESS
                    }
                if (success) complete()
                else if (data.oprate == EMultiAlarmOprate.ALARM_FULL) {
                    fail("LIMIT_REACHED", "手表闹钟数量已满")
                } else {
                    fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                }
            }
        val response =
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                } else {
                    connectionHandler.postDelayed(::verifyWrite, ALARM_WRITE_VERIFY_DELAY_MS)
                }
            }
        when (operation) {
            "add" -> manager.addAlarm2(response, listener, setting)
            "update" -> manager.modifyAlarm2(response, listener, setting)
            "delete" -> manager.deleteAlarm2(response, listener, setting)
            else -> callback.error("INVALID_ARGUMENT", "请选择要执行的闹钟操作")
        }
    }

    private fun writeTextAlarm(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val operation = values?.get("operation")?.toString().orEmpty()
        val requestedId = (values?.get("id") as? Number)?.toInt() ?: 0
        val existing =
            if (requestedId > 0) manager.getTextAlarmList().orEmpty().firstOrNull { it.alarmId == requestedId }
            else null
        if ((operation == "update" || operation == "delete") && existing == null) {
            callback.error("ALARM_NOT_FOUND", "没有找到这个闹钟，请刷新后重试")
            return
        }
        // The SDK delete/modify contract expects the object returned by the
        // preceding read. Reusing it preserves BluetoothAddress and MAFlag.
        val setting = existing ?: TextAlarm2Setting()
        if (operation == "delete") {
            deleteTextAlarmWithCompatibility(setting, callback)
            return
        }
        if (operation != "delete") setting.apply {
            alarmId = requestedId
            alarmHour = (values?.get("hour") as? Number)?.toInt()?.coerceIn(0, 23) ?: 8
            alarmMinute = (values?.get("minute") as? Number)?.toInt()?.coerceIn(0, 59) ?: 0
            isOpen = values?.get("enabled") != false
            val repeatDays =
                (values?.get("repeatDays") as? List<*>)
                    .orEmpty()
                    .mapNotNull { (it as? Number)?.toInt() }
                    .toSet()
            repeatStatus = (7 downTo 1).joinToString("") { if (repeatDays.contains(it)) "1" else "0" }
            unRepeatDate =
                if (repeatDays.isEmpty()) nextAlarmDate(alarmHour, alarmMinute)
                else "0000-00-00"
            scene = 0
            content = values?.get("label")?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: "闹钟"
        }
        val completed = AtomicBoolean(false)
        fun complete() {
            if (completed.compareAndSet(false, true)) callback.success(Unit)
        }
        fun fail(code: String, message: String) {
            if (completed.compareAndSet(false, true)) callback.error(code, message)
        }
        fun matches(item: TextAlarm2Setting): Boolean =
            item.alarmHour == setting.alarmHour &&
                item.alarmMinute == setting.alarmMinute &&
                item.isOpen == setting.isOpen &&
                item.repeatStatus.orEmpty() == setting.repeatStatus.orEmpty() &&
                item.content.orEmpty() == setting.content.orEmpty()
        fun verifyWrite() {
            if (completed.get()) return
            readTextAlarmList(
                onSuccess = { items ->
                    val verified =
                        when (operation) {
                            "update" -> items.any { it.alarmId == setting.alarmId && matches(it) }
                            else -> items.any(::matches)
                        }
                    if (verified) complete()
                    else fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                },
                onFailure = { fail("WRITE_FAILED", "闹钟保存失败，请稍后重试") },
            )
        }
        val listener =
            object : ITextAlarmDataListener {
                override fun onAlarmDataChangeListListener(data: TextAlarmData?) {
                    if (data == null) {
                        fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                        return
                    }
                    val success =
                        data.oprate == EMultiAlarmOprate.SETTING_SUCCESS
                    if (success) complete()
                    else if (data.oprate == EMultiAlarmOprate.ALARM_FULL) {
                        fail("LIMIT_REACHED", "手表闹钟数量已满")
                    } else {
                        fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                    }
                }
            }
        val response =
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    fail("WRITE_FAILED", "闹钟保存失败，请稍后重试")
                } else {
                    connectionHandler.postDelayed(::verifyWrite, ALARM_WRITE_VERIFY_DELAY_MS)
                }
            }
        when (operation) {
            "add" -> manager.addTextAlarm(response, listener, setting)
            "update" -> manager.modifyTextAlarm(response, listener, setting)
            else -> callback.error("INVALID_ARGUMENT", "请选择要执行的闹钟操作")
        }
    }

    private fun deleteTextAlarmWithCompatibility(
        initialSetting: TextAlarm2Setting,
        callback: ResultCallback<Unit>,
    ) {
        val completed = AtomicBoolean(false)
        val repairStarted = AtomicBoolean(false)

        fun complete() {
            if (completed.compareAndSet(false, true)) callback.success(Unit)
        }

        fun fail() {
            if (completed.compareAndSet(false, true)) {
                callback.error("WRITE_FAILED", "闹钟删除失败，请稍后重试")
            }
        }

        lateinit var sendDelete: (TextAlarm2Setting, Boolean) -> Unit

        fun repairAndRetry(target: TextAlarm2Setting) {
            if (completed.get() || !repairStarted.compareAndSet(false, true)) return
            // Some older alarms can be read but their original text cannot be
            // round-tripped by the firmware. Rewriting the same alarm once
            // makes the official delete command acceptable without changing
            // its time, repeat days or enabled state.
            target.content = if (safeAlarmLabel(target.content) == "闹钟") "提醒" else "闹钟"
            val verificationStarted = AtomicBoolean(false)

            fun verifyRepairAndRetry() {
                if (completed.get() || !verificationStarted.compareAndSet(false, true)) return
                readTextAlarmList(
                    onSuccess = { items ->
                        val latest = items.firstOrNull { it.alarmId == target.alarmId }
                        if (latest != null && latest.content == target.content) {
                            sendDelete(latest, false)
                        } else {
                            fail()
                        }
                    },
                    onFailure = ::fail,
                )
            }

            manager.modifyTextAlarm(
                IBleWriteResponse { code ->
                    if (code != Code.REQUEST_SUCCESS) {
                        fail()
                    } else {
                        connectionHandler.postDelayed(
                            ::verifyRepairAndRetry,
                            ALARM_WRITE_VERIFY_DELAY_MS,
                        )
                    }
                },
                object : ITextAlarmDataListener {
                    override fun onAlarmDataChangeListListener(data: TextAlarmData?) {
                        if (data?.oprate == EMultiAlarmOprate.SETTING_SUCCESS) {
                            connectionHandler.postDelayed(
                                ::verifyRepairAndRetry,
                                ALARM_CACHE_SETTLE_MS,
                            )
                        } else if (data?.oprate != null) {
                            fail()
                        }
                    }
                },
                target,
            )
        }

        sendDelete = deleteAttempt@{ target, allowRepair ->
            if (completed.get()) return@deleteAttempt
            val attemptFinished = AtomicBoolean(false)

            fun handleRejectedDelete() {
                if (!attemptFinished.compareAndSet(false, true) || completed.get()) return
                if (allowRepair) {
                    Log.w(LOG_TAG, "Text alarm delete rejected; rewriting id=${target.alarmId} before retry")
                    repairAndRetry(target)
                } else {
                    fail()
                }
            }

            fun verifyDelete() {
                if (attemptFinished.get() || completed.get()) return
                readTextAlarmList(
                    onSuccess = { items ->
                        if (!attemptFinished.compareAndSet(false, true) || completed.get()) {
                            return@readTextAlarmList
                        }
                        if (items.none { it.alarmId == target.alarmId }) {
                            complete()
                        } else if (allowRepair) {
                            Log.w(LOG_TAG, "Text alarm remained after delete; rewriting id=${target.alarmId}")
                            repairAndRetry(target)
                        } else {
                            fail()
                        }
                    },
                    onFailure = {
                        if (attemptFinished.compareAndSet(false, true)) fail()
                    },
                )
            }

            manager.deleteTextAlarm(
                IBleWriteResponse { code ->
                    if (code != Code.REQUEST_SUCCESS) {
                        handleRejectedDelete()
                    } else {
                        connectionHandler.postDelayed(
                            ::verifyDelete,
                            ALARM_WRITE_VERIFY_DELAY_MS,
                        )
                    }
                },
                object : ITextAlarmDataListener {
                    override fun onAlarmDataChangeListListener(data: TextAlarmData?) {
                        when (data?.oprate) {
                            EMultiAlarmOprate.CLEAR_SUCCESS -> {
                                if (attemptFinished.compareAndSet(false, true)) complete()
                            }
                            EMultiAlarmOprate.CLEAR_FAIL -> handleRejectedDelete()
                            null -> handleRejectedDelete()
                            else -> handleRejectedDelete()
                        }
                    }
                },
                target,
            )
        }

        sendDelete(initialSetting, true)
    }

    private fun alarmPayload(setting: Alarm2Setting): Map<String, Any?> =
        mapOf(
            "id" to setting.alarmId,
            "hour" to setting.alarmHour,
            "minute" to setting.alarmMinute,
            "enabled" to setting.isOpen,
            "label" to safeAlarmLabel((setting as? TextAlarm2Setting)?.content),
            "repeatDays" to
                setting.repeatStatus.orEmpty().mapIndexedNotNull { index, value ->
                    if (value == '1') 7 - index else null
                },
        )

    private fun safeAlarmLabel(value: String?): String {
        val text = value?.trim().orEmpty()
        if (text.isEmpty() || text.any { it == '\uFFFD' || Character.isISOControl(it) }) return "闹钟"
        return text.take(MAX_ALARM_LABEL_LENGTH)
    }

    private fun readContacts(callback: ResultCallback<Any?>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportContactFunction) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        manager.readContact(
            -1,
            object : IContactOptListener {
                override fun onContactOptSuccess(opt: EContactOpt, crc: Int) = Unit

                override fun onContactOptFailed(opt: EContactOpt) {
                    callback.error("READ_FAILED", "联系人读取失败，请稍后重试")
                }

                override fun onContactReadSuccess(contacts: List<Contact>) {
                    cachedContacts.clear()
                    cachedContacts.addAll(contacts)
                    val reportedSosIds = contacts.filter { it.isSettingSOS }.map { it.contactID }
                    if (currentSosContactId !in reportedSosIds) {
                        currentSosContactId = reportedSosIds.firstOrNull()
                    }
                    callback.success(contactListPayload())
                }

                override fun onContactReadASSameCRC() {
                    callback.success(contactListPayload())
                }

                override fun onContactReadFailed() {
                    callback.error("READ_FAILED", "联系人读取失败，请稍后重试")
                }
            },
            writeResponse(callback, "联系人读取失败，请稍后重试"),
        )
    }

    private fun writeContact(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportContactFunction) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val operation = values?.get("operation")?.toString().orEmpty()
        val id = (values?.get("id") as? Number)?.toInt() ?: nextContactId()
        val contact =
            Contact(
                id,
                values?.get("name")?.toString()?.trim().orEmpty(),
                values?.get("phone")?.toString()?.trim().orEmpty(),
                values?.get("isEmergency") == true,
                values?.get("supportsEmergency") == true ||
                    VpSpGetUtil.getVpSpVariInstance(appContext).contactType == 2,
            )
        if (operation != "delete" && (contact.name.isBlank() || contact.phoneNumber.isBlank())) {
            callback.error("INVALID_ARGUMENT", "请填写联系人姓名和电话")
            return
        }
        val listener =
            object : IContactOptListener {
                override fun onContactOptSuccess(opt: EContactOpt, crc: Int) {
                    cachedContacts.removeAll { it.contactID == contact.contactID }
                    if (operation != "delete") cachedContacts.add(contact)
                    if (operation == "emergency") {
                        currentSosContactId =
                            if (contact.isSettingSOS) contact.contactID
                            else currentSosContactId?.takeUnless { it == contact.contactID }
                    } else if (operation == "delete" && currentSosContactId == contact.contactID) {
                        currentSosContactId = null
                    }
                    callback.success(Unit)
                }

                override fun onContactOptFailed(opt: EContactOpt) {
                    callback.error("WRITE_FAILED", "联系人保存失败，请稍后重试")
                }

                override fun onContactReadSuccess(contacts: List<Contact>) = Unit

                override fun onContactReadASSameCRC() = Unit

                override fun onContactReadFailed() = Unit
            }
        val response = writeResponse(callback, "联系人保存失败，请稍后重试")
        when (operation) {
            "add" -> manager.addContact(contact, listener, response)
            "delete" -> manager.deleteContact(contact, listener, response)
            "emergency" ->
                manager.setContactSOSState(contact.isSettingSOS, contact, listener, response)
            else -> callback.error("INVALID_ARGUMENT", "请选择要执行的联系人操作")
        }
    }

    private fun contactListPayload(): Map<String, Any?> =
        mapOf("items" to cachedContacts.sortedBy { it.contactID }.map(::contactPayload))

    private fun contactPayload(contact: Contact): Map<String, Any?> =
        mapOf(
            "id" to contact.contactID,
            "name" to contact.name,
            "phone" to contact.phoneNumber,
            "isEmergency" to
                (currentSosContactId?.let { it == contact.contactID } ?: contact.isSettingSOS),
            "supportsEmergency" to contact.isSupportSOS,
        )

    private fun nextContactId(): Int =
        (1..10).firstOrNull { candidate -> cachedContacts.none { it.contactID == candidate } } ?: 11

    private fun readHealthReminders(callback: ResultCallback<Any?>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        if (!preferences.isSupportHealthRemind && preferences.isSupportLongseat) {
            readLegacySedentaryReminder(callback)
            return
        }
        if (!preferences.isSupportHealthRemind) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        cachedHealthReminders.clear()
        manager.readHealthRemind(
            HealthRemindType.ALL,
            object : IHealthRemindListener {
                override fun functionNotSupport() {
                    callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
                }

                override fun onHealthRemindRead(reminder: HealthRemind) {
                    cachedHealthReminders[reminder.remindType] = reminder
                }

                override fun onHealthRemindReadingComplete() {
                    callback.success(healthReminderListPayload())
                }

                override fun onHealthRemindReadFailed() {
                    callback.error("READ_FAILED", "健康提醒读取失败，请稍后重试")
                }

                override fun onHealthRemindReport(reminder: HealthRemind) {
                    cachedHealthReminders[reminder.remindType] = reminder
                    emit("deviceFeatureChanged", mapOf("feature" to "health_reminders"))
                }

                override fun onHealthRemindReportFailed() = Unit

                override fun onHealthRemindSettingSuccess(reminder: HealthRemind) = Unit

                override fun onHealthRemindSettingFailed(type: HealthRemindType) = Unit
            },
            writeResponse(callback, "健康提醒读取失败，请稍后重试"),
        )
    }

    private fun writeHealthReminder(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        if (values?.get("id")?.toString() == LEGACY_SEDENTARY_ID &&
            !preferences.isSupportHealthRemind &&
            preferences.isSupportLongseat
        ) {
            writeLegacySedentaryReminder(values, callback)
            return
        }
        val type = healthRemindType(values?.get("id")?.toString())
        if (type == null) {
            callback.error("INVALID_ARGUMENT", "请选择健康提醒类型")
            return
        }
        val reminder =
            HealthRemind(
                type,
                minutesToTimeData((values?.get("startMinutes") as? Number)?.toInt() ?: 480),
                minutesToTimeData((values?.get("endMinutes") as? Number)?.toInt() ?: 1320),
                (values?.get("intervalMinutes") as? Number)?.toInt()?.coerceIn(15, 240) ?: 60,
                values?.get("enabled") == true,
            )
        manager.settingHealthRemind(
            reminder,
            object : IHealthRemindListener {
                override fun functionNotSupport() {
                    callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
                }

                override fun onHealthRemindRead(reminder: HealthRemind) = Unit

                override fun onHealthRemindReadingComplete() = Unit

                override fun onHealthRemindReadFailed() = Unit

                override fun onHealthRemindReport(reminder: HealthRemind) = Unit

                override fun onHealthRemindReportFailed() = Unit

                override fun onHealthRemindSettingSuccess(saved: HealthRemind) {
                    cachedHealthReminders[saved.remindType] = saved
                    callback.success(Unit)
                }

                override fun onHealthRemindSettingFailed(type: HealthRemindType) {
                    callback.error("WRITE_FAILED", "健康提醒保存失败，请稍后重试")
                }
            },
            writeResponse(callback, "健康提醒保存失败，请稍后重试"),
        )
    }

    private fun readLegacySedentaryReminder(callback: ResultCallback<Any?>) {
        manager.readLongSeat(
            writeResponse(callback, "久坐提醒读取失败，请稍后重试"),
            ILongSeatDataListener { data ->
                when (data.status?.name) {
                    "READ_SUCCESS" ->
                        callback.success(
                            mapOf(
                                "items" to
                                    listOf(
                                        mapOf(
                                            "id" to LEGACY_SEDENTARY_ID,
                                            "label" to "久坐提醒",
                                            "enabled" to data.isOpen,
                                            "startMinutes" to (data.startHour * 60 + data.startMinute),
                                            "endMinutes" to (data.endHour * 60 + data.endMinute),
                                            "intervalMinutes" to data.threshold,
                                        ),
                                    ),
                            ),
                        )
                    "UNSUPPORT" -> callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
                    else -> callback.error("READ_FAILED", "久坐提醒读取失败，请稍后重试")
                }
            },
        )
    }

    private fun writeLegacySedentaryReminder(
        values: Map<*, *>?,
        callback: ResultCallback<Unit>,
    ) {
        val start = (values?.get("startMinutes") as? Number)?.toInt() ?: 480
        val end = (values?.get("endMinutes") as? Number)?.toInt() ?: 1320
        val expectedOpen = values?.get("enabled") == true
        val setting =
            LongSeatSetting(
                ((start % 1440) + 1440) % 1440 / 60,
                ((start % 60) + 60) % 60,
                ((end % 1440) + 1440) % 1440 / 60,
                ((end % 60) + 60) % 60,
                (values?.get("intervalMinutes") as? Number)?.toInt()?.coerceIn(10, 120) ?: 60,
                expectedOpen,
            )
        manager.settingLongSeat(
            writeResponse(callback, "久坐提醒保存失败，请稍后重试"),
            setting,
            ILongSeatDataListener { data ->
                val success =
                    data.status?.name == if (expectedOpen) "OPEN_SUCCESS" else "CLOSE_SUCCESS"
                if (success) callback.success(Unit)
                else if (data.status?.name == "UNSUPPORT") {
                    callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
                } else {
                    callback.error("WRITE_FAILED", "久坐提醒保存失败，请稍后重试")
                }
            },
        )
    }

    private fun healthReminderListPayload(): Map<String, Any?> =
        mapOf("items" to cachedHealthReminders.values.map(::healthReminderPayload))

    private fun healthReminderPayload(reminder: HealthRemind): Map<String, Any?> =
        mapOf(
            "id" to reminder.remindType.name.lowercase(Locale.ROOT),
            "label" to healthRemindLabel(reminder.remindType),
            "enabled" to reminder.status,
            "startMinutes" to (reminder.startTime.hour * 60 + reminder.startTime.minute),
            "endMinutes" to (reminder.endTime.hour * 60 + reminder.endTime.minute),
            "intervalMinutes" to reminder.interval,
        )

    private fun healthRemindType(value: String?): HealthRemindType? =
        HealthRemindType.values().firstOrNull {
            it != HealthRemindType.ALL && it.name.equals(value, ignoreCase = true)
        }

    private fun healthRemindLabel(type: HealthRemindType): String =
        when (type) {
            HealthRemindType.SEDENTARY -> "久坐提醒"
            HealthRemindType.DRINK_WATER -> "喝水提醒"
            HealthRemindType.OVERLOOK -> "远眺提醒"
            HealthRemindType.SPORTS -> "运动提醒"
            HealthRemindType.TAKE_MEDICINE -> "服药提醒"
            HealthRemindType.READING -> "阅读提醒"
            HealthRemindType.GOING_OUT -> "外出提醒"
            HealthRemindType.WASH -> "洗手提醒"
            else -> "健康提醒"
        }

    private fun readWorldClocks(callback: ResultCallback<Any?>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportWorldClock) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        manager.readWorldClock(
            -1,
            BleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    callback.error("READ_FAILED", "世界时钟读取失败，请稍后重试")
                }
            },
            object : IWorldClockOptListener {
                override fun onWorldClockReadSuccess(clocks: List<WorldClock>, crc: Int) {
                    cachedWorldClocks.clear()
                    cachedWorldClocks.addAll(clocks)
                    callback.success(worldClockListPayload())
                }

                override fun onWorldClockOptSuccess(
                    opt: IWorldClockOptListener.WorldClockOpt,
                    crc: Int,
                ) = Unit

                override fun onWorldClockOptFailed(opt: IWorldClockOptListener.WorldClockOpt) {
                    callback.error("READ_FAILED", "世界时钟读取失败，请稍后重试")
                }
            },
        )
    }

    private fun writeWorldClock(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportWorldClock) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val operation = values?.get("operation")?.toString().orEmpty()
        val id = (values?.get("id") as? Number)?.toInt() ?: nextWorldClockId()
        val city = values?.get("city")?.toString()?.trim().orEmpty()
        val offsetMinutes = (values?.get("utcOffsetMinutes") as? Number)?.toInt() ?: 0
        val clock = WorldClock(id, (offsetMinutes / 15.0).toInt(), city, city).apply {
            isOpen = values?.get("enabled") != false
        }
        if (operation != "delete" && city.isBlank()) {
            callback.error("INVALID_ARGUMENT", "请选择城市")
            return
        }
        val listener =
            object : IWorldClockOptListener {
                override fun onWorldClockReadSuccess(clocks: List<WorldClock>, crc: Int) = Unit

                override fun onWorldClockOptSuccess(
                    opt: IWorldClockOptListener.WorldClockOpt,
                    crc: Int,
                ) {
                    cachedWorldClocks.removeAll { it.id == clock.id }
                    if (operation != "delete") cachedWorldClocks.add(clock)
                    callback.success(Unit)
                }

                override fun onWorldClockOptFailed(opt: IWorldClockOptListener.WorldClockOpt) {
                    callback.error("WRITE_FAILED", "世界时钟保存失败，请稍后重试")
                }
            }
        val response =
            BleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    callback.error("WRITE_FAILED", "世界时钟保存失败，请稍后重试")
                }
            }
        when (operation) {
            "add" -> manager.addWorldClock(clock, response, listener)
            "delete" -> manager.deleteWorldClock(clock, response, listener)
            else -> callback.error("INVALID_ARGUMENT", "请选择要执行的世界时钟操作")
        }
    }

    private fun worldClockListPayload(): Map<String, Any?> =
        mapOf("items" to cachedWorldClocks.sortedBy { it.id }.map(::worldClockPayload))

    private fun worldClockPayload(clock: WorldClock): Map<String, Any?> =
        mapOf(
            "id" to clock.id,
            "city" to clock.timeZoneName,
            "utcOffsetMinutes" to clock.timeZone * 15,
            "enabled" to clock.isOpen,
        )

    private fun nextWorldClockId(): Int =
        (1..10).firstOrNull { candidate -> cachedWorldClocks.none { it.id == candidate } } ?: 11

    private fun readWeather(callback: ResultCallback<Any?>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportWeather) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        manager.readWeatherStatusInfo(
            writeResponse(callback, "天气设置读取失败，请稍后重试"),
            IWeatherStatusDataListener { data ->
                if (data.oprate != EWeatherOprateStatus.READ_SUCCESS) {
                    callback.error("READ_FAILED", "天气设置读取失败，请稍后重试")
                    return@IWeatherStatusDataListener
                }
                weatherCrc = data.crc
                callback.success(
                    mapOf(
                        "enabled" to data.isOpen,
                        "useCelsius" to (data.weatherType == EWeatherType.C),
                        "city" to lastWeatherCity,
                        "updatedAt" to lastWeatherUpdatedAt,
                    ),
                )
            },
        )
    }

    private fun writeWeather(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportWeather) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        if (values?.get("operation")?.toString() == "sync") {
            writeWeatherContent(values, callback)
            return
        }
        writeWeatherStatus(values, callback)
    }

    private fun writeWeatherStatus(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val setting =
            WeatherStatusSetting(
                weatherCrc,
                values?.get("enabled") == true,
                if (values?.get("useCelsius") != false) EWeatherType.C else EWeatherType.F,
            )
        manager.settingWeatherStatusInfo(
            writeResponse(callback, "天气设置保存失败，请稍后重试"),
            setting,
            IWeatherStatusDataListener { data ->
                if (data.oprate == EWeatherOprateStatus.SETTING_STATUS_SUCCESS) {
                    weatherCrc = data.crc
                    callback.success(Unit)
                } else {
                    callback.error("WRITE_FAILED", "天气设置保存失败，请稍后重试")
                }
            },
        )
    }

    private fun writeWeatherContent(values: Map<*, *>?, callback: ResultCallback<Unit>) {
        val city = values?.get("city")?.toString()?.trim().orEmpty()
        val updatedAt = (values?.get("updatedAt") as? Number)?.toLong() ?: System.currentTimeMillis()
        val hourlyMaps = mapList(values?.get("hourly"))
        val dailyMaps = mapList(values?.get("daily"))
        if (city.isBlank() || hourlyMaps.isEmpty() || dailyMaps.isEmpty()) {
            callback.error("INVALID_ARGUMENT", "暂时没有可同步的天气数据")
            return
        }
        val crc = ((updatedAt xor city.hashCode().toLong()) and 0xffff).toInt()
        val hourly =
            hourlyMaps.map { item ->
                val temperatureC = (item["temperatureC"] as? Number)?.toInt() ?: 0
                WeatherEvery3Hour(
                    timeDataFromMillis((item["time"] as? Number)?.toLong() ?: updatedAt),
                    celsiusToFahrenheit(temperatureC),
                    temperatureC,
                    (item["uvIndex"] as? Number)?.toInt()?.coerceIn(0, 15) ?: 0,
                    (item["weatherCode"] as? Number)?.toInt()?.coerceIn(0, 155) ?: 120,
                    item["windLevel"]?.toString().orEmpty().ifBlank { "0" },
                    ((item["visibilityMeters"] as? Number)?.toDouble() ?: 5000.0) / 1000.0,
                )
            }
        val daily =
            dailyMaps.map { item ->
                val maximumC = (item["maximumC"] as? Number)?.toInt() ?: 0
                val minimumC = (item["minimumC"] as? Number)?.toInt() ?: 0
                WeatherEveryDay(
                    timeDataFromMillis((item["time"] as? Number)?.toLong() ?: updatedAt),
                    celsiusToFahrenheit(maximumC),
                    celsiusToFahrenheit(minimumC),
                    maximumC,
                    minimumC,
                    (item["uvIndex"] as? Number)?.toInt()?.coerceIn(0, 15) ?: 0,
                    (item["dayWeatherCode"] as? Number)?.toInt()?.coerceIn(0, 155) ?: 120,
                    (item["nightWeatherCode"] as? Number)?.toInt()?.coerceIn(0, 155) ?: 120,
                    item["windLevel"]?.toString().orEmpty().ifBlank { "0" },
                    ((item["visibilityMeters"] as? Number)?.toDouble() ?: 5000.0) / 1000.0,
                )
            }
        val weatherData =
            WeatherData(
                crc,
                city,
                0,
                timeDataFromMillis(updatedAt),
                hourly,
                daily,
            )
        manager.settingWeatherData(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    callback.error("WRITE_FAILED", "天气同步失败，请稍后重试")
                }
            },
            weatherData,
            IWeatherStatusDataListener { data ->
                if (data.oprate != EWeatherOprateStatus.SETTING_CONTENT_SUCCESS) {
                    callback.error("WRITE_FAILED", "天气同步失败，请稍后重试")
                    return@IWeatherStatusDataListener
                }
                weatherCrc = data.crc
                lastWeatherCity = city
                lastWeatherUpdatedAt = updatedAt
                writeWeatherStatus(values, callback)
            },
        )
    }

    private fun mapList(value: Any?): List<Map<*, *>> =
        (value as? List<*>)?.mapNotNull { it as? Map<*, *> }.orEmpty()

    private fun timeDataFromMillis(value: Long): TimeData {
        val calendar = Calendar.getInstance().apply { timeInMillis = value }
        return TimeData(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
            calendar.get(Calendar.HOUR_OF_DAY),
            calendar.get(Calendar.MINUTE),
            calendar.get(Calendar.SECOND),
        )
    }

    private fun celsiusToFahrenheit(value: Int): Int =
        kotlin.math.round(value * 9.0 / 5.0 + 32.0).toInt()

    private fun minutesToTimeData(value: Int): TimeData {
        val normalized = ((value % 1440) + 1440) % 1440
        return TimeData(normalized / 60, normalized % 60)
    }

    private fun nextAlarmDate(hour: Int, minute: Int): String {
        val alarm = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(alarm.time)
    }

    fun triggerDeviceAction(
        feature: String,
        enabled: Boolean,
        callback: ResultCallback<Unit>,
    ) {
        ensureConnected(callback) ?: return
        if (feature == "camera") {
            triggerCamera(enabled, callback)
            return
        }
        if (feature == "notifications") {
            runCatching {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                appContext.startActivity(intent)
            }.onSuccess {
                callback.success(Unit)
            }.onFailure {
                callback.error("SETTINGS_UNAVAILABLE", "无法打开系统设置，请稍后重试")
            }
            return
        }
        if (feature != "find_watch") {
            callback.error("FEATURE_UNAVAILABLE", "此功能暂时无法使用，请稍后再试")
            return
        }
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportFindDeviceByPhone) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val listener =
            object : IFindDevicelistener {
                override fun unSupportFindDeviceByPhone() {
                    callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
                }

                override fun findedDevice() {
                    callback.success(Unit)
                }

                override fun unFindDevice() {
                    callback.success(Unit)
                }

                override fun findingDevice() {
                    callback.success(Unit)
                }
            }
        val writeResponse =
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    callback.error("WRITE_FAILED", "暂时无法查找手表，请稍后重试")
                }
            }
        if (enabled) {
            manager.startFindDeviceByPhone(writeResponse, listener)
        } else {
            manager.stopFindDeviceByPhone(writeResponse, listener)
        }
    }

    private fun triggerCamera(enabled: Boolean, callback: ResultCallback<Unit>) {
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportCamera) {
            callback.error("FEATURE_UNSUPPORTED", "当前手表不支持此功能")
            return
        }
        val listener =
            object : ICameraDataListener {
                override fun OnCameraDataChange(status: ECameraStatus) {
                    when (status) {
                        ECameraStatus.TAKEPHOTO_CAN ->
                            emit("cameraShutter", mapOf("deviceId" to connectedDeviceId))
                        ECameraStatus.OPEN_SUCCESS,
                        ECameraStatus.DEVICE_OPEN_SUCCESS,
                        ECameraStatus.CLOSE_SUCCESS,
                        -> callback.success(Unit)
                        ECameraStatus.OPEN_FALI,
                        ECameraStatus.CLOSE_FAIL,
                        ECameraStatus.TAKEPHOTO_CAN_NOT,
                        -> callback.error("CAMERA_FAILED", "相机遥控暂时无法使用，请稍后重试")
                        else -> Unit
                    }
                }
            }
        manager.setCameraListener(listener)
        val response = writeResponse(callback, "相机遥控暂时无法使用，请稍后重试")
        if (enabled) manager.startCamera(response, listener)
        else manager.stopCamera(response, listener)
    }

    fun startSport(mode: String, callback: ResultCallback<Unit>) {
        ensureConnected(callback) ?: return
        val sportType =
            when (mode) {
                "walking" -> ESportType.OUTDOOR_WALK
                "cycling" -> ESportType.OUTDOOR_RIDING
                "hiking" -> ESportType.HIKE
                else -> ESportType.OUTDOOR_RUNNING
            }
        val supportsAppControl = supportsAppSportControl()
        val supportsMultiSport = supportsMultiSportMode()
        val supportsSingleSport = supportsSingleSportMode()
        if (!supportsAppControl && !supportsMultiSport && (!supportsSingleSport || mode != "running")) {
            callback.error(
                "SPORT_MODE_UNSUPPORTED",
                if (supportsSingleSport) {
                    "当前手表仅支持由 APP 开启跑步模式"
                } else {
                    "当前手表未开放由 APP 开启运动模式"
                },
            )
            return
        }
        activeSportUsesAppControl = false
        activeControlledSportType = sportType
        val listener =
            object : ISportModelStateListener {
                override fun onSportModelStateChange(data: SportModelStateData) {
                    val returnedMode = data.sportModeType
                    Log.i(
                        LOG_TAG,
                        "sport requested=${sportType.name} multi=$supportsMultiSport returnedMode=$returnedMode mapped=${sportModeName(returnedMode)}",
                    )
                    emit(
                        "sportState",
                        mapOf(
                            "value" to "running",
                            "mode" to mode,
                            "type" to sportType.name,
                            "deviceModeType" to returnedMode,
                            "deviceStatus" to (data.getDeviceStauts()?.name ?: "unknown"),
                        ),
                    )
                    callback.success(Unit)
                }

                override fun onSportStopped() {
                    emit("sportState", mapOf("value" to "stopped", "mode" to mode))
                }
            }
        Log.i(
            LOG_TAG,
            "start sport mode=$mode type=${sportType.name} appControl=$supportsAppControl multi=$supportsMultiSport single=$supportsSingleSport",
        )
        if (supportsAppControl) {
            val guarded =
                withOperationTimeout(
                    callback,
                    "SPORT_CONTROL_TIMEOUT",
                    "手表未确认开启${sportModeLabel(mode)}，请保持连接后重试",
                )
            manager.setSportControlInfo(
                writeResponse(guarded, "运动模式暂时无法开启"),
                ESportControlType.START,
                sportType,
                object : ISportControlOptListener {
                    override fun onSportControlOptFail() {
                        guarded.error("SPORT_CONTROL_FAILED", "手表未能开启${sportModeLabel(mode)}")
                    }

                    override fun onSportControlOptSuccess() {
                        activeSportUsesAppControl = true
                        activeControlledSportType = sportType
                        emit(
                            "sportState",
                            mapOf("value" to "running", "mode" to mode, "type" to sportType.name),
                        )
                        guarded.success(Unit)
                    }

                    override fun onSportControlDataChange(dataInfo: SportControlDataInfo) {
                        Log.i(
                            LOG_TAG,
                            "sport start data requested=${sportType.name} returned=${dataInfo.sportType.name}",
                        )
                    }
                },
            )
        } else if (supportsMultiSport) {
            manager.startMultSportModel(
                writeResponse(callback, "运动模式暂时无法开启"),
                listener,
                sportType,
            )
        } else {
            // D5 single-sport devices do not accept an ESportType. This is the
            // same start command used by the mini-program and represents the
            // device's sole app-controlled running mode.
            manager.startSportModel(
                writeResponse(callback, "跑步模式暂时无法开启"),
                listener,
            )
        }
    }

    private fun supportsMultiSportMode(): Boolean =
        functionPackage2?.multSportMode.haveFunction() ||
            legacyFunctionData?.multSportModel.haveFunction()

    private fun supportsSingleSportMode(): Boolean =
        functionPackage2?.sportModelFunction.haveFunction() ||
            legacyFunctionData?.sportModel.haveFunction()

    private fun supportsAppSportControl(): Boolean =
        legacyFunctionData?.daSport.haveFunction()

    private fun sportModeLabel(mode: String): String =
        when (mode) {
            "walking" -> "步行"
            "cycling" -> "骑行"
            "hiking" -> "徒步"
            else -> "跑步"
        }

    private fun isSystemBluetoothEnabled(): Boolean =
        try {
            val bluetoothManager =
                appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bluetoothManager?.adapter?.isEnabled == true
        } catch (_: SecurityException) {
            false
        }

    fun stopSport(callback: ResultCallback<Unit>) {
        ensureConnected(callback) ?: return
        val controlledType = activeControlledSportType
        if (activeSportUsesAppControl && controlledType != null) {
            val guarded =
                withOperationTimeout(
                    callback,
                    "SPORT_CONTROL_TIMEOUT",
                    "手表未确认结束运动，请保持连接后重试",
                )
            manager.setSportControlInfo(
                writeResponse(guarded, "运动模式暂时无法结束"),
                ESportControlType.STOP,
                controlledType,
                object : ISportControlOptListener {
                    override fun onSportControlOptFail() {
                        guarded.error("SPORT_CONTROL_FAILED", "手表未能结束当前运动")
                    }

                    override fun onSportControlOptSuccess() {
                        activeSportUsesAppControl = false
                        activeControlledSportType = null
                        emit("sportState", mapOf("value" to "stopped"))
                        guarded.success(Unit)
                    }

                    override fun onSportControlDataChange(dataInfo: SportControlDataInfo) {
                        Log.i(
                            LOG_TAG,
                            "sport stop data type=${dataInfo.sportType.name} duration=${dataInfo.sportDuration}",
                        )
                    }
                },
            )
            return
        }
        manager.stopSportModel(
            writeResponse(callback, "运动模式暂时无法结束"),
            object : ISportModelStateListener {
                override fun onSportModelStateChange(data: SportModelStateData) {
                    emit("sportState", mapOf("value" to "stopped"))
                    callback.success(Unit)
                }

                override fun onSportStopped() {
                    emit("sportState", mapOf("value" to "stopped"))
                    callback.success(Unit)
                }
            },
        )
    }

    fun readSportRecords(callback: ResultCallback<List<Map<String, Any?>>>) {
        ensureConnected(callback) ?: return
        val records = mutableListOf<Map<String, Any?>>()
        synchronized(this) { activeHealthSyncRecords = records }
        manager.readSportModelOrigin(
            writeResponse(callback, "运动记录暂时无法读取"),
            object : ISportModelOriginListener {
                override fun onReadOriginProgress(progress: Float) {
                    emit("sportSyncProgress", mapOf("progress" to progress.toDouble()))
                }

                override fun onReadOriginProgressDetail(
                    crc: Int,
                    date: String,
                    progress: Int,
                    total: Int,
                ) {
                    emit(
                        "sportSyncProgress",
                        mapOf("crc" to crc, "date" to date, "progress" to progress, "total" to total),
                    )
                }

                override fun onHeadChangeListListener(data: SportModelOriginHeadData) {
                    records += sportRecord(data)
                }

                override fun onGPSWatchSportModeHeadChange(data: SportModelGPSWatchOriginHeadData) {
                    records += sportRecord(data)
                }

                override fun onItemChangeListListener(items: MutableList<SportModelOriginItemData>) = Unit

                override fun onReadOriginComplete() {
                    callback.success(records.distinctBy { it["id"] })
                }
            },
        )
    }

    private fun sportRecord(data: SportModelOriginHeadData): Map<String, Any?> {
        val startedAt = data.getStartTime()?.toFullDateTimeString().orEmpty()
        return mapOf(
            "id" to "${data.getSportType()}-$startedAt-${data.getCrc()}",
            "mode" to sportModeName(data.getSportType()),
            "startedAt" to startedAt,
            "durationSeconds" to data.getSportTime(),
            "distanceKm" to data.getDistance(),
            "calories" to data.getKcals(),
        )
    }

    private fun sportRecord(data: SportModelGPSWatchOriginHeadData): Map<String, Any?> {
        val startedAt = data.getStartTime()?.toFullDateTimeString().orEmpty()
        return mapOf(
            "id" to "${data.getSportType()}-$startedAt-${data.getCrc()}",
            "mode" to sportModeName(data.getSportType()),
            "startedAt" to startedAt,
            "durationSeconds" to data.getSportTime(),
            "distanceKm" to data.getDistance(),
            "calories" to data.getCalories(),
        )
    }

    private fun sportModeName(type: Int): String =
        when (type) {
            2, 4 -> "walking"
            7, 8 -> "cycling"
            5, 11 -> "hiking"
            else -> "running"
        }

    fun readAutoMeasureSettings(callback: ResultCallback<Map<String, Boolean>>) {
        ensureConnected(callback) ?: return
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        val legacyTypes = legacyAutoMeasureTypes(preferences)
        val supportsAutoMeasure =
            preferences.isSupportAutoMeasure ||
                functionPackage4?.autoMeasure.haveFunction() ||
                legacyFunctionData?.autoMeasure.haveFunction()
        val modernFinished = AtomicBoolean(false)
        val modernTimeout =
            Runnable {
                if (!modernFinished.compareAndSet(false, true)) return@Runnable
                if (legacyTypes.isNotEmpty()) {
                    readLegacyAutoMeasureSettings(legacyTypes, callback)
                } else if (supportsAutoMeasure) {
                    callback.error("AUTO_MEASURE_READ_TIMEOUT", "暂时未读取到自动检测设置，请稍后重试")
                } else {
                    autoMeasureSettings.clear()
                    callback.success(emptyMap())
                }
            }
        fun fallbackToLegacy() {
            if (!modernFinished.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(modernTimeout)
            if (legacyTypes.isNotEmpty()) {
                readLegacyAutoMeasureSettings(legacyTypes, callback)
            } else if (supportsAutoMeasure) {
                callback.error("AUTO_MEASURE_READ_FAILED", "手表不支持或无法读取自动检测设置")
            } else {
                autoMeasureSettings.clear()
                callback.success(emptyMap())
            }
        }
        // Some W9S firmware advertises legacy switches but still implements
        // B3 AutoMeasureData. Try the richer command first so the real 10-minute
        // cadence and writable interval capability are not lost.
        connectionHandler.postDelayed(modernTimeout, 4_000L)
        manager.readAutoMeasureSettingData(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) fallbackToLegacy()
            },
            object : IAutoMeasureSettingDataListener {
                override fun onSettingDataChange(items: MutableList<AutoMeasureData>) {
                    if (items.isEmpty()) {
                        fallbackToLegacy()
                        return
                    }
                    if (!modernFinished.compareAndSet(false, true)) return
                    connectionHandler.removeCallbacks(modernTimeout)
                    autoMeasureSettings.clear()
                    items.forEach { item ->
                        autoMeasureName(item.funType)?.let { name ->
                            autoMeasureSettings[name] = item
                        }
                    }
                    callback.success(
                        autoMeasureSettings.mapValues { (_, item) -> item.isSwitchOpen },
                    )
                }

                override fun onSettingDataChangeFail() {
                    fallbackToLegacy()
                }

                override fun onSettingDataChangeSuccess() = Unit
            },
        )
    }

    fun setAutoMeasureSetting(
        type: String,
        enabled: Boolean,
        callback: ResultCallback<Unit>,
    ) {
        ensureConnected(callback) ?: return
        val setting = autoMeasureSettings[type]
        if (setting == null) {
            setLegacyAutoMeasureSetting(type, enabled, callback)
            return
        }
        setting.isSwitchOpen = enabled
        manager.setAutoMeasureSettingData(
            writeResponse(callback, "自动检测设置保存失败"),
            setting,
            object : IAutoMeasureSettingDataListener {
                override fun onSettingDataChange(items: MutableList<AutoMeasureData>) = Unit

                override fun onSettingDataChangeFail() {
                    callback.error("AUTO_MEASURE_WRITE_FAILED", "自动检测设置写入失败")
                }

                override fun onSettingDataChangeSuccess() {
                    callback.success(Unit)
                }
            },
        )
    }

    private fun legacyAutoMeasureTypes(preferences: VpSpGetUtil): Set<String> =
        buildSet {
            if (preferences.isSupportFivemiuteHeart) add("heartRate")
            if (preferences.isSupportFivemiuteBp) add("bloodPressure")
            if (preferences.isSupportBloodGlucoseDetect) add("bloodGlucose")
            if (preferences.temperatureType > 0) add("bodyTemperature")
            if (preferences.isSupportAllDayHRV) add("hrv")
        }

    private fun readLegacyAutoMeasureSettings(
        supportedTypes: Set<String>,
        callback: ResultCallback<Map<String, Boolean>>,
    ) {
        val guardedCallback =
            withOperationTimeout(
                callback,
                "AUTO_MEASURE_READ_TIMEOUT",
                "暂时未读取到手表健康监测设置，请稍后重试",
            )
        val values = linkedMapOf<String, Boolean>()
        var finalizeTask: Runnable? = null
        manager.readCustomSetting(
            writeResponse(guardedCallback, "手表健康监测设置暂时无法读取"),
            object : ICustomSettingDataListener {
                override fun OnSettingDataChange(data: CustomSettingData) {
                    if (data.status != ECustomStatus.READ_SUCCESS &&
                        data.status != ECustomStatus.SETTING_SUCCESS
                    ) {
                        guardedCallback.error("AUTO_MEASURE_READ_FAILED", "手表健康监测设置读取失败")
                        return
                    }
                    lastCustomSettingData = data
                    Log.i(
                        LOG_TAG,
                        "Legacy auto-measure support[${data.index}]: " +
                            "heart=${data.autoHeartDetect}, bp=${data.autoBpDetect}, " +
                            "glucose=${data.bloodGlucoseDetection}, " +
                            "temperature=${data.autoTemperatureDetect}, hrv=${data.autoHrv}",
                    )
                    if (supportedTypes.contains("heartRate") &&
                        legacyAutoMeasureStatus(data, "heartRate").haveFunction()
                    ) {
                        values["heartRate"] = legacyAutoMeasureValue(data, "heartRate")
                    }
                    if (supportedTypes.contains("bloodPressure") &&
                        legacyAutoMeasureStatus(data, "bloodPressure").haveFunction()
                    ) {
                        values["bloodPressure"] = legacyAutoMeasureValue(data, "bloodPressure")
                    }
                    if (supportedTypes.contains("bloodGlucose") &&
                        legacyAutoMeasureStatus(data, "bloodGlucose").haveFunction()
                    ) {
                        values["bloodGlucose"] = legacyAutoMeasureValue(data, "bloodGlucose")
                    }
                    if (supportedTypes.contains("bodyTemperature") &&
                        legacyAutoMeasureStatus(data, "bodyTemperature").haveFunction()
                    ) {
                        values["bodyTemperature"] = legacyAutoMeasureValue(data, "bodyTemperature")
                    }
                    if (supportedTypes.contains("hrv") &&
                        legacyAutoMeasureStatus(data, "hrv").haveFunction()
                    ) {
                        values["hrv"] = legacyAutoMeasureValue(data, "hrv")
                    }
                    // W9S reports CustomSettingData in multiple packets. The
                    // temperature/glucose flags arrive shortly after the
                    // heart-rate packet, so completing on the first callback
                    // hides valid settings and makes writes appear to revert.
                    finalizeTask?.let(connectionHandler::removeCallbacks)
                    finalizeTask = Runnable {
                        autoMeasureSettings.clear()
                        guardedCallback.success(values.toMap())
                    }
                    connectionHandler.postDelayed(finalizeTask!!, 180L)
                }
            },
        )
    }

    private fun setLegacyAutoMeasureSetting(
        type: String,
        enabled: Boolean,
        callback: ResultCallback<Unit>,
    ) {
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        if (!legacyAutoMeasureTypes(preferences).contains(type)) {
            callback.error("AUTO_MEASURE_UNSUPPORTED", "当前手表不支持该自动检测功能")
            return
        }
        val current = lastCustomSettingData
        if (current == null) {
            callback.error("READ_REQUIRED", "请先刷新手表健康监测设置后再操作")
            return
        }
        val status =
            if (enabled) EFunctionStatus.SUPPORT_OPEN else EFunctionStatus.SUPPORT_CLOSE
        // Follow the SDK demo exactly: update the CustomSettingData snapshot
        // first and only then construct the payload. Some W9S firmware ignores
        // fields changed on CustomSetting after construction.
        when (type) {
            "heartRate" -> current.autoHeartDetect = status
            "bloodPressure" -> current.autoBpDetect = status
            "bloodGlucose" -> current.bloodGlucoseDetection = status
            "bodyTemperature" -> current.autoTemperatureDetect = status
            "hrv" -> current.autoHrv = status
            else -> {
                callback.error("AUTO_MEASURE_UNSUPPORTED", "当前手表不支持该自动检测功能")
                return
            }
        }
        val setting = CustomSetting(current)
        val guardedCallback =
            withOperationTimeout(
                callback,
                "AUTO_MEASURE_WRITE_TIMEOUT",
                "手表健康监测设置保存超时，请稍后重试",
            )
        val verificationStarted = AtomicBoolean(false)
        manager.changeCustomSetting(
            writeResponse(guardedCallback, "手表健康监测设置保存失败"),
            object : ICustomSettingDataListener {
                override fun OnSettingDataChange(data: CustomSettingData) {
                    if (data.status != ECustomStatus.SETTING_SUCCESS &&
                        data.status != ECustomStatus.READ_SUCCESS
                    ) {
                        guardedCallback.error("AUTO_MEASURE_WRITE_FAILED", "手表健康监测设置保存失败")
                        return
                    }
                    lastCustomSettingData = data
                    if (!verificationStarted.compareAndSet(false, true)) return
                    // SETTING_SUCCESS may carry the pre-write snapshot on W9S.
                    // Re-read from the watch before reporting success so a page
                    // refresh cannot silently flip the switch back.
                    connectionHandler.postDelayed(
                        {
                            manager.readCustomSetting(
                                writeResponse(
                                    guardedCallback,
                                    "手表健康监测设置保存后校验失败",
                                ),
                                object : ICustomSettingDataListener {
                                    override fun OnSettingDataChange(verified: CustomSettingData) {
                                        if (verified.status != ECustomStatus.READ_SUCCESS &&
                                            verified.status != ECustomStatus.SETTING_SUCCESS
                                        ) {
                                            guardedCallback.error(
                                                "AUTO_MEASURE_VERIFY_FAILED",
                                                "手表健康监测设置保存后校验失败",
                                            )
                                            return
                                        }
                                        lastCustomSettingData = verified
                                        val verifiedStatus =
                                            legacyAutoMeasureStatus(verified, type)
                                        if (!verifiedStatus.haveFunction()) {
                                            // The requested flag can be in a
                                            // later CustomSettingData packet.
                                            return
                                        }
                                        val actual = legacyAutoMeasureValue(verified, type)
                                        if (actual != enabled) {
                                            guardedCallback.error(
                                                "AUTO_MEASURE_NOT_PERSISTED",
                                                "手表未保存该健康监测开关，请保持连接后重试",
                                            )
                                            return
                                        }
                                        guardedCallback.success(Unit)
                                    }
                                },
                            )
                        },
                        1_200L,
                    )
                }
            },
            setting,
        )
    }

    fun readAutoMeasureIntervals(callback: ResultCallback<Map<String, Any?>>) {
        ensureConnected(callback) ?: return
        val modernIntervals =
            autoMeasureSettings.mapValues { (_, item) ->
                mapOf(
                    "minutes" to item.measureInterval.coerceAtLeast(0),
                    "stepMinutes" to item.stepUnit.coerceAtLeast(1),
                    "canModify" to item.isIntervalModify,
                )
            }
        if (modernIntervals.isNotEmpty()) {
            callback.success(modernIntervals)
            return
        }

        // Older W9S firmware exposes automatic-measurement
        // switches through CustomSettingData instead of AutoMeasureData. The
        // protocol has no writable interval field for that command, so show
        // the real fixed cadence rather than hiding the interval completely or
        // pretending an app-only timer changes the watch behaviour.
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        callback.success(
            legacyAutoMeasureTypes(preferences).associateWith {
                mapOf(
                    "minutes" to 10,
                    "stepMinutes" to 10,
                    "canModify" to false,
                )
            },
        )
    }

    fun setAutoMeasureInterval(
        type: String,
        minutes: Int,
        callback: ResultCallback<Unit>,
    ) {
        ensureConnected(callback) ?: return
        val setting = autoMeasureSettings[type]
        if (setting == null || !setting.isIntervalModify) {
            callback.error("AUTO_MEASURE_INTERVAL_UNSUPPORTED", "当前手表不支持调整此项监测间隔")
            return
        }
        val step = setting.stepUnit.coerceAtLeast(1)
        if (minutes < step || minutes % step != 0) {
            callback.error(
                "AUTO_MEASURE_INTERVAL_INVALID",
                "监测间隔不能小于 $step 分钟，且必须是 $step 的整数倍",
            )
            return
        }
        setting.measureInterval = minutes
        manager.setAutoMeasureSettingData(
            writeResponse(callback, "自动监测间隔保存失败"),
            setting,
            object : IAutoMeasureSettingDataListener {
                override fun onSettingDataChange(items: MutableList<AutoMeasureData>) = Unit

                override fun onSettingDataChangeFail() {
                    callback.error("AUTO_MEASURE_INTERVAL_WRITE_FAILED", "自动监测间隔写入失败")
                }

                override fun onSettingDataChangeSuccess() {
                    callback.success(Unit)
                }
            },
        )
    }

    private fun legacyAutoMeasureValue(
        data: CustomSettingData,
        type: String,
    ): Boolean =
        when (type) {
            "heartRate" -> data.autoHeartDetect.isOpen
            "bloodPressure" -> data.autoBpDetect.isOpen
            "bloodGlucose" -> data.bloodGlucoseDetection.isOpen
            "bodyTemperature" -> data.autoTemperatureDetect.isOpen
            "hrv" -> data.autoHrv.isOpen
            else -> false
        }

    private fun legacyAutoMeasureStatus(
        data: CustomSettingData,
        type: String,
    ): EFunctionStatus =
        when (type) {
            "heartRate" -> data.autoHeartDetect
            "bloodPressure" -> data.autoBpDetect
            "bloodGlucose" -> data.bloodGlucoseDetection
            "bodyTemperature" -> data.autoTemperatureDetect
            "hrv" -> data.autoHrv
            else -> EFunctionStatus.UNSUPPORT
        }

    fun readHeartRateWarning(callback: ResultCallback<Int?>) {
        ensureConnected(callback) ?: return
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        if (!preferences.isSupportHeartwaring) {
            callback.success(null)
            return
        }
        val guardedCallback =
            withOperationTimeout(
                callback,
                "HEART_WARNING_READ_TIMEOUT",
                "暂时未读取到心率预警设置，请稍后重试",
            )
        manager.readHealthAlarmInterval(
            EHealthAlarmType.HEART_RATE_ALARM,
            writeResponse(guardedCallback, "心率预警暂时无法读取"),
            object : IHealthAlarmIntervalListener {
                override fun functionNotSupport() {
                    guardedCallback.success(null)
                }

                override fun onHealthAlarmIntervalReadSuccess(
                    data: HealthAlarmInterval,
                    support: Boolean,
                ) {
                    if (support) guardedCallback.success(data.ceilingValue.toInt())
                    else guardedCallback.success(null)
                }

                override fun onHealthAlarmIntervalSetting(
                    data: HealthAlarmInterval,
                    success: Boolean,
                ) = Unit
            },
        )
    }

    fun setHeartRateWarning(value: Int, callback: ResultCallback<Unit>) {
        ensureConnected(callback) ?: return
        if (!VpSpGetUtil.getVpSpVariInstance(appContext).isSupportHeartwaring) {
            callback.error("HEART_WARNING_UNSUPPORTED", "当前手表不支持心率过高预警")
            return
        }
        val setting = HealthAlarmInterval(
            EHealthAlarmType.HEART_RATE_ALARM,
            value.coerceIn(70, 190).toFloat(),
            0f,
            true,
        )
        manager.setHealthAlarmInterval(
            setting,
            writeResponse(callback, "心率预警保存失败"),
            object : IHealthAlarmIntervalListener {
                override fun functionNotSupport() {
                    callback.error("HEART_WARNING_UNSUPPORTED", "当前手表不支持心率过高预警")
                }

                override fun onHealthAlarmIntervalReadSuccess(
                    data: HealthAlarmInterval,
                    support: Boolean,
                ) = Unit

                override fun onHealthAlarmIntervalSetting(
                    data: HealthAlarmInterval,
                    success: Boolean,
                ) {
                    if (success) callback.success(Unit)
                    else callback.error("HEART_WARNING_WRITE_FAILED", "心率预警设置失败")
                }
            },
        )
    }

    private fun autoMeasureName(type: EAutoMeasureType?): String? =
        when (type) {
            EAutoMeasureType.PULSE_RATE -> "heartRate"
            EAutoMeasureType.BLOOD_PRESSURE -> "bloodPressure"
            EAutoMeasureType.BLOOD_GLUCOSE -> "bloodGlucose"
            EAutoMeasureType.BODY_TEMPERATURE -> "bodyTemperature"
            else -> null
        }

    fun syncHealthData(cursor: String?, callback: ResultCallback<List<Map<String, Any?>>>) {
        ensureConnected(callback) ?: return
        cancelActiveHealthSync(
            "HEALTH_SYNC_SUPERSEDED",
            "历史数据同步已由新的同步任务替代",
            emitError = false,
        )
        val deviceId = connectedDeviceId
        val generation =
            synchronized(this) {
                healthSyncGeneration += 1
                activeHealthSyncCallback = callback
                activeHealthSyncDeviceId = deviceId
                activeHealthSyncProgress = 0.0
                healthSyncGeneration
            }
        val records = mutableListOf<Map<String, Any?>>()
        emitHealthSyncProgress(deviceId, cursor, 0.0)
        armHealthSyncTimeout(generation, callback, deviceId, "睡眠数据")
        manager.readSleepData(
            healthReadWriteResponse(generation, callback, deviceId, "睡眠数据"),
            object : ISleepDataListener {
                override fun onSleepDataChange(day: String, sleep: SleepData) {
                    connectionHandler.post {
                        if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                        if (sleep.allSleepTime > 0) {
                            records +=
                                record(
                                    "sleep",
                                    mapOf(
                                        "value" to sleep.allSleepTime / 60.0,
                                        "deepHours" to sleep.deepSleepTime / 60.0,
                                        "lightHours" to sleep.lowSleepTime / 60.0,
                                        "wakeCount" to sleep.wakeCount,
                                    ),
                                    "h",
                                    sleepRecordDate(day, sleep),
                                )
                        }
                        armHealthSyncTimeout(generation, callback, deviceId, "睡眠数据")
                    }
                }

                override fun onSleepProgress(progress: Float) {
                    connectionHandler.post {
                        if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                        emitHealthSyncProgress(deviceId, cursor, progress.coerceIn(0f, 1f) * 0.1)
                        armHealthSyncTimeout(generation, callback, deviceId, "睡眠数据")
                    }
                }

                override fun onSleepProgressDetail(day: String, currentPackage: Int) {
                    connectionHandler.post {
                        if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                        armHealthSyncTimeout(generation, callback, deviceId, "睡眠数据")
                    }
                }

                override fun onReadSleepComplete() {
                    connectionHandler.post {
                        if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                        emitHealthSyncProgress(deviceId, cursor, 0.1)
                        readOriginHealthData(
                            generation,
                            callback,
                            deviceId,
                            cursor,
                            records,
                        )
                    }
                }
            },
            watchDataDays,
        )
    }

    private fun readOriginHealthData(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        cursor: String?,
        records: MutableList<Map<String, Any?>>,
    ) {
        if (!isHealthSyncActive(generation, callback, deviceId)) return
        val originProtocolVersion =
            runCatching {
                VpSpGetUtil.getVpSpVariInstance(appContext).originProtocolVersion
            }.getOrDefault(0)
        val usesOriginData3 = originProtocolVersion == 3 || originProtocolVersion == 5
        Log.i(
            LOG_TAG,
            "readOriginHealthData device=$deviceId protocol=$originProtocolVersion listener=${if (usesOriginData3) "v3" else "legacy"}",
        )
        armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
        val writeResponse =
            healthReadWriteResponse(generation, callback, deviceId, "日常健康数据")
        if (usesOriginData3) {
            manager.readOriginData(
                writeResponse,
                object : IOriginData3Listener {
                    override fun onOriginFiveMinuteListDataChange(items: MutableList<OriginData3>) {
                        connectionHandler.post {
                            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                            items.forEach { appendOriginData3(it, records) }
                            emitHealthSyncProgress(deviceId, cursor, 0.38)
                            armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
                        }
                    }

                    override fun onOriginHalfHourDataChange(origin: OriginHalfHourData) {
                        connectionHandler.post {
                            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                            appendHalfHourData(origin, records)
                            emitHealthSyncProgress(deviceId, cursor, 0.62)
                            armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
                        }
                    }

                    override fun onOriginHRVOriginListDataChange(items: MutableList<HRVOriginData>) {
                        connectionHandler.post {
                            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                            items.forEach { origin ->
                                if (origin.hrvValue > 0) {
                                    val at = origin.getmTime()?.toCalendar()?.time
                                        ?: parseOriginTime(origin.date, origin.getmTime()?.clock)
                                    records += record("hrv", mapOf("value" to origin.hrvValue), "ms", at)
                                }
                            }
                            emitHealthSyncProgress(deviceId, cursor, 0.78)
                            armHealthSyncTimeout(generation, callback, deviceId, "HRV数据")
                        }
                    }

                    override fun onOriginSpo2OriginListDataChange(items: MutableList<Spo2hOriginData>) {
                        connectionHandler.post {
                            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                            items.forEach { origin ->
                                if (origin.oxygenValue > 0) {
                                    val at = origin.getmTime()?.toCalendar()?.time
                                        ?: parseOriginTime(origin.date, origin.getmTime()?.clock)
                                    records += record("blood_oxygen", mapOf("value" to origin.oxygenValue), "%", at)
                                }
                            }
                            emitHealthSyncProgress(deviceId, cursor, 0.9)
                            armHealthSyncTimeout(generation, callback, deviceId, "血氧数据")
                        }
                    }

                    override fun onReadOriginProgressDetail(
                        day: Int,
                        date: String,
                        allPackage: Int,
                        currentPackage: Int,
                    ) {
                        touchOriginHealthSync(generation, callback, deviceId)
                    }

                    override fun onReadOriginProgress(progress: Float) {
                        updateOriginHealthProgress(generation, callback, deviceId, cursor, progress)
                    }

                    override fun onReadOriginComplete() {
                        completeOriginHealthSync(generation, callback, deviceId, cursor, records)
                    }

                    override fun onReadTimeout(type: Int) {
                        timeoutOriginHealthSync(generation, callback, deviceId, type)
                    }
                },
                watchDataDays,
            )
        } else {
            manager.readOriginData(
                writeResponse,
                object : IOriginDataListener {
                    override fun onOringinFiveMinuteDataChange(origin: OriginData) {
                        connectionHandler.post {
                            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                            appendOriginData(origin, records)
                            emitHealthSyncProgress(deviceId, cursor, 0.42)
                            armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
                        }
                    }

                    override fun onOringinHalfHourDataChange(origin: OriginHalfHourData) {
                        connectionHandler.post {
                            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                            appendHalfHourData(origin, records)
                            emitHealthSyncProgress(deviceId, cursor, 0.72)
                            armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
                        }
                    }

                    override fun onReadOriginProgressDetail(
                        day: Int,
                        date: String,
                        allPackage: Int,
                        currentPackage: Int,
                    ) {
                        touchOriginHealthSync(generation, callback, deviceId)
                    }

                    override fun onReadOriginProgress(progress: Float) {
                        updateOriginHealthProgress(generation, callback, deviceId, cursor, progress)
                    }

                    override fun onReadOriginComplete() {
                        completeOriginHealthSync(generation, callback, deviceId, cursor, records)
                    }

                    override fun onReadTimeout(type: Int) {
                        timeoutOriginHealthSync(generation, callback, deviceId, type)
                    }
                },
                watchDataDays,
            )
        }
    }

    private fun appendOriginData(
        origin: OriginData,
        records: MutableList<Map<String, Any?>>,
        includeHeartRate: Boolean = true,
    ) {
        val at = origin.getmTime()?.toCalendar()?.time ?: parseOriginTime(origin.date, origin.getmTime()?.clock)
        if (includeHeartRate && origin.rateValue > 0) {
            records += record("heart_rate", mapOf("value" to origin.rateValue), "bpm", at)
        }
        if (origin.highValue > 0 && origin.lowValue > 0) {
            records +=
                record(
                    "blood_pressure",
                    mapOf("systolic" to origin.highValue, "diastolic" to origin.lowValue),
                    "mmHg",
                    at,
                )
        }
        if (origin.temperature > 0) {
            records += record("body_temperature", mapOf("value" to origin.temperature), "℃", at)
        }
    }

    private fun appendOriginData3(
        origin: OriginData3,
        records: MutableList<Map<String, Any?>>,
    ) {
        appendOriginData(origin, records, includeHeartRate = false)
        val at = origin.getmTime()?.toCalendar()?.time ?: parseOriginTime(origin.date, origin.getmTime()?.clock)
        val pulseSamples = origin.ppgs?.filter { it in 30..240 }.orEmpty()
        if (pulseSamples.isNotEmpty()) {
            records +=
                record(
                    "heart_rate",
                    mapOf("value" to pulseSamples.average()),
                    "bpm",
                    at,
                )
        }
        val oxygenSamples = origin.oxygens?.filter { it in 50..100 }.orEmpty()
        if (oxygenSamples.isNotEmpty()) {
            records +=
                record(
                    "blood_oxygen",
                    mapOf("value" to oxygenSamples.average()),
                    "%",
                    at,
                )
        }
        if (origin.bloodGlucose > 0) {
            records += record(
                "blood_glucose",
                mapOf("value" to origin.bloodGlucose),
                "mmol/L",
                at,
            )
        }
        origin.bloodComponent?.let { component ->
            val values = buildMap<String, Number> {
                if (component.uricAcid > 0) put("uricAcid", component.uricAcid)
                if (component.tCHO > 0) put("totalCholesterol", component.tCHO)
                if (component.tAG > 0) put("triglycerides", component.tAG)
                if (component.hDL > 0) put("highDensityLipoprotein", component.hDL)
                if (component.lDL > 0) put("lowDensityLipoprotein", component.lDL)
            }
            if (values.isNotEmpty()) {
                records += record("blood_composition", values, "", at)
            }
        }
    }

    private fun appendHalfHourData(
        origin: OriginHalfHourData,
        records: MutableList<Map<String, Any?>>,
    ) {
        origin.halfHourSportDatas.orEmpty().forEach { sport ->
            val at = sport.time?.toCalendar()?.time ?: parseOriginTime(sport.date, sport.time?.clock)
            if (sport.stepValue > 0) records += record("steps", mapOf("value" to sport.stepValue), "步", at)
            if (sport.disValue > 0) records += record("distance", mapOf("value" to sport.disValue), "km", at)
            if (sport.calValue > 0) records += record("calories", mapOf("value" to sport.calValue), "kcal", at)
        }
    }

    private fun touchOriginHealthSync(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
    ) {
        connectionHandler.post {
            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
            armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
        }
    }

    private fun updateOriginHealthProgress(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        cursor: String?,
        progress: Float,
    ) {
        connectionHandler.post {
            if (!isHealthSyncActive(generation, callback, deviceId)) return@post
            emitHealthSyncProgress(
                deviceId,
                cursor,
                0.1 + progress.coerceIn(0f, 1f) * 0.9,
            )
            armHealthSyncTimeout(generation, callback, deviceId, "日常健康数据")
        }
    }

    private fun completeOriginHealthSync(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        cursor: String?,
        records: MutableList<Map<String, Any?>>,
    ) {
        connectionHandler.post {
            if (!finishHealthSync(generation, callback, deviceId)) return@post
            emitHealthSyncProgress(deviceId, cursor, 1.0)
            callback.success(records.distinctBy { it["id"] })
        }
    }

    private fun timeoutOriginHealthSync(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        type: Int,
    ) {
        connectionHandler.post {
            failHealthSync(
                generation,
                callback,
                deviceId,
                "HEALTH_READ_TIMEOUT",
                "设备日常健康数据读取超时（类型 $type）",
            )
        }
    }

    private fun healthReadWriteResponse(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        stage: String,
    ) =
        IBleWriteResponse { code ->
            connectionHandler.post {
                if (!isHealthSyncActive(generation, callback, deviceId)) return@post
                if (code == Code.REQUEST_SUCCESS) {
                    armHealthSyncTimeout(generation, callback, deviceId, stage)
                } else {
                    failHealthSync(
                        generation,
                        callback,
                        deviceId,
                        "HEALTH_READ_WRITE_FAILED",
                        "${stage}读取失败，请保持手表靠近手机后重试",
                    )
                }
            }
        }

    private fun emitHealthSyncProgress(deviceId: String, cursor: String?, progress: Double) {
        val monotonic =
            synchronized(this) {
                activeHealthSyncProgress =
                    maxOf(activeHealthSyncProgress, progress.coerceIn(0.0, 1.0))
                activeHealthSyncProgress
            }
        emit(
            "syncProgress",
            mapOf(
                "deviceId" to deviceId,
                "progress" to monotonic,
                "cursor" to cursor,
            ),
        )
    }

    private fun isHealthSyncActive(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
    ): Boolean =
        synchronized(this) {
            healthSyncGeneration == generation &&
                activeHealthSyncCallback === callback &&
                activeHealthSyncDeviceId.equals(deviceId, ignoreCase = true) &&
                connectedDeviceId.equals(deviceId, ignoreCase = true)
        }

    private fun armHealthSyncTimeout(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        stage: String,
    ) {
        if (!isHealthSyncActive(generation, callback, deviceId)) return
        healthSyncTimeoutTask?.let(connectionHandler::removeCallbacks)
        val timeout =
            Runnable {
                Log.w(LOG_TAG, "health sync idle timeout device=$deviceId stage=$stage")
                failHealthSync(
                    generation,
                    callback,
                    deviceId,
                    "HEALTH_READ_TIMEOUT",
                    "设备${stage}读取超时",
                )
            }
        healthSyncTimeoutTask = timeout
        connectionHandler.postDelayed(timeout, HEALTH_SYNC_IDLE_TIMEOUT_MS)
    }

    private fun finishHealthSync(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
    ): Boolean {
        val claimed =
            synchronized(this) {
                if (healthSyncGeneration != generation ||
                    activeHealthSyncCallback !== callback ||
                    !activeHealthSyncDeviceId.equals(deviceId, ignoreCase = true)
                ) {
                    false
                } else {
                    activeHealthSyncCallback = null
                    activeHealthSyncDeviceId = ""
                    activeHealthSyncRecords = null
                    true
                }
            }
        if (claimed) {
            healthSyncTimeoutTask?.let(connectionHandler::removeCallbacks)
            healthSyncTimeoutTask = null
        }
        return claimed
    }

    private fun failHealthSync(
        generation: Int,
        callback: ResultCallback<List<Map<String, Any?>>>,
        deviceId: String,
        code: String,
        message: String,
    ) {
        val partialRecords =
            synchronized(this) {
                activeHealthSyncRecords?.toList().orEmpty()
            }.distinctBy { it["id"] }
        if (!finishHealthSync(generation, callback, deviceId)) return
        if (partialRecords.isNotEmpty()) {
            Log.w(LOG_TAG, "health sync returned ${partialRecords.size} partial records after $code")
            emit(
                "syncProgress",
                mapOf("deviceId" to deviceId, "progress" to 1.0, "partial" to true),
            )
            callback.success(partialRecords)
            return
        }
        emit("error", mapOf("code" to code, "message" to message, "deviceId" to deviceId))
        callback.error(code, message)
    }

    private fun cancelActiveHealthSync(
        code: String,
        message: String,
        emitError: Boolean,
    ) {
        val callback =
            synchronized(this) {
                val current = activeHealthSyncCallback
                activeHealthSyncCallback = null
                activeHealthSyncDeviceId = ""
                activeHealthSyncRecords = null
                healthSyncGeneration += 1
                current
            }
        healthSyncTimeoutTask?.let(connectionHandler::removeCallbacks)
        healthSyncTimeoutTask = null
        if (callback != null) {
            if (emitError) emit("error", mapOf("code" to code, "message" to message))
            callback.error(code, message)
        }
    }

    fun startMeasurement(metric: String, callback: ResultCallback<Unit>) {
        ensureConnected(callback) ?: return
        if (!(capabilities["metrics"] as List<*>).contains(metric)) {
            callback.error("UNSUPPORTED_METRIC", "当前设备不支持该指标")
            return
        }
        if (activeMetric != null) {
            callback.error("MEASUREMENT_DEVICE_BUSY", "另一项手表测量尚未结束，请稍后重试")
            return
        }
        activeMetric = metric
        armMeasurementResultTimeout(metric)
        Log.i(LOG_TAG, "measurement start metric=$metric device=$connectedDeviceId")
        emit("state", mapOf("value" to "measuring", "metric" to metric))
        try {
            when (metric) {
                "heart_rate" -> manager.startDetectHeart(measurementWrite(callback), heartDataListener)
                "blood_pressure" -> startBloodPressureMeasurement(callback)
                "blood_oxygen" -> manager.startDetectSPO2H(measurementWrite(callback), oxygenDataListener)
                "body_temperature" -> {
                    temperatureRetryUsed = false
                    manager.startDetectTempture(measurementWrite(callback), temperatureDataListener)
                }
                "blood_glucose" -> manager.startBloodGlucoseDetect(measurementWrite(callback), bloodGlucoseListener)
                "body_composition" -> manager.startDetectBodyComponent(measurementWrite(callback), bodyComponentListener)
                "blood_composition" ->
                    manager.startDetectBloodComponent(measurementWrite(callback), false, bloodComponentListener)
                "ecg" -> {
                    resetEcgMeasurementStream()
                    manager.startDetectECG(measurementWrite(callback), true, ecgListener)
                }
                "hrv" -> {
                    val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
                    // W9S firmware does not expose the standalone HRV command,
                    // but its supported mini-checkup protocol returns HRV as a
                    // first-class result. Use that official route so the watch
                    // opens its health check page and returns progress/errors.
                    if (hrvMiniCheckupSupported) {
                        activeHrvUsesEcg = false
                        activeHrvUsesMiniCheckup = true
                        manager.startMiniCheckup(
                            BleWriteResponse { code ->
                                connectionHandler.post {
                                    if (code == Code.REQUEST_SUCCESS) {
                                        Log.i(LOG_TAG, "HRV mini-checkup command accepted")
                                        callback.success(Unit)
                                    } else {
                                        activeHrvUsesMiniCheckup = false
                                        measurementResultTimeoutTask?.let(connectionHandler::removeCallbacks)
                                        measurementResultTimeoutTask = null
                                        synchronized(this) {
                                            if (activeMetric == "hrv") activeMetric = null
                                        }
                                        callback.error(
                                            "HRV_MEASUREMENT_FAILED",
                                            "手表未能开始 HRV 健康检测，请稍后重试",
                                        )
                                    }
                                }
                            },
                            miniCheckupHrvListener,
                        )
                    } else if (directHrvMeasurementSupported || preferences.isSupportHrvAppDetect) {
                        activeHrvUsesEcg = false
                        activeHrvUsesMiniCheckup = false
                        manager.startDetectHrv(measurementWrite(callback), hrvListener)
                    } else if (preferences.isSupportECG) {
                        // Some W9S firmware exposes HRV only as part of the ECG
                        // result.  Use the vendor ECG result instead of failing
                        // an otherwise measurable HRV entry.
                        resetEcgMeasurementStream()
                        activeHrvUsesEcg = true
                        activeHrvUsesMiniCheckup = false
                        manager.startDetectECG(measurementWrite(callback), true, ecgListener)
                    } else {
                        throw IllegalStateException("HRV app measurement is not supported")
                    }
                }
                else -> {
                    synchronized(this) { activeMetric = null }
                    callback.error("MEASUREMENT_NOT_AVAILABLE", "该指标仅支持同步手表历史数据")
                }
            }
        } catch (error: Throwable) {
            measurementResultTimeoutTask?.let(connectionHandler::removeCallbacks)
            measurementResultTimeoutTask = null
            synchronized(this) {
                if (activeMetric == metric) activeMetric = null
            }
            Log.e(LOG_TAG, "measurement start failed metric=$metric", error)
            callback.error(
                "MEASUREMENT_START_FAILED",
                "暂时无法开始${measurementMetricLabel(metric)}测量，请稍后重试",
            )
        }
    }

    fun stopMeasurement(metric: String, callback: ResultCallback<Unit>) {
        measurementResultTimeoutTask?.let(connectionHandler::removeCallbacks)
        measurementResultTimeoutTask = null
        val response = measurementStopWrite(callback, metric)
        when (metric) {
            "heart_rate" -> manager.stopDetectHeart(response)
            "blood_pressure" -> {
                cancelPendingBloodPressureStart()
                if (activeBloodPressureUsesMiniCheckup) {
                    manager.stopMiniCheckup(
                        BleWriteResponse { code ->
                            activeBloodPressureUsesMiniCheckup = false
                            if (code == Code.REQUEST_SUCCESS) {
                                callback.success(Unit)
                            } else {
                                callback.error("MEASUREMENT_STOP_FAILED", "暂时无法停止血压测量")
                            }
                        },
                        miniCheckupBloodPressureListener,
                    )
                } else {
                    manager.stopDetectBP(response, activeBloodPressureMode)
                }
            }
            "blood_oxygen" -> manager.stopDetectSPO2H(response, oxygenDataListener)
            "body_temperature" -> manager.stopDetectTempture(response, temperatureDataListener)
            "blood_glucose" -> manager.stopBloodGlucoseDetect(response, bloodGlucoseListener)
            "body_composition" -> manager.stopDetectBodyComponent(response)
            "blood_composition" -> manager.stopDetectBloodComponent(response)
            "ecg" -> manager.stopDetectECG(response, true, ecgListener)
            "hrv" -> {
                if (activeHrvUsesMiniCheckup) {
                    manager.stopMiniCheckup(
                        BleWriteResponse { code ->
                            activeHrvUsesMiniCheckup = false
                            if (code == Code.REQUEST_SUCCESS) {
                                callback.success(Unit)
                            } else {
                                callback.error("MEASUREMENT_STOP_FAILED", "暂时无法停止 HRV 测量")
                            }
                        },
                        miniCheckupHrvListener,
                    )
                } else if (activeHrvUsesEcg) {
                    manager.stopDetectECG(response, true, ecgListener)
                } else {
                    manager.stopDetectHrv(response, hrvListener)
                }
                activeHrvUsesEcg = false
                activeHrvUsesMiniCheckup = false
            }
            else -> callback.error("MEASUREMENT_NOT_AVAILABLE", "该指标没有可停止的实时测量")
        }
        activeMetric = null
    }

    private fun startBloodPressureMeasurement(callback: ResultCallback<Unit>) {
        val generation = ++bloodPressureStartGeneration
        pendingBloodPressureStart = callback
        Log.i(
            LOG_TAG,
            "blood pressure protocol=wear_check_then_device_mode",
        )
        bloodPressureWearTimeoutTask?.let(connectionHandler::removeCallbacks)
        val timeout =
            Runnable {
                runCatching { manager.stopDetectHeart { } }
                failPendingBloodPressureStart(
                    generation,
                    "BLOOD_PRESSURE_WEAR_TIMEOUT",
                    "未检测到有效佩戴，请收紧表带并保持静止后重试",
                )
            }
        bloodPressureWearTimeoutTask = timeout
        connectionHandler.postDelayed(timeout, BLOOD_PRESSURE_WEAR_TIMEOUT_MS)
        manager.startDetectHeart(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    connectionHandler.post {
                        failPendingBloodPressureStart(
                            generation,
                            "BLOOD_PRESSURE_WEAR_CHECK_FAILED",
                            "手表未能开始佩戴检测，请稍后重试",
                        )
                    }
                }
            },
            bloodPressureWearListener,
        )
    }

    private fun armMeasurementResultTimeout(metric: String) {
        measurementResultTimeoutTask?.let(connectionHandler::removeCallbacks)
        val timeout =
            Runnable {
                failMeasurement(
                    metric,
                    "${metric.uppercase()}_RESULT_TIMEOUT",
                    "${measurementMetricLabel(metric)}长时间没有返回结果，请确认手表已正确佩戴并退出其他测量后重试",
                )
            }
        measurementResultTimeoutTask = timeout
        connectionHandler.postDelayed(timeout, measurementResultTimeoutFor(metric))
    }

    private fun measurementResultTimeoutFor(metric: String): Long =
        when (metric) {
            "hrv" -> 180_000L
            "ecg", "body_composition", "blood_composition" -> 120_000L
            "blood_pressure" -> 140_000L
            else -> 75_000L
        }

    private fun applyPhotoWatchFaceLayout(
        values: Map<*, *>?,
        callback: ResultCallback<Unit>,
    ) {
        val positions = EWatchUIElementPosition.values()
        val index = (values?.get("timePosition") as? Number)?.toInt()?.coerceIn(0, positions.lastIndex) ?: 0
        val completed = AtomicBoolean(false)
        val timeout =
            Runnable {
                if (completed.compareAndSet(false, true)) {
                    callback.error("PHOTO_LAYOUT_TIMEOUT", "照片已传输，但表盘样式读取超时，请重试")
                }
            }
        fun finish(success: Boolean) {
            if (!completed.compareAndSet(false, true)) return
            connectionHandler.removeCallbacks(timeout)
            if (success) callback.success(Unit)
            else callback.error("PHOTO_LAYOUT_FAILED", "照片已传输，但时间位置保存失败，请重试")
        }
        connectionHandler.postDelayed(timeout, PHOTO_LAYOUT_TIMEOUT_MS)
        manager.readWatchUiInfo(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) finish(false)
            },
            EUIFromType.CUSTOM,
            object : IUIBaseInfoListener<UIDataCustom> {
                override fun onBaseUiInfo(data: UIDataCustom) {
                    connectionHandler.postDelayed(
                        {
                            manager.setCustomWacthUi(
                                IBleWriteResponse { code ->
                                    if (code != Code.REQUEST_SUCCESS) finish(false)
                                },
                                UICustomSetData(
                                    false,
                                    positions[index],
                                    data.upTimeType,
                                    data.downTimeType,
                                    data.color888,
                                ),
                                object : IUIBaseInfoListener<UIDataCustom> {
                                    override fun onBaseUiInfo(updated: UIDataCustom) {
                                        finish(updated.timePosition == positions[index])
                                    }
                                },
                            )
                        },
                        PHOTO_LAYOUT_SETTLE_MS,
                    )
                }
            },
        )
    }

    private val bloodPressureWearListener =
        object : IHeartDataListener {
            override fun onDataChange(data: HeartData) {
                connectionHandler.post {
                    val generation = bloodPressureStartGeneration
                    if (pendingBloodPressureStart == null || activeMetric != "blood_pressure") {
                        return@post
                    }
                    Log.d(
                        LOG_TAG,
                        "blood pressure wear check status=${data.heartStatus} value=${data.data}",
                    )
                    when {
                        data.heartStatus == EHeartStatus.STATE_HEART_NORMAL && data.data in 20..300 -> {
                            bloodPressureWearTimeoutTask?.let(connectionHandler::removeCallbacks)
                            bloodPressureWearTimeoutTask = null
                            manager.stopDetectHeart(
                                IBleWriteResponse { code ->
                                    connectionHandler.post {
                                        if (code == Code.REQUEST_SUCCESS) {
                                            // The SDK does not support overlapping asynchronous operations.
                                            // Let the heart-rate stop settle before starting BP; otherwise
                                            // W9S can accept the write without ever returning BpData.
                                            connectionHandler.postDelayed(
                                                { startBloodPressureProtocol(generation) },
                                                MEASUREMENT_STOP_SETTLE_MS,
                                            )
                                        } else {
                                            failPendingBloodPressureStart(
                                                generation,
                                                "BLOOD_PRESSURE_WEAR_CHECK_FAILED",
                                                "佩戴检测未能结束，请稍后重试",
                                            )
                                        }
                                    }
                                },
                            )
                        }
                        data.heartStatus == EHeartStatus.STATE_HEART_WEAR_ERROR -> {
                            runCatching { manager.stopDetectHeart { } }
                            failPendingBloodPressureStart(
                                generation,
                                "BLOOD_PRESSURE_NOT_WORN",
                                "请正确佩戴手表后重新测量血压",
                            )
                        }
                        data.heartStatus == EHeartStatus.STATE_LOW_BATTERY -> {
                            runCatching { manager.stopDetectHeart { } }
                            failPendingBloodPressureStart(
                                generation,
                                "BLOOD_PRESSURE_LOW_BATTERY",
                                "手表电量过低，充电后再测量血压",
                            )
                        }
                        data.heartStatus == EHeartStatus.STATE_HEART_BUSY -> {
                            runCatching { manager.stopDetectHeart { } }
                            failPendingBloodPressureStart(
                                generation,
                                "BLOOD_PRESSURE_DEVICE_BUSY",
                                "手表正在处理其他任务，请稍后重试",
                            )
                        }
                    }
                }
            }
        }

    private fun startBloodPressureProtocol(generation: Int) {
        if (generation != bloodPressureStartGeneration || pendingBloodPressureStart == null) return
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        Log.i(
            LOG_TAG,
            "blood pressure protocol miniCheckup=${preferences.isSupportMiniCheckup} " +
                "type=${preferences.miniCheckupType}",
        )
        if (preferences.isSupportMiniCheckup) {
            beginMiniCheckupBloodPressureMeasurement(generation)
        } else {
            readBloodPressureMode(generation)
        }
    }

    private fun beginMiniCheckupBloodPressureMeasurement(generation: Int) {
        if (generation != bloodPressureStartGeneration) return
        val callback = pendingBloodPressureStart ?: return
        manager.startMiniCheckup(
            BleWriteResponse { code ->
                connectionHandler.post {
                    if (generation != bloodPressureStartGeneration || pendingBloodPressureStart == null) {
                        return@post
                    }
                    if (code == Code.REQUEST_SUCCESS) {
                        pendingBloodPressureStart = null
                        activeBloodPressureUsesMiniCheckup = true
                        Log.i(LOG_TAG, "blood pressure mini-checkup command accepted")
                        callback.success(Unit)
                    } else {
                        Log.w(
                            LOG_TAG,
                            "blood pressure mini-checkup rejected code=$code; falling back to classic protocol",
                        )
                        activeBloodPressureUsesMiniCheckup = false
                        readBloodPressureMode(generation)
                    }
                }
            },
            miniCheckupBloodPressureListener,
        )
    }

    private fun readBloodPressureMode(generation: Int) {
        if (generation != bloodPressureStartGeneration || pendingBloodPressureStart == null) return
        bloodPressureModeTimeoutTask?.let(connectionHandler::removeCallbacks)
        val timeout =
            Runnable {
                Log.w(LOG_TAG, "blood pressure mode read timed out; using public mode")
                beginBloodPressureMeasurement(
                    generation,
                    EBPDetectModel.DETECT_MODEL_PUBLIC,
                )
            }
        bloodPressureModeTimeoutTask = timeout
        connectionHandler.postDelayed(timeout, BLOOD_PRESSURE_MODE_TIMEOUT_MS)
        manager.readDetectBP(
            IBleWriteResponse { code ->
                if (code != Code.REQUEST_SUCCESS) {
                    connectionHandler.post {
                        Log.w(LOG_TAG, "blood pressure mode read rejected code=$code; using public mode")
                        beginBloodPressureMeasurement(
                            generation,
                            EBPDetectModel.DETECT_MODEL_PUBLIC,
                        )
                    }
                }
            },
            object : IBPSettingDataListener {
                override fun onDataChange(data: BpSettingData) {
                    connectionHandler.post {
                        val mode =
                            if (data.model == EBPDetectModel.DETECT_MODEL_PRIVATE &&
                                data.highPressure in 60..300 &&
                                data.lowPressure in 20..200
                            ) {
                                EBPDetectModel.DETECT_MODEL_PRIVATE
                            } else {
                                EBPDetectModel.DETECT_MODEL_PUBLIC
                            }
                        Log.i(
                            LOG_TAG,
                            "blood pressure mode status=${data.status} reported=${data.model} " +
                                "high=${data.highPressure} low=${data.lowPressure} selected=$mode",
                        )
                        beginBloodPressureMeasurement(generation, mode)
                    }
                }
            },
        )
    }

    private fun beginBloodPressureMeasurement(
        generation: Int,
        mode: EBPDetectModel,
    ) {
        if (generation != bloodPressureStartGeneration) return
        val callback = pendingBloodPressureStart ?: return
        pendingBloodPressureStart = null
        bloodPressureModeTimeoutTask?.let(connectionHandler::removeCallbacks)
        bloodPressureModeTimeoutTask = null
        activeBloodPressureMode = mode
        activeBloodPressureUsesMiniCheckup = false
        manager.startDetectBP(measurementWrite(callback), bloodPressureDataListener, mode)
    }

    private fun cancelPendingBloodPressureStart() {
        bloodPressureStartGeneration += 1
        pendingBloodPressureStart = null
        bloodPressureWearTimeoutTask?.let(connectionHandler::removeCallbacks)
        bloodPressureWearTimeoutTask = null
        bloodPressureModeTimeoutTask?.let(connectionHandler::removeCallbacks)
        bloodPressureModeTimeoutTask = null
    }

    private fun clearMeasurementSessionState() {
        measurementResultTimeoutTask?.let(connectionHandler::removeCallbacks)
        measurementResultTimeoutTask = null
        cancelPendingBloodPressureStart()
        activeMetric = null
        activeHrvUsesEcg = false
        activeHrvUsesMiniCheckup = false
    }

    private fun failPendingBloodPressureStart(
        generation: Int,
        code: String,
        message: String,
    ) {
        if (generation != bloodPressureStartGeneration) return
        val callback = pendingBloodPressureStart ?: return
        pendingBloodPressureStart = null
        bloodPressureWearTimeoutTask?.let(connectionHandler::removeCallbacks)
        bloodPressureWearTimeoutTask = null
        bloodPressureModeTimeoutTask?.let(connectionHandler::removeCallbacks)
        bloodPressureModeTimeoutTask = null
        activeMetric = null
        callback.error(code, message)
    }

    // The vendor demo uses retained anonymous listener instances for manual
    // measurements. Keeping the listeners strongly referenced also avoids the
    // release optimizer turning operation-specific SAM adapters into callback
    // types that the closed-source SDK cannot invoke reliably.
    private val heartDataListener =
        object : IHeartDataListener {
            override fun onDataChange(data: HeartData) = onHeartData(data)
        }

    private val bloodPressureDataListener =
        object : IBPDetectDataListener {
            override fun onDataChange(data: BpData) = onBloodPressureData(data)
        }

    private val miniCheckupBloodPressureListener =
        object : IMiniCheckupOptListener {
            override fun onMiniCheckupTestProgress(progress: Int) {
                Log.d(LOG_TAG, "blood pressure mini-checkup progress=$progress")
            }

            override fun onMiniCheckupStopSuccess() {
                activeBloodPressureUsesMiniCheckup = false
            }

            override fun onMiniCheckupTestFailed(errorCode: EMiniCheckupTestErrorCode) {
                val (code, message) =
                    when (errorCode) {
                        EMiniCheckupTestErrorCode.WEARING_ABNORMALITY ->
                            "BLOOD_PRESSURE_NOT_WORN" to "请正确佩戴手表后重新测量血压"
                        EMiniCheckupTestErrorCode.LOW_POWER ->
                            "BLOOD_PRESSURE_LOW_BATTERY" to "手表电量过低，充电后再测量血压"
                        EMiniCheckupTestErrorCode.DEVICE_BUSY ->
                            "BLOOD_PRESSURE_DEVICE_BUSY" to "手表正在处理其他任务，请稍后重试"
                        EMiniCheckupTestErrorCode.FUNCTION_NOT_SUPPORT ->
                            "BLOOD_PRESSURE_FAILED" to "当前手表暂不支持此测量方式"
                        else ->
                            "BLOOD_PRESSURE_FAILED" to "本次血压测量未完成，请保持静止后重试"
                    }
                failMeasurement("blood_pressure", code, message)
            }

            override fun onMiniCheckupSuccess(data: MiniCheckupResultData) {
                acceptMiniCheckupBloodPressure(
                    data.systolicBloodPressure,
                    data.diastolicBloodPressure,
                )
            }

            override fun onMiniCheckupDetailTestSuccess(data: MiniCheckupDetailData) {
                val photoelectric = data.bpPhotoelectric
                val airPump = data.bpAirPump
                val high =
                    photoelectric?.systolicBloodPressure
                        ?: airPump?.systolicBloodPressure
                        ?: 0
                val low =
                    photoelectric?.diastolicBloodPressure
                        ?: airPump?.diastolicBloodPressure
                        ?: 0
                acceptMiniCheckupBloodPressure(high, low)
            }
        }

    private val miniCheckupHrvListener =
        object : IMiniCheckupOptListener {
            override fun onMiniCheckupTestProgress(progress: Int) {
                val normalized = progress.coerceIn(0, 100)
                Log.d(LOG_TAG, "HRV mini-checkup progress=$normalized")
                emit(
                    "measurementProgress",
                    mapOf(
                        "metric" to "hrv",
                        "progress" to normalized,
                        "deviceState" to "FREE",
                    ),
                )
            }

            override fun onMiniCheckupStopSuccess() {
                activeHrvUsesMiniCheckup = false
            }

            override fun onMiniCheckupTestFailed(errorCode: EMiniCheckupTestErrorCode) {
                activeHrvUsesMiniCheckup = false
                val (code, message) =
                    when (errorCode) {
                        EMiniCheckupTestErrorCode.WEARING_ABNORMALITY ->
                            "HRV_NOT_WORN" to "请将手表贴合手腕并保持静止后重新测量 HRV"
                        EMiniCheckupTestErrorCode.LOW_POWER ->
                            "HRV_LOW_BATTERY" to "手表电量过低，充电后再测量 HRV"
                        EMiniCheckupTestErrorCode.DEVICE_BUSY ->
                            "HRV_DEVICE_BUSY" to "手表正在处理其他任务，请稍后重试"
                        EMiniCheckupTestErrorCode.FUNCTION_NOT_SUPPORT ->
                            "HRV_MEASUREMENT_FAILED" to "当前手表暂不支持 HRV 健康检测"
                        else ->
                            "HRV_MEASUREMENT_FAILED" to "HRV 测量未完成，请正确佩戴并保持静止后重试"
                    }
                failMeasurement("hrv", code, message)
            }

            override fun onMiniCheckupSuccess(data: MiniCheckupResultData) {
                acceptMiniCheckupHrv(data.hrv)
            }

            override fun onMiniCheckupDetailTestSuccess(data: MiniCheckupDetailData) {
                acceptMiniCheckupHrv(data.hrv)
            }
        }

    private fun acceptMiniCheckupHrv(value: Int) {
        Log.i(
            LOG_TAG,
            "measurement callback metric=hrv protocol=mini_checkup value=$value active=$activeMetric",
        )
        if (value in 1..250) {
            if (claimMeasurementResult("hrv")) {
                emitRecord(record("hrv", mapOf("value" to value), "ms", Date()))
            }
        } else if (activeMetric == "hrv") {
            failMeasurement(
                "hrv",
                "HRV_RESULT_EMPTY",
                "本次健康检测未返回有效 HRV 数据，请保持静止后重试",
            )
        }
    }

    private fun acceptMiniCheckupBloodPressure(high: Int, low: Int) {
        Log.i(
            LOG_TAG,
            "measurement callback metric=blood_pressure protocol=mini_checkup high=$high low=$low active=$activeMetric",
        )
        if (high in 60..300 && low in 20..200 && high > low) {
            if (claimMeasurementResult("blood_pressure")) {
                emitRecord(
                    record(
                        "blood_pressure",
                        mapOf("systolic" to high, "diastolic" to low),
                        "mmHg",
                        Date(),
                    ),
                )
            }
        } else {
            failMeasurement(
                "blood_pressure",
                "BLOOD_PRESSURE_INVALID",
                "本次血压结果无效，请保持静止后重试",
            )
        }
    }

    private val oxygenDataListener =
        object : ISpo2hDataListener {
            override fun onSpO2HADataChange(data: Spo2hData) = onOxygenData(data)
        }

    private val temperatureDataListener =
        object : ITemptureDetectDataListener {
            override fun onDataChange(data: TemptureDetectData) = onTemperatureData(data)
        }

    private fun onHeartData(data: HeartData) {
        Log.d(
            LOG_TAG,
            "measurement callback metric=heart_rate status=${data.heartStatus} value=${data.data} active=$activeMetric",
        )
        if (data.heartStatus == EHeartStatus.STATE_HEART_NORMAL &&
            data.data in 20..300 &&
            claimMeasurementResult("heart_rate")
        ) {
            emitRecord(record("heart_rate", mapOf("value" to data.data), "bpm", Date()))
            return
        }
        when (data.heartStatus) {
            EHeartStatus.STATE_HEART_WEAR_ERROR ->
                failMeasurement("heart_rate", "HEART_NOT_WORN", "请正确佩戴手表后重新测量心率")
            EHeartStatus.STATE_HEART_BUSY ->
                failMeasurement("heart_rate", "HEART_DEVICE_BUSY", "手表正在处理其他任务，请稍后重试")
            EHeartStatus.STATE_LOW_BATTERY ->
                failMeasurement("heart_rate", "HEART_LOW_BATTERY", "手表电量过低，充电后再测量")
            else -> Unit
        }
    }

    private fun onBloodPressureData(data: BpData) {
        Log.i(
            LOG_TAG,
            "measurement callback metric=blood_pressure status=${data.status} progress=${data.progress} " +
                "hasProgress=${data.isHaveProgress} " +
                "high=${data.highPressure} low=${data.lowPressure} active=$activeMetric",
        )
        val resultReady = !data.isHaveProgress || data.progress >= 100
        if (data.status == EBPDetectStatus.STATE_BP_NORMAL &&
            resultReady &&
            acceptBloodPressureResult(
                highPressure = data.highPressure,
                lowPressure = data.lowPressure,
                source = "sdk_listener",
            )
        ) {
            return
        }
        if (data.status != EBPDetectStatus.STATE_BP_NORMAL) {
            val message =
                when (data.status) {
                    EBPDetectStatus.STATE_BP_WEAR_OFF -> "请正确佩戴手表后重新测量血压"
                    EBPDetectStatus.STATE_BP_LOW_BATTERY -> "手表电量过低，充电后再测量"
                    EBPDetectStatus.STATE_BP_CHARGING -> "手表充电时无法测量血压"
                    else -> "手表正在处理其他任务，请稍后重试"
                }
            failMeasurement("blood_pressure", "BLOOD_PRESSURE_FAILED", message)
        } else if (resultReady && (data.highPressure > 0 || data.lowPressure > 0)) {
            failMeasurement("blood_pressure", "BLOOD_PRESSURE_INVALID", "本次血压结果无效，请保持静止后重试")
        }
    }

    private fun onRawDeviceCallback(value: ByteArray) {
        // HBand 2.3.77.15 occasionally receives W9S BP notifications without
        // forwarding them to IBPDetectDataListener. The public raw-notify hook
        // runs before the SDK dispatcher, so accept only the documented final
        // BP packet and let claimMeasurementResult prevent duplicate records
        // when the standard listener is also delivered.
        if (value.size < 6 || (value[0].toInt() and 0xFF) != 0x90) return
        val highPressure = value[1].toInt() and 0xFF
        val lowPressure = value[2].toInt() and 0xFF
        val progress = value[3].toInt() and 0xFF
        val status = value[4].toInt() and 0xFF
        val hasProgress = (value[5].toInt() and 0xFF) == 1
        if ((hasProgress && progress < 100) || status != 0) return
        connectionHandler.post {
            acceptBloodPressureResult(
                highPressure = highPressure,
                lowPressure = lowPressure,
                source = "raw_notify_fallback",
            )
        }
    }

    private fun acceptBloodPressureResult(
        highPressure: Int,
        lowPressure: Int,
        source: String,
    ): Boolean {
        if (highPressure !in 60..300 ||
            lowPressure !in 20..200 ||
            highPressure <= lowPressure ||
            !claimMeasurementResult("blood_pressure")
        ) {
            return false
        }
        Log.i(
            LOG_TAG,
            "measurement result accepted metric=blood_pressure source=$source " +
                "high=$highPressure low=$lowPressure",
        )
        emitRecord(
            record(
                "blood_pressure",
                mapOf("systolic" to highPressure, "diastolic" to lowPressure),
                "mmHg",
                Date(),
            ),
        )
        return true
    }

    private fun onOxygenData(data: Spo2hData) {
        Log.d(
            LOG_TAG,
            "measurement callback metric=blood_oxygen state=${data.spState}/${data.deviceState} " +
                "value=${data.value} checking=${data.isChecking}/${data.checkingProgress} active=$activeMetric",
        )
        if (data.spState == ESPO2HStatus.OPEN &&
            data.deviceState == EDeviceStatus.FREE &&
            data.value in 2..100 &&
            (!data.isChecking || data.checkingProgress >= 100) &&
            claimMeasurementResult("blood_oxygen")
        ) {
            emitRecord(record("blood_oxygen", mapOf("value" to data.value), "%", Date()))
            return
        }
        when {
            data.spState == ESPO2HStatus.NOT_SUPPORT ->
                failMeasurement("blood_oxygen", "OXYGEN_UNSUPPORTED", "当前手表不支持血氧测量")
            data.deviceState == EDeviceStatus.UNPASS_WEAR ->
                failMeasurement("blood_oxygen", "OXYGEN_NOT_WORN", "请正确佩戴手表后重新测量血氧")
            data.deviceState in setOf(EDeviceStatus.BUSY, EDeviceStatus.CHARGING, EDeviceStatus.CHARG_LOW) ->
                failMeasurement("blood_oxygen", "OXYGEN_DEVICE_BUSY", "手表当前无法测量血氧，请稍后重试")
        }
    }

    private fun onTemperatureData(data: TemptureDetectData) {
        Log.d(
            LOG_TAG,
            "measurement callback metric=body_temperature operation=${data.oprate} state=${data.deviceState} " +
                "progress=${data.progress} value=${data.tempture} skin=${data.temptureBase} active=$activeMetric",
        )
        if (data.oprate == 1 &&
            data.deviceState in setOf(0, 7) &&
            data.progress >= 100 &&
            data.tempture in 20.0f..45.0f &&
            claimMeasurementResult("body_temperature")
        ) {
            val values = buildMap<String, Number> {
                put("value", data.tempture)
                if (data.temptureBase in 15.0f..45.0f) put("skinTemperature", data.temptureBase)
            }
            emitRecord(record("body_temperature", values, "℃", Date()))
            return
        }
        when {
            data.oprate == 0 ->
                failMeasurement("body_temperature", "TEMPERATURE_UNSUPPORTED", "当前手表不支持体温测量")
            data.deviceState == 8 ->
                failMeasurement("body_temperature", "TEMPERATURE_LOW_BATTERY", "手表电量过低，充电后再测量")
            data.deviceState == 9 ->
                failMeasurement("body_temperature", "TEMPERATURE_SENSOR_ERROR", "体温传感器暂时不可用，请重新佩戴后重试")
            data.deviceState in 1..6 && !temperatureRetryUsed && activeMetric == "body_temperature" -> {
                temperatureRetryUsed = true
                Log.i(LOG_TAG, "temperature device busy; stop stale session and retry once")
                runCatching {
                    manager.stopDetectTempture(
                        IBleWriteResponse { code ->
                            if (code == Code.REQUEST_SUCCESS) {
                                connectionHandler.postDelayed(
                                    {
                                        if (activeMetric == "body_temperature") {
                                            manager.startDetectTempture({ }, temperatureDataListener)
                                        }
                                    },
                                    MEASUREMENT_STOP_SETTLE_MS,
                                )
                            } else {
                                failMeasurement(
                                    "body_temperature",
                                    "TEMPERATURE_DEVICE_BUSY",
                                    "手表仍在处理其他任务，请退出手表其他测量后重试",
                                )
                            }
                        },
                        temperatureDataListener,
                    )
                }.onFailure {
                    failMeasurement(
                        "body_temperature",
                        "TEMPERATURE_DEVICE_BUSY",
                        "手表仍在处理其他任务，请退出手表其他测量后重试",
                    )
                }
            }
            data.deviceState in 1..6 ->
                failMeasurement("body_temperature", "TEMPERATURE_DEVICE_BUSY", "手表仍在处理其他任务，请退出手表其他测量后重试")
        }
    }

    private val bloodGlucoseListener =
        object : IBloodGlucoseChangeListener {
            override fun onDetectError(progress: Int, status: EBloodGlucoseStatus) {
                val (code, message) =
                    when (status) {
                        EBloodGlucoseStatus.WEARING_ERROR ->
                            "GLUCOSE_NOT_WORN" to "未检测到正确佩戴，请将手表贴合手腕后重新测量血糖"
                        EBloodGlucoseStatus.LOW_POWER ->
                            "GLUCOSE_LOW_BATTERY" to "手表电量过低，充电后再测量血糖"
                        EBloodGlucoseStatus.BUSY ->
                            "GLUCOSE_DEVICE_BUSY" to "手表正在处理其他任务，请稍后再测量血糖"
                        EBloodGlucoseStatus.NONSUPPORT ->
                            "UNSUPPORTED_METRIC" to "当前手表不支持手动测量血糖"
                        else ->
                            "GLUCOSE_MEASUREMENT_FAILED" to "血糖测量未完成，请保持正确佩戴后重试"
                    }
                failMeasurement("blood_glucose", code, message)
            }

            override fun onBloodGlucoseDetect(progress: Int, value: Float, risk: EBloodGlucoseRiskLevel) {
                emit(
                    "measurementProgress",
                    mapOf(
                        "metric" to "blood_glucose",
                        "progress" to progress.coerceIn(0, 100),
                        "deviceState" to "FREE",
                    ),
                )
                if (progress >= 100 && value > 0 && claimMeasurementResult("blood_glucose")) {
                    emitRecord(
                        record(
                            "blood_glucose",
                            mapOf("value" to value, "risk" to risk.value),
                            "mmol/L",
                            Date(),
                        ),
                    )
                }
            }

            override fun onBloodGlucoseStopDetect() = Unit
            override fun onBloodGlucoseAdjustingSettingSuccess(open: Boolean, value: Float) {
                completeGlucoseCalibration(true)
            }
            override fun onBloodGlucoseAdjustingSettingFailed() {
                completeGlucoseCalibration(false)
            }
            override fun onBloodGlucoseAdjustingReadSuccess(open: Boolean, value: Float) = Unit
            override fun onBloodGlucoseAdjustingReadFailed() = Unit
            override fun onBGMultipleAdjustingReadSuccess(
                open: Boolean,
                first: com.veepoo.protocol.model.datas.MealInfo,
                second: com.veepoo.protocol.model.datas.MealInfo,
                third: com.veepoo.protocol.model.datas.MealInfo,
            ) = Unit

            override fun onBGMultipleAdjustingReadFailed() = Unit
            override fun onBGMultipleAdjustingSettingSuccess() = Unit
            override fun onBGMultipleAdjustingSettingFailed() = Unit
        }

    private val bodyComponentListener =
        object : IBodyComponentDetectListener {
            override fun onDetecting(progress: Int, lead: Int) {
                emit(
                    "measurementProgress",
                    mapOf(
                        "metric" to "body_composition",
                        "progress" to progress.coerceIn(0, 100),
                        "deviceState" to if (lead == 0) "FREE" else "UNPASS_WEAR",
                    ),
                )
            }

            override fun onDetectSuccess(data: BodyComponent) {
                val values = bodyComponentValues(data)
                if (values.isNotEmpty() && claimMeasurementResult("body_composition")) {
                    emitRecord(record("body_composition", values, "", Date()))
                }
            }

            override fun onDetectFailed(state: DetectState) {
                val (code, message) =
                    when (state) {
                        DetectState.BUSY ->
                            "BODY_COMPOSITION_BUSY" to "手表正在处理其他任务，请稍后重试"
                        DetectState.LOW_POWER ->
                            "BODY_COMPOSITION_LOW_BATTERY" to "手表电量过低，充电后再测量身体成分"
                        else ->
                            "BODY_COMPOSITION_NOT_WORN" to "请正确佩戴手表并保持电极接触后重新测量身体成分"
                    }
                failMeasurement("body_composition", code, message)
            }

            override fun onDetectStop() = Unit
        }

    private val bloodComponentListener =
        object : IBloodComponentDetectListener {
            override fun onDetectFailed(state: EBloodComponentDetectState) {
                val (code, message) =
                    when (state) {
                        EBloodComponentDetectState.WEAR_ERROR ->
                            "BLOOD_COMPONENT_NOT_WORN" to "请正确佩戴手表并保持电极接触后重新测量血液成分"
                        EBloodComponentDetectState.BUSY,
                        EBloodComponentDetectState.DETECTING,
                        -> "BLOOD_COMPONENT_BUSY" to "手表正在处理其他任务，请稍后重试"
                        EBloodComponentDetectState.LOW_POWER ->
                            "BLOOD_COMPONENT_LOW_BATTERY" to "手表电量过低，充电后再测量血液成分"
                        else ->
                            "BLOOD_COMPONENT_FAILED" to "血液成分测量未完成，请保持正确佩戴后重试"
                    }
                failMeasurement("blood_composition", code, message)
            }

            override fun onDetecting(progress: Int, data: BloodComponent) {
                emit(
                    "measurementProgress",
                    mapOf(
                        "metric" to "blood_composition",
                        "progress" to progress.coerceIn(0, 100),
                    ),
                )
                if (progress >= 100) {
                    if (!completeBloodComponentMeasurement(data)) {
                        connectionHandler.postDelayed(
                            {
                                if (activeMetric == "blood_composition") {
                                    failMeasurement(
                                        "blood_composition",
                                        "BLOOD_COMPONENT_EMPTY_RESULT",
                                        "血液成分测量完成但未返回有效数据，请保持正确佩戴后重试",
                                    )
                                }
                            },
                            1_500L,
                        )
                    }
                }
            }
            override fun onDetectStop() = Unit

            override fun onDetectComplete(data: BloodComponent) {
                completeBloodComponentMeasurement(data)
            }
        }

    private fun completeBloodComponentMeasurement(data: BloodComponent): Boolean {
        val values = bloodComponentValues(data)
        if (values.isEmpty() || !claimMeasurementResult("blood_composition")) return false
        emitRecord(record("blood_composition", values, "", Date()))
        return true
    }

    private val activeEcgSamples = mutableListOf<Number>()
    private val pendingEcgRawSamples = mutableListOf<Int>()
    private val pendingEcgPowerSamples = mutableListOf<Int>()

    private fun resetEcgMeasurementStream() {
        synchronized(activeEcgSamples) { activeEcgSamples.clear() }
        synchronized(pendingEcgRawSamples) {
            pendingEcgRawSamples.clear()
            pendingEcgPowerSamples.clear()
        }
        ecgSampleFrequency = DEFAULT_ECG_SAMPLE_FREQUENCY
        activeEcgType = storedEcgType()
        latestEcgHeartRate = 0
        latestEcgHrv = 0
        lastEcgAdcLogAt = 0L
        lastEcgStateLogAt = 0L
    }

    private fun storedEcgType(): Int =
        runCatching {
            VpSpGetUtil.getVpSpVariInstance(appContext).getECGType()
        }.getOrDefault(0).takeIf { it in 1..14 } ?: 0

    private fun bufferPendingEcgSamples(data: IntArray, power: IntArray) {
        synchronized(pendingEcgRawSamples) {
            data.forEachIndexed { index, sample ->
                pendingEcgRawSamples += sample
                pendingEcgPowerSamples +=
                    power.getOrNull(index)?.takeIf { it > 0 } ?: DEFAULT_ECG_POWER
            }
            val maximumPending =
                (ecgSampleFrequency.coerceIn(50, 1000) * ECG_PENDING_SECONDS).coerceAtLeast(500)
            val excess = pendingEcgRawSamples.size - maximumPending
            if (excess > 0) {
                pendingEcgRawSamples.subList(0, excess).clear()
                pendingEcgPowerSamples.subList(0, excess).clear()
            }
        }
    }

    private fun flushPendingEcgSamples() {
        if (activeEcgType !in 1..14) return
        val pending =
            synchronized(pendingEcgRawSamples) {
                if (pendingEcgRawSamples.isEmpty()) {
                    null
                } else {
                    Pair(
                        pendingEcgRawSamples.toList(),
                        pendingEcgPowerSamples.toIntArray(),
                    ).also {
                        pendingEcgRawSamples.clear()
                        pendingEcgPowerSamples.clear()
                    }
                }
            } ?: return
        publishEcgSamples(
            calibrateEcgSamples(
                pending.first,
                pending.second,
                ecgTypeOverride = activeEcgType,
            ),
        )
    }

    private fun publishEcgSamples(
        calibrated: List<Number>,
        emitLive: Boolean = true,
    ) {
        if (calibrated.isEmpty()) return
        synchronized(activeEcgSamples) { activeEcgSamples += calibrated }
        if (!emitLive) return
        emit(
            "measurementProgress",
            mapOf(
                "metric" to (activeMetric ?: "ecg"),
                // Match the official HBand demo: forward every ADC point in
                // callback order so the Flutter trace retains its time axis.
                "samples" to calibrated,
            ),
        )
    }

    private val ecgListener =
        object : IECGDetectListener {
            override fun onEcgDetectInfoChange(info: EcgDetectInfo) {
                ecgSampleFrequency = info.frequency.takeIf { it in 50..1000 } ?: DEFAULT_ECG_SAMPLE_FREQUENCY
                if (activeEcgType !in 1..14) activeEcgType = storedEcgType()
                flushPendingEcgSamples()
                Log.i(
                    LOG_TAG,
                    "ecg info frequency=${info.frequency} draw=${info.drawFrequency} type=$activeEcgType",
                )
                emit(
                    "measurementProgress",
                    mapOf(
                        "metric" to (activeMetric ?: "ecg"),
                        "frequency" to info.frequency,
                        "drawFrequency" to info.drawFrequency,
                    ),
                )
            }

            override fun onEcgDetectStateChange(state: EcgDetectState) {
                val metric = activeMetric ?: return
                val now = System.currentTimeMillis()
                if (now - lastEcgStateLogAt >= 1_000L) {
                    lastEcgStateLogAt = now
                    Log.d(
                        LOG_TAG,
                        "ecg state measureType=${state.ecgType} hardwareType=$activeEcgType progress=${state.progress} wear=${state.wear} device=${state.deviceState.name} heart=${state.hr2} hrv=${state.hrv}",
                    )
                }
                if (state.hr2 in 30..210) latestEcgHeartRate = state.hr2
                if (state.hrv in 1..250) latestEcgHrv = state.hrv
                emit(
                    "measurementProgress",
                    mapOf(
                        "metric" to metric,
                        "progress" to state.progress.coerceIn(0, 100),
                        "wear" to state.wear,
                        "deviceState" to state.deviceState.name,
                        "heartRate" to state.hr2,
                        "hrv" to state.hrv,
                    ),
                )
                if (state.deviceState == EDeviceStatus.UNPASS_WEAR || state.wear == 1) {
                    failMeasurement(
                        metric,
                        "ECG_NOT_WORN",
                        "请正确佩戴手表，并将手指持续贴在心电电极上",
                    )
                } else if (state.progress >= 100) {
                    deferEcgCompletion(metric)
                }
            }

            override fun onEcgDetectResultChange(result: EcgDetectResult) {
                Log.d(
                    LOG_TAG,
                    "ecg result callback success=${result.isSuccess} heart=${result.aveHeart} hrv=${result.aveHrv} qt=${result.aveQT}",
                )
                val metric = activeMetric ?: "ecg"
                val values = buildMap<String, Number> {
                    if (result.aveHeart in 30..210) put("meanHeartRate", result.aveHeart)
                    if (result.aveHrv in 1..250) put("averageHRV", result.aveHrv)
                    if (result.aveQT > 0) put("averageTimeInterval", result.aveQT)
                    if (result.aveResRate > 0) put("respiratoryRate", result.aveResRate)
                    put("sampleFrequency", result.frequency.takeIf { it > 0 } ?: ecgSampleFrequency)
                    if (result.isSuccess) {
                        val abnormalCount = result.diseaseResult?.count { it != 0 } ?: 0
                        if (abnormalCount > 0) put("deviceAbnormalFlags", abnormalCount)
                    }
                }
                val resultValues =
                    if (metric == "hrv") {
                        result.aveHrv.takeIf { it in 1..250 }?.let { mapOf("value" to it) }.orEmpty()
                    } else {
                        values
                    }
                if (metric == "ecg") {
                    result.aveHeart.takeIf { it in 30..210 }?.let { latestEcgHeartRate = it }
                    result.aveHrv.takeIf { it in 1..250 }?.let { latestEcgHrv = it }
                    // The result callback can arrive before the SDK's diagnosis
                    // callback. Do not persist it first, otherwise the diagnosis
                    // callback loses the claim and the risk fields are discarded.
                    if (result.isSuccess) {
                        deferEcgCompletion(metric)
                    } else {
                        deferEcgFailure(metric)
                    }
                    return
                }
                val hasUsablePrimary = metric == "hrv" || resultValues.containsKey("meanHeartRate")
                if (resultValues.isEmpty() || !hasUsablePrimary) {
                    if (!result.isSuccess) deferEcgFailure(metric)
                    return
                }
                if (!result.isSuccess) {
                    Log.w(
                        LOG_TAG,
                        "ecg result flagged incomplete but contains usable metrics; preserving trend data metric=$metric",
                    )
                }
                val samples =
                    if (metric == "ecg") {
                        selectEcgSamples(
                            result.filterSignals?.toList().orEmpty(),
                            result.powers,
                        )
                    } else {
                        emptyList()
                    }
                if (metric == "ecg" && samples.isEmpty()) {
                    deferEcgFailure(metric)
                    return
                }
                if (resultValues.isNotEmpty() && hasUsablePrimary && claimMeasurementResult(metric)) {
                    emitRecord(
                        record(
                            metric,
                            resultValues,
                            if (metric == "hrv") "ms" else "",
                            Date(),
                            if (metric == "ecg") samples else emptyList(),
                            rawVersion = if (metric == "ecg") ECG_CALIBRATED_RAW_VERSION else 1,
                        ),
                    )
                }
            }

            override fun onEcgDetectDiagnosisChange(diagnosis: EcgDiagnosis) {
                Log.d(
                    LOG_TAG,
                    "ecg diagnosis callback success=${diagnosis.isSuccess} heart=${diagnosis.heartRate} hrv=${diagnosis.hrv} qt=${diagnosis.qtTime}",
                )
                val metric = activeMetric ?: "ecg"
                val hasReturnedRiskValues =
                    listOf(
                        diagnosis.diseaseRisk,
                        diagnosis.pressureIndex,
                        diagnosis.fatigueIndex,
                        diagnosis.myocarditisRisk,
                        diagnosis.chdRisk,
                        diagnosis.angioscleroticRisk,
                    ).any { it > 0 } ||
                        diagnosis.risk32?.any { it != 0 } == true ||
                        diagnosis.diagnosis8?.any { it != 0 } == true ||
                        diagnosis.diseaseResult?.any { it != 0 } == true
                // A successful diagnosis callback is itself the SDK's
                // authoritative indication that the risk result is present.
                // Zero is a valid low-risk value and must not be treated as a
                // missing field.
                val hasRiskAnalysis = diagnosis.isSuccess || hasReturnedRiskValues
                val values = buildMap<String, Number> {
                    if (diagnosis.heartRate in 30..210) put("meanHeartRate", diagnosis.heartRate)
                    if (diagnosis.hrv in 1..250) put("averageHRV", diagnosis.hrv)
                    if (diagnosis.qtTime > 0) put("averageTimeInterval", diagnosis.qtTime)
                    if (diagnosis.respRate > 0) put("respiratoryRate", diagnosis.respRate)
                    if (hasRiskAnalysis) {
                        put("riskAnalysisAvailable", 1)
                        if (diagnosis.diseaseRisk >= 0) put("diseaseRisk", diagnosis.diseaseRisk)
                        if (diagnosis.pressureIndex >= 0) put("pressureIndex", diagnosis.pressureIndex)
                        if (diagnosis.fatigueIndex >= 0) put("fatigueIndex", diagnosis.fatigueIndex)
                        if (diagnosis.myocarditisRisk >= 0) put("myocarditisRisk", diagnosis.myocarditisRisk)
                        if (diagnosis.chdRisk >= 0) put("chdRisk", diagnosis.chdRisk)
                        if (diagnosis.angioscleroticRisk >= 0) {
                            put("angioscleroticRisk", diagnosis.angioscleroticRisk)
                        }
                        if (diagnosis.qrsTime > 0) put("qrsTime", diagnosis.qrsTime)
                        if (diagnosis.qrsAmp > 0) put("qrsAmplitude", diagnosis.qrsAmp)
                        if (diagnosis.pwvMeanVal > 0) put("pulseWaveVelocity", diagnosis.pwvMeanVal)
                        if (diagnosis.stMeanAmp != 0) put("stAmplitude", diagnosis.stMeanAmp)
                        if (diagnosis.diseaseSdnn > 0) put("sdnn", diagnosis.diseaseSdnn)
                        if (diagnosis.diseaseRmssd > 0) put("rmssd", diagnosis.diseaseRmssd)
                        val abnormalCount = diagnosis.diseaseResult?.count { it != 0 } ?: 0
                        put("deviceAbnormalFlags", abnormalCount)
                    }
                    put("sampleFrequency", diagnosis.frequency.takeIf { it > 0 } ?: ecgSampleFrequency)
                }
                val resultValues =
                    if (metric == "hrv") {
                        diagnosis.hrv.takeIf { it in 1..250 }?.let { mapOf("value" to it) }.orEmpty()
                    } else {
                        values
                    }
                if (metric == "ecg" && !hasRiskAnalysis) {
                    diagnosis.heartRate.takeIf { it in 30..210 }?.let { latestEcgHeartRate = it }
                    diagnosis.hrv.takeIf { it in 1..250 }?.let { latestEcgHrv = it }
                    // The SDK did not provide a successful diagnosis callback.
                    // Preserve the trace without inventing risk values.
                    if (diagnosis.isSuccess) {
                        deferEcgCompletion(metric)
                    } else {
                        deferEcgFailure(metric)
                    }
                    return
                }
                val hasUsablePrimary = metric == "hrv" || resultValues.containsKey("meanHeartRate")
                if (resultValues.isEmpty() || !hasUsablePrimary) {
                    if (!diagnosis.isSuccess) deferEcgFailure(metric)
                    return
                }
                if (!diagnosis.isSuccess) {
                    Log.w(
                        LOG_TAG,
                        "ecg diagnosis flagged incomplete but contains usable metrics; preserving trend data metric=$metric",
                    )
                }
                val samples =
                    if (metric == "ecg") {
                        selectEcgSamples(
                            diagnosis.filterSignals?.toList().orEmpty(),
                            diagnosis.powers,
                        )
                    } else {
                        emptyList()
                    }
                if (metric == "ecg" && samples.isEmpty()) {
                    deferEcgFailure(metric)
                    return
                }
                if (resultValues.isNotEmpty() && hasUsablePrimary && claimMeasurementResult(metric)) {
                    emitRecord(
                        record(
                            metric,
                            resultValues,
                            if (metric == "hrv") "ms" else "",
                            Date(),
                            if (metric == "ecg") samples else emptyList(),
                            rawVersion = if (metric == "ecg") ECG_CALIBRATED_RAW_VERSION else 1,
                        ),
                    )
                }
            }

            override fun onEcgADCChange(data: IntArray, power: IntArray) {
                if (activeEcgType !in 1..14) activeEcgType = storedEcgType()
                if (activeEcgType !in 1..14) {
                    bufferPendingEcgSamples(data, power)
                    val now = System.currentTimeMillis()
                    if (now - lastEcgAdcLogAt >= 1_000L) {
                        lastEcgAdcLogAt = now
                        Log.w(
                            LOG_TAG,
                            "ecg adc waiting for valid type raw=${data.size} pending=${pendingEcgRawSamples.size}",
                        )
                    }
                    return
                }
                flushPendingEcgSamples()
                val validRaw = data.filter { it != Int.MAX_VALUE }
                val hasWaveformData = validRaw.any { it != 0 }
                val calibrated =
                    calibrateEcgSamples(
                        data.toList(),
                        power,
                        ecgTypeOverride = activeEcgType,
                    )
                val now = System.currentTimeMillis()
                if (now - lastEcgAdcLogAt >= 1_000L) {
                    lastEcgAdcLogAt = now
                    val rawMinimum = validRaw.minOrNull()
                    val rawMaximum = validRaw.maxOrNull()
                    val powerMinimum = power.minOrNull()
                    val powerMaximum = power.maxOrNull()
                    val minimum = calibrated.minOfOrNull { it.toDouble() }
                    val maximum = calibrated.maxOfOrNull { it.toDouble() }
                    Log.d(
                        LOG_TAG,
                        "ecg adc type=$activeEcgType raw=${data.size}/${validRaw.size}/$rawMinimum..$rawMaximum power=${power.size}/$powerMinimum..$powerMaximum calibrated=${calibrated.size}/$minimum..$maximum",
                    )
                }
                // HBand documents that callbacks without reasonable waveform
                // data must not be drawn. Some W9S firmware represents that
                // state as a full zero packet instead of an empty array. Keep
                // those samples in the quality buffer, but do not let them
                // repeatedly replace the last genuine live trace on screen.
                publishEcgSamples(calibrated, emitLive = hasWaveformData)
            }
        }

    private val hrvListener =
        object : IHrvDetectListener {
            override fun onHrvDetect(hrv: Int) {
                if (hrv > 0 && claimMeasurementResult("hrv")) {
                    emitRecord(record("hrv", mapOf("value" to hrv), "ms", Date()))
                }
            }

            override fun onDetectFailed(state: HrvDetectState) {
                val (code, message) =
                    when (state) {
                        HrvDetectState.WEAR_OFF ->
                            "HRV_NOT_WORN" to "请将手表贴合手腕并保持静止后重新测量 HRV"
                        HrvDetectState.BUSY ->
                            "HRV_DEVICE_BUSY" to "手表正在处理其他任务，请稍后重试"
                        HrvDetectState.LOW_POWER ->
                            "HRV_LOW_BATTERY" to "手表电量过低，充电后再测量 HRV"
                        else ->
                            "HRV_MEASUREMENT_FAILED" to "HRV 测量未完成，请保持正确佩戴后重试"
                    }
                failMeasurement("hrv", code, message)
            }

            override fun onDetectStop() = Unit
        }

    private fun claimMeasurementResult(metric: String): Boolean =
        synchronized(this) {
            if (activeMetric != metric) {
                Log.w(LOG_TAG, "measurement result ignored metric=$metric active=$activeMetric")
                false
            } else {
                activeMetric = null
                measurementResultTimeoutTask?.let(connectionHandler::removeCallbacks)
                measurementResultTimeoutTask = null
                Log.i(LOG_TAG, "measurement result accepted metric=$metric")
                true
            }
        }

    private fun selectEcgSamples(
        filteredSamples: List<Number>,
        filteredPowers: IntArray? = null,
    ): List<Number> {
        val live =
            synchronized(activeEcgSamples) {
                activeEcgSamples.toList()
            }.filter { it.toLong() != Int.MAX_VALUE.toLong() }
        val liveCoverage = ecgSampleChangeRatio(live)
        val liveRejection = ecgTraceRejectionReason(live)
        if (liveRejection == null) {
            Log.i(
                LOG_TAG,
                "ecg samples live=${live.size}/$liveCoverage selected=live",
            )
            return live
        }
        val liveTail = longestUsableEcgTail(live)
        if (liveTail.isNotEmpty()) {
            Log.i(
                LOG_TAG,
                "ecg samples live=${live.size}/$liveCoverage full=$liveRejection selected=live_tail/${liveTail.size}",
            )
            return liveTail
        }
        val filtered = calibrateEcgSamples(filteredSamples, filteredPowers)
        val filteredCoverage = ecgSampleChangeRatio(filtered)
        val minimumFilteredSamples = (ecgSampleFrequency.coerceIn(50, 1000) / 2).coerceAtLeast(16)
        val filteredRejection = ecgTraceRejectionReason(filtered)
        if (filtered.size >= minimumFilteredSamples && filteredRejection == null) {
            Log.i(
                LOG_TAG,
                "ecg samples live=${live.size}/$liveCoverage filtered=${filtered.size}/$filteredCoverage selected=filtered",
            )
            return filtered
        }
        Log.i(
            LOG_TAG,
            "ecg samples filtered=${filtered.size}/$filteredCoverage/$filteredRejection live=${live.size}/$liveCoverage/$liveRejection selected=none",
        )
        return emptyList()
    }

    private fun longestUsableEcgTail(samples: List<Number>): List<Number> {
        val frequency = ecgSampleFrequency.coerceIn(50, 1000)
        val minimumTailSamples = frequency * ECG_MIN_USABLE_TAIL_SECONDS
        if (samples.size < minimumTailSamples) return emptyList()
        var tailSamples = minOf(samples.size, frequency * ECG_MAX_USABLE_TAIL_SECONDS)
        while (tailSamples >= minimumTailSamples) {
            val candidate = samples.subList(samples.size - tailSamples, samples.size)
            if (ecgTraceRejectionReason(candidate) == null) return candidate.toList()
            tailSamples -= frequency
        }
        return emptyList()
    }

    private fun isUsableEcgTrace(samples: List<Number>): Boolean =
        ecgTraceRejectionReason(samples) == null

    private fun ecgTraceRejectionReason(samples: List<Number>): String? {
        val frequency = ecgSampleFrequency.coerceIn(50, 1000)
        val minimumSamples = frequency.coerceAtLeast(16)
        if (samples.size < minimumSamples) return "too_short"
        val values = samples.map { it.toDouble() }.filter { it.isFinite() }
        if (values.size < minimumSamples) return "non_finite"
        val sorted = values.sorted()
        val middle = sorted.size / 2
        val baseline =
            if (sorted.size % 2 == 0) {
                (sorted[middle - 1] + sorted[middle]) / 2.0
            } else {
                sorted[middle]
            }
        val valid = values.filter { kotlin.math.abs(it - baseline) <= ECG_MAX_DISPLAY_DEVIATION_MV }
        val validRatio = valid.size.toDouble() / values.size
        if (validRatio < ECG_MIN_VALID_SAMPLE_RATIO) return "contact_rails"
        if (ecgSampleChangeRatio(valid) < ECG_MIN_SAMPLE_CHANGE_RATIO) return "flat"
        if (hasRepeatedIsolatedEcgResets(valid)) return "converter_resets"
        if (hasLongEcgRamp(valid, frequency)) return "long_ramp"
        val validSorted = valid.sorted()
        val lower = validSorted[(validSorted.lastIndex * 0.05).toInt()]
        val upper = validSorted[(validSorted.lastIndex * 0.95).toInt()]
        return if (upper - lower >= ECG_MIN_CENTRAL_SPAN_MV) null else "low_span"
    }

    private fun hasRepeatedIsolatedEcgResets(values: List<Double>): Boolean {
        var isolatedResets = 0
        for (index in 1 until values.lastIndex) {
            val previous = values[index - 1]
            val current = values[index]
            val next = values[index + 1]
            if (
                kotlin.math.abs(current - previous) > 2.0 &&
                    kotlin.math.abs(next - current) > 2.0 &&
                    kotlin.math.abs(next - previous) <= 0.3
            ) {
                isolatedResets += 1
                if (isolatedResets >= 2) return true
            }
        }
        return false
    }

    private fun hasLongEcgRamp(values: List<Double>, sampleFrequency: Int): Boolean {
        if (values.size < 32) return false
        val blockSize = (sampleFrequency.coerceIn(50, 1000) / 50).coerceAtLeast(1)
        val blocks = mutableListOf<Double>()
        var start = 0
        while (start < values.size) {
            val end = (start + blockSize).coerceAtMost(values.size)
            var total = 0.0
            for (index in start until end) total += values[index]
            blocks += total / (end - start)
            start = end
        }
        if (blocks.size < 3) return false
        val sorted = blocks.sorted()
        val lower = sorted[(sorted.lastIndex * 0.05).toInt()]
        val upper = sorted[(sorted.lastIndex * 0.95).toInt()]
        val centralSpan = upper - lower
        if (centralSpan <= 0) return false
        val minimumDelta = maxOf(0.002, centralSpan * 0.002)
        val maximumRampDelta = maxOf(0.15, centralSpan * 0.15)
        val minimumSwing = maxOf(0.8, centralSpan * 0.35)
        val minimumRampBlocks = 18
        var direction = 0
        var runBlocks = 0
        var runStart = blocks.first()
        for (index in 1 until blocks.size) {
            val delta = blocks[index] - blocks[index - 1]
            if (kotlin.math.abs(delta) > maximumRampDelta) {
                direction = 0
                runBlocks = 0
                runStart = blocks[index]
                continue
            }
            val nextDirection = if (kotlin.math.abs(delta) < minimumDelta) 0 else if (delta > 0) 1 else -1
            if (nextDirection == 0) {
                direction = 0
                runBlocks = 0
                runStart = blocks[index]
                continue
            }
            if (nextDirection != direction) {
                direction = nextDirection
                runBlocks = 1
                runStart = blocks[index - 1]
            } else {
                runBlocks += 1
            }
            if (
                runBlocks >= minimumRampBlocks &&
                    kotlin.math.abs(blocks[index] - runStart) >= minimumSwing
            ) {
                return true
            }
        }
        return false
    }

    private fun calibrateEcgSamples(
        rawSamples: List<Number>,
        powers: IntArray? = null,
        ecgTypeOverride: Int? = null,
    ): List<Number> {
        val ecgType = ecgTypeOverride?.takeIf { it in 1..14 } ?: storedEcgType()
        if (ecgType !in 1..14) return emptyList()
        return rawSamples.mapIndexedNotNull { index, sample ->
            if (sample.toLong() == Int.MAX_VALUE.toLong()) return@mapIndexedNotNull null
            val power = powers?.getOrNull(index)?.takeIf { it > 0 } ?: DEFAULT_ECG_POWER
            runCatching {
                EcgUtil.convertToMvWithValue(sample.toInt(), ecgType, false, power)
                    .takeIf { it.isFinite() }
                    ?.toDouble()
            }.getOrNull()
        }
    }

    private fun ecgSampleChangeRatio(samples: List<Number>): Double {
        if (samples.size < 2) return 0.0
        var changedSamples = 0
        var previous = samples.first().toDouble()
        for (index in 1 until samples.size) {
            val current = samples[index].toDouble()
            if (current != previous) changedSamples += 1
            previous = current
        }
        return changedSamples.toDouble() / (samples.size - 1)
    }

    private fun failMeasurement(
        metric: String,
        code: String,
        message: String,
    ) {
        if (claimMeasurementResult(metric)) {
            stopFailedMeasurement(metric)
            emit("error", mapOf("code" to code, "message" to message))
        }
    }

    private fun deferEcgFailure(metric: String) {
        deferEcgCompletion(metric)
    }

    private fun deferEcgCompletion(metric: String) {
        connectionHandler.postDelayed(
            {
                if (activeMetric == metric) {
                    val values =
                        if (metric == "hrv") {
                            latestEcgHrv.takeIf { it in 1..250 }?.let { mapOf("value" to it) }.orEmpty()
                        } else {
                            buildMap<String, Number> {
                                if (latestEcgHeartRate in 30..210) put("meanHeartRate", latestEcgHeartRate)
                                if (latestEcgHrv in 1..250) put("averageHRV", latestEcgHrv)
                                put("sampleFrequency", ecgSampleFrequency)
                            }
                        }
                    val hasUsablePrimary = metric == "hrv" || values.containsKey("meanHeartRate")
                    val samples =
                        if (metric == "ecg") selectEcgSamples(emptyList()) else emptyList()
                    val hasUsableWaveform = metric != "ecg" || samples.isNotEmpty()
                    if (values.isNotEmpty() &&
                        hasUsablePrimary &&
                        hasUsableWaveform &&
                        claimMeasurementResult(metric)
                    ) {
                        emitRecord(
                            record(
                                metric,
                                values,
                                if (metric == "hrv") "ms" else "",
                                Date(),
                                samples,
                                rawVersion = if (metric == "ecg") ECG_CALIBRATED_RAW_VERSION else 1,
                            ),
                        )
                    } else if (activeMetric == metric) {
                        val hrv = metric == "hrv"
                        failMeasurement(
                            metric,
                            if (hrv) "HRV_MEASUREMENT_FAILED" else "ECG_MEASUREMENT_FAILED",
                            if (hrv) {
                                "HRV 测量未完成，请保持手表贴合并持续接触电极后重试"
                            } else {
                                "心电测量未完成，请保持接触电极后重试"
                            },
                        )
                    }
                }
            },
            ECG_RESULT_SETTLE_MS,
        )
    }

    private fun stopFailedMeasurement(metric: String) {
        val ignored = IBleWriteResponse { }
        runCatching {
            when (metric) {
                "heart_rate" -> manager.stopDetectHeart(ignored)
                "blood_pressure" -> {
                    if (activeBloodPressureUsesMiniCheckup) {
                        manager.stopMiniCheckup(BleWriteResponse { }, miniCheckupBloodPressureListener)
                        activeBloodPressureUsesMiniCheckup = false
                    } else {
                        manager.stopDetectBP(ignored, activeBloodPressureMode)
                    }
                }
                "blood_oxygen" -> manager.stopDetectSPO2H(ignored, ISpo2hDataListener { })
                "body_temperature" -> manager.stopDetectTempture(ignored, ITemptureDetectDataListener { })
                "blood_glucose" -> manager.stopBloodGlucoseDetect(ignored, bloodGlucoseListener)
                "body_composition" -> manager.stopDetectBodyComponent(ignored)
                "blood_composition" -> manager.stopDetectBloodComponent(ignored)
                "ecg" -> manager.stopDetectECG(ignored, true, ecgListener)
                "hrv" -> {
                    if (activeHrvUsesMiniCheckup) {
                        manager.stopMiniCheckup(BleWriteResponse { }, miniCheckupHrvListener)
                    } else if (activeHrvUsesEcg) {
                        manager.stopDetectECG(ignored, true, ecgListener)
                    } else {
                        manager.stopDetectHrv(ignored, hrvListener)
                    }
                    activeHrvUsesEcg = false
                    activeHrvUsesMiniCheckup = false
                }
            }
        }.onFailure { error ->
            Log.w(LOG_TAG, "Failed to stop $metric after terminal measurement error", error)
        }
    }

    private fun bodyComponentValues(data: BodyComponent): Map<String, Number> =
        buildMap {
            fun putRange(key: String, value: Float, min: Float, max: Float) {
                if (value.isFinite() && value in min..max) put(key, value)
            }
            putRange("bmi", data.BMI, 5f, 80f)
            putRange("bodyFatRate", data.bodyFatRate, 2f, 48f)
            putRange("fatMass", data.fatRate, 1f, 248f)
            putRange("fatFreeMass", data.FFM, 1f, 248f)
            putRange("muscleRate", data.muscleRate, 1f, 100f)
            putRange("muscleMass", data.muscleMass, 1f, 248f)
            putRange("subcutaneousFat", data.subcutaneousFat, 1f, 100f)
            putRange("bodyWaterRate", data.bodyWater, 10f, 90f)
            putRange("waterMass", data.waterContent, 1f, 248f)
            putRange("skeletalMuscleRate", data.skeletalMuscleRate, 1f, 100f)
            putRange("boneMass", data.boneMass, 0.5f, 10f)
            putRange("proteinRate", data.proteinProportion, 1f, 50f)
            putRange("proteinMass", data.proteinMass, 0.5f, 100f)
            putRange("basalMetabolicRate", data.basalMetabolicRate, 25f, 14_995f)
        }

    private fun bloodComponentValues(data: BloodComponent): Map<String, Number> =
        buildMap {
            if (data.uricAcid in 90f..1000f) put("uricAcid", data.uricAcid)
            if (data.tCHO in 0.01f..100f) put("totalCholesterol", data.tCHO)
            if (data.tAG in 0.01f..100f) put("triglycerides", data.tAG)
            if (data.hDL in 0.01f..100f) put("highDensityLipoprotein", data.hDL)
            if (data.lDL in 0.01f..100f) put("lowDensityLipoprotein", data.lDL)
        }

    private fun measurementWrite(callback: ResultCallback<Unit>): IBleWriteResponse {
        val metric = activeMetric.orEmpty()
        val completed = AtomicBoolean(false)
        connectionHandler.postDelayed(
            {
                if (activeMetric == metric && completed.compareAndSet(false, true)) {
                    Log.w(LOG_TAG, "measurement start callback timed out metric=$metric; waiting for sensor result")
                    callback.success(Unit)
                }
            },
            MEASUREMENT_START_ACK_TIMEOUT_MS,
        )
        return IBleWriteResponse { code ->
            if (code == Code.REQUEST_SUCCESS) {
                Log.d(LOG_TAG, "measurement command accepted active=$activeMetric")
                if (completed.compareAndSet(false, true)) callback.success(Unit)
            } else {
                Log.w(LOG_TAG, "measurement command rejected code=$code active=$activeMetric")
                if (completed.compareAndSet(false, true)) {
                    synchronized(this) { activeMetric = null }
                    callback.error("MEASUREMENT_COMMAND_FAILED", "暂时无法开始测量，请稍后重试")
                } else {
                    failMeasurement(metric, "MEASUREMENT_COMMAND_FAILED", "暂时无法开始测量，请稍后重试")
                }
            }
        }
    }

    private fun measurementStopWrite(
        callback: ResultCallback<Unit>,
        metric: String,
    ): IBleWriteResponse {
        val completed = AtomicBoolean(false)
        connectionHandler.postDelayed(
            {
                if (completed.compareAndSet(false, true)) {
                    Log.w(LOG_TAG, "measurement stop callback timed out metric=$metric; releasing session")
                    callback.success(Unit)
                }
            },
            MEASUREMENT_STOP_CALLBACK_TIMEOUT_MS,
        )
        return IBleWriteResponse { code ->
            if (!completed.compareAndSet(false, true)) return@IBleWriteResponse
            if (code == Code.REQUEST_SUCCESS) {
                Log.d(LOG_TAG, "measurement stop accepted metric=$metric; waiting for device settle")
                connectionHandler.postDelayed(
                    { callback.success(Unit) },
                    MEASUREMENT_STOP_SETTLE_MS,
                )
            } else {
                Log.w(LOG_TAG, "measurement stop rejected code=$code metric=$metric")
                callback.error("MEASUREMENT_STOP_FAILED", "暂时无法停止${measurementMetricLabel(metric)}测量")
            }
        }
    }

    private fun measurementMetricLabel(metric: String): String =
        when (metric) {
            "blood_pressure" -> "血压"
            "body_temperature" -> "体温"
            "ecg" -> "心电"
            "hrv" -> "HRV"
            "body_composition" -> "身体成分"
            "blood_composition" -> "血液成分"
            else -> "当前"
        }

    private fun writeResponse(callback: ResultCallback<*>, message: String) =
        IBleWriteResponse { code ->
            if (code != Code.REQUEST_SUCCESS) callback.error("WRITE_FAILED", message)
        }

    private fun <T> withOperationTimeout(
        callback: ResultCallback<T>,
        code: String,
        message: String,
    ): ResultCallback<T> {
        val completed = AtomicBoolean(false)
        lateinit var timeout: Runnable
        val guarded =
            object : ResultCallback<T> {
                override fun success(value: T) {
                    if (!completed.compareAndSet(false, true)) return
                    connectionHandler.removeCallbacks(timeout)
                    callback.success(value)
                }

                override fun error(code: String, message: String) {
                    if (!completed.compareAndSet(false, true)) return
                    connectionHandler.removeCallbacks(timeout)
                    callback.error(code, message)
                }
            }
        timeout = Runnable { guarded.error(code, message) }
        connectionHandler.postDelayed(timeout, DEVICE_SETTING_TIMEOUT_MS)
        return guarded
    }

    private fun ensureConnected(callback: ResultCallback<*>): Unit? {
        val deviceId = connectedDeviceId.trim()
        if (deviceId.isBlank()) {
            callback.error("NOT_CONNECTED", "请先连接赛电设备")
            return null
        }
        if (!runCatching { manager.isDeviceConnected(deviceId) }.getOrDefault(false)) {
            clearStaleConnection(deviceId)
            callback.error("CONNECTION_DROPPED", "设备连接已断开，请重新连接")
            return null
        }
        return Unit
    }

    private fun record(
        type: String,
        values: Map<String, Number>,
        unit: String,
        measuredAt: Date,
        samples: List<Number> = emptyList(),
        rawVersion: Int = 1,
    ): Map<String, Any?> {
        val timestamp = iso8601(measuredAt)
        return buildMap(
        ) {
            putAll(mapOf(
            "id" to "$connectedDeviceId:$type:$timestamp",
            "type" to type,
            "values" to values,
            "unit" to unit,
            "measuredAt" to timestamp,
            "timezone" to timezoneOffset(),
            "deviceId" to connectedDeviceId,
            "firmwareVersion" to firmwareVersion,
            "quality" to "device_reported",
            "source" to "wearable",
            "rawVersion" to rawVersion,
            ))
            if (samples.isNotEmpty()) put("samples", samples)
        }
    }

    private fun emitRecord(record: Map<String, Any?>) {
        emit("healthRecord", record)
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        eventListener?.invoke(mapOf("type" to type, "payload" to payload))
    }

    private fun registerConnectStatusListener(address: String, generation: Int) {
        unregisterConnectStatusListener()
        val listener =
            object : IABleConnectStatusListener() {
                override fun onConnectStatusChanged(mac: String, status: Int) {
                    if (!mac.equals(address, ignoreCase = true)) return
                    connectionHandler.post {
                        if (connectionGeneration != generation) return@post
                        val activeCallback = activeConnectionFor(generation)
                        if (status == Constants.STATUS_CONNECTED) {
                            // Low-level GATT may connect briefly while the SDK
                            // is still retrying service discovery. Only the
                            // official connect/notify callbacks advance stage.
                            return@post
                        }
                        if (status != Constants.STATUS_DISCONNECTED) return@post
                        if (activeCallback != null) {
                            // Ignore the listener's initial disconnected state;
                            // once transport connected, a drop must finish the
                            // pending MethodChannel call instead of hanging it.
                            if (activeTransportConnected) {
                                failConnection(
                                    generation,
                                    activeCallback,
                                    "CONNECTION_DROPPED",
                                    "设备连接中断，请将手表靠近手机后重试",
                                )
                            }
                            return@post
                        }
                        if (connectedDeviceId.equals(address, ignoreCase = true)) {
                            cancelActiveHealthSync(
                                "HEALTH_SYNC_CANCELLED",
                                "设备连接已断开，历史数据同步已取消",
                                emitError = false,
                            )
                            connectingDeviceId = ""
                            connectedDeviceId = ""
                            clearMeasurementSessionState()
                            releaseJLWatchFaceSession()
                            emit("disconnected", mapOf("deviceId" to mac))
                        }
                    }
                }
            }
        connectStatusAddress = address
        connectStatusListener = listener
        manager.registerConnectStatusListener(address, listener)
    }

    private fun unregisterConnectStatusListener() {
        val address = connectStatusAddress
        val listener = connectStatusListener
        connectStatusAddress = ""
        connectStatusListener = null
        if (address.isNotBlank() && listener != null) {
            runCatching { manager.unregisterConnectStatusListener(address, listener) }
        }
    }

    private fun fail(callback: ResultCallback<Unit>, code: String, message: String) {
        emit("error", mapOf("code" to code, "message" to message))
        callback.error(code, message)
    }

    fun close(preserveConnection: Boolean = false) {
        cancelActiveHealthSync(
            "HEALTH_SYNC_CANCELLED",
            "设备服务已关闭，历史数据同步已取消",
            emitError = false,
        )
        cancelActiveConnectionAttempt(
            "CONNECT_CANCELLED",
            "连接任务已取消",
            emitError = false,
        )
        manager.stopScanDevice()
        finishScan()
        unregisterConnectStatusListener()
        connectingDeviceId = ""
        clearMeasurementSessionState()
        releaseJLWatchFaceSession()
        if (!preserveConnection) {
            connectedDeviceId = ""
            manager.disconnectWatch { }
        }
        eventListener = null
    }

    private fun scheduleCapabilitiesUpdate(generation: Int) {
        capabilityUpdateTask?.let(connectionHandler::removeCallbacks)
        val task =
            Runnable {
                if (connectionGeneration != generation) return@Runnable
                val updated = capabilitiesFromReports()
                if (updated["resolved"] != true) return@Runnable
                capabilities = updated
                if (connectedDeviceId.isNotBlank()) {
                    emit("capabilitiesUpdated", updated)
                }
            }
        capabilityUpdateTask = task
        connectionHandler.postDelayed(task, 320L)
    }

    private fun capabilitiesFromReports(): Map<String, Any?> {
        val legacy = legacyFunctionData
        val package1 = functionPackage1
        val package2 = functionPackage2
        val package3 = functionPackage3
        val package4 = functionPackage4
        val package5 = functionPackage5
        if (legacy == null &&
            package1 == null &&
            package2 == null &&
            package3 == null &&
            package4 == null &&
            package5 == null
        ) {
            return defaultCapabilities()
        }
        val preferences = VpSpGetUtil.getVpSpVariInstance(appContext)
        val heartRateSupported =
            package1?.heartRateDetect.haveFunction() || legacy?.heartDetect.haveFunction()
        val bloodPressureSupported =
            package1?.bloodPressure.haveFunction() || legacy?.bp.haveFunction()
        val bloodOxygenSupported =
            package1?.spo2H.haveFunction() || legacy?.spo2H.haveFunction()
        val temperatureSupported =
            package3?.temperatureFunction.haveFunction() ||
                (package3?.temperatureType ?: 0) > 0 ||
                legacy?.temperatureFunction.haveFunction() ||
                (legacy?.temptureType ?: 0) > 0
        val ecgSupported =
            package2?.ecgFunction.haveFunction() || legacy?.ecg.haveFunction()
        val hrvHistorySupported =
            package2?.hrvFunction.haveFunction() || legacy?.hrvFunction.haveFunction()
        val bodyComponentSupported =
            package4?.bodyComponent.haveFunction() || legacy?.bodyComponent.haveFunction()
        val bloodComponentSupported =
            package4?.bloodComponent.haveFunction() || legacy?.bloodComponent.haveFunction()
        hrvMiniCheckupSupported =
            package4?.miniCheckup.haveFunction() || preferences.isSupportMiniCheckup
        directHrvMeasurementSupported =
            package2?.hrvAppDetectFunction.haveFunction() ||
                legacy?.hrvAppDetectFunction.haveFunction() ||
                preferences.isSupportHrvAppDetect
        bloodGlucoseMeasurementSupported =
            package3?.bloodGlucose.haveFunction() ||
                legacy?.bloodGlucose.haveFunction() ||
                preferences.isSupportBloodGlucoseDetect ||
                preferences.isSupportBloodGlucose
        Log.i(
            LOG_TAG,
            "measurement capabilities directHrv=$directHrvMeasurementSupported " +
                "miniCheckupHrv=$hrvMiniCheckupSupported " +
                "bloodGlucose=$bloodGlucoseMeasurementSupported",
        )
        val metrics = mutableListOf("steps", "distance", "calories", "sleep")
        if (heartRateSupported) metrics += "heart_rate"
        if (bloodPressureSupported) metrics += "blood_pressure"
        if (bloodOxygenSupported) metrics += "blood_oxygen"
        if (bloodGlucoseMeasurementSupported) metrics += "blood_glucose"
        if (temperatureSupported) metrics += "body_temperature"
        if (ecgSupported) metrics += "ecg"
        if (hrvHistorySupported || directHrvMeasurementSupported || hrvMiniCheckupSupported) {
            metrics += "hrv"
        }
        if (bodyComponentSupported) metrics += "body_composition"
        if (bloodComponentSupported) metrics += "blood_composition"
        val manualMetrics = mutableListOf<String>()
        if (heartRateSupported) manualMetrics += "heart_rate"
        if (bloodPressureSupported) manualMetrics += "blood_pressure"
        if (bloodOxygenSupported) manualMetrics += "blood_oxygen"
        if (bloodGlucoseMeasurementSupported) manualMetrics += "blood_glucose"
        if (temperatureSupported) manualMetrics += "body_temperature"
        if (ecgSupported) manualMetrics += "ecg"
        if (directHrvMeasurementSupported || hrvMiniCheckupSupported) manualMetrics += "hrv"
        if (bodyComponentSupported) manualMetrics += "body_composition"
        if (bloodComponentSupported) manualMetrics += "blood_composition"
        val sportModes =
            when {
                supportsAppSportControl() -> listOf("running", "walking", "cycling", "hiking")
                supportsMultiSportMode() -> listOf("running", "walking", "cycling", "hiking")
                supportsSingleSportMode() -> listOf("running")
                else -> emptyList()
            }
        Log.i(
            LOG_TAG,
            "sport capabilities app=${supportsAppSportControl()} single=${supportsSingleSportMode()} multi=${supportsMultiSportMode()} modes=$sportModes",
        )
        val features = mutableListOf<String>()
        val legacyAutoMeasureTypes = legacyAutoMeasureTypes(preferences)
        val supportsHealthMonitoring =
            package4?.autoMeasure.haveFunction() ||
                legacy?.autoMeasure.haveFunction() ||
                preferences.isSupportAutoMeasure ||
                legacyAutoMeasureTypes.isNotEmpty()
        if (supportsHealthMonitoring) features += "health_monitoring"
        val watchFaceServerCount = package3?.watchUiServerCount ?: legacy?.watchUiServerCount ?: 0
        val watchFaceCustomCount = package3?.watchUiCustomCount ?: legacy?.watchUiCoustomCount ?: 0
        if (watchFaceServerCount > 0 || watchFaceCustomCount > 0 || manager.isJLCPUPlatform) {
            features += "watch_faces"
        }
        if (watchFaceCustomCount > 0 || manager.isJLCPUPlatform) {
            features += "photo_watch_face"
        }
        if (package3?.findDeviceByPhoneFunction.haveFunction() ||
            legacy?.findDeviceByPhone.haveFunction() ||
            preferences.isSupportFindDeviceByPhone
        ) {
            features += "find_watch"
        }
        if (package1?.camera.haveFunction() || legacy?.camera.haveFunction() || preferences.isSupportCamera) {
            features += "camera"
        }
        if (preferences.isSupportBTFunction) features += "phone_calls"
        if (package3?.contactFunction.haveFunction() ||
            (package3?.contactType ?: 0) > 0 ||
            legacy?.contactFunction.haveFunction() ||
            preferences.isSupportContactFunction
        ) {
            features += "contacts"
        }
        if ((package2?.allMsgLength ?: legacy?.allMsgLength ?: 0) > 0 || supportsSocialNotifications()) {
            features += "notifications"
        }
        if (package1?.alarm.haveFunction() ||
            package1?.textAlarm.haveFunction() ||
            legacy?.alarm2.haveFunction() ||
            legacy?.textAlarm.haveFunction() ||
            preferences.isSupportMultiAlarm ||
            preferences.isSupportTextAlarm
        ) {
            features += "alarms"
        }
        if (package2?.weatherFunction.haveFunction() || legacy?.weatherFunction.haveFunction()) {
            features += "weather"
        }
        if (package4?.worldClock.haveFunction() || legacy?.worldClock.haveFunction()) {
            features += "world_clock"
        }
        if (package1?.healthRemind.haveFunction() ||
            package1?.sedentaryRemind.haveFunction() ||
            legacy?.healthRemind.haveFunction() ||
            legacy?.longseat.haveFunction()
        ) {
            features += "health_reminders"
        }
        if (package3?.bloodGlucoseRiskAssessment.haveFunction() ||
            package4?.miniCheckup.haveFunction() ||
            legacy?.healthAssessment.haveFunction()
        ) {
            features += "health_assessment"
        }
        if (package1?.screenLight.haveFunction() ||
            package1?.nightTurnSetting.haveFunction() ||
            package2?.screenLightTime.haveFunction() ||
            (package5?.screenType ?: legacy?.screenType ?: 0) > 0 ||
            legacy?.screenLight.haveFunction()
        ) {
            features += "screen_display"
        }
        val integratedFeatures =
            listOf(
                "watch_faces",
                "photo_watch_face",
                "find_watch",
                "camera",
                "phone_calls",
                "contacts",
                "notifications",
                "alarms",
                "weather",
                "world_clock",
                "health_reminders",
                "health_monitoring",
                "health_assessment",
                "screen_display",
            ).filter { feature ->
                features.contains(feature) &&
                    (feature !in setOf("watch_faces", "photo_watch_face") || manager.isJLCPUPlatform)
            }
        return mapOf(
            "resolved" to true,
            "metrics" to metrics,
            "manualMetrics" to manualMetrics,
            "sportModes" to sportModes,
            "features" to features.distinct(),
            "integratedFeatures" to integratedFeatures,
            "supportsBackgroundSync" to true,
            "supportsWatchFaces" to features.contains("watch_faces"),
            "supportsOta" to false,
        )
    }

    private fun supportsSocialNotifications(): Boolean {
        val data = socialFunctionData ?: return false
        return data.phone.haveFunction() ||
            data.msg.haveFunction() ||
            data.wechat.haveFunction() ||
            data.qq.haveFunction() ||
            data.dingding.haveFunction() ||
            data.wxWork.haveFunction() ||
            data.whats.haveFunction() ||
            data.tikTok.haveFunction() ||
            data.telegram.haveFunction() ||
            data.other.haveFunction()
    }

    companion object {
        private const val CONNECTION_PREFERENCES = "saidian_wearable_connection"
        private const val LAST_DEVICE_ID = "last_device_id"
        private const val LAST_DEVICE_NAME = "last_device_name"
        private const val LOG_TAG = "SaidianVeepoo"
        private val FIRMWARE_VERSION_PATTERN = Regex("^[0-9A-Fa-f]{2}(\\.[0-9A-Fa-f]{2}){2}$")
        private const val PERSON_SYNC_TIMEOUT_MS = 8_000L
        private const val CONNECTION_FLOW_TIMEOUT_MS = 180_000L
        private const val HEALTH_SYNC_IDLE_TIMEOUT_MS = 45_000L
        private const val DEVICE_SETTING_TIMEOUT_MS = 15_000L
        // W9S needs about 12.4 seconds to return its first valid heart sample
        // after the sensor starts. Keep enough margin so a correctly worn
        // watch is not rejected just before that sample arrives.
        private const val BLOOD_PRESSURE_WEAR_TIMEOUT_MS = 20_000L
        private const val BLOOD_PRESSURE_MODE_TIMEOUT_MS = 4_000L
        private const val MEASUREMENT_START_ACK_TIMEOUT_MS = 1_500L
        private const val MEASUREMENT_STOP_SETTLE_MS = 1_200L
        private const val MEASUREMENT_STOP_CALLBACK_TIMEOUT_MS = 3_000L
        private const val ECG_RESULT_SETTLE_MS = 5_000L
        private const val ECG_MIN_SAMPLE_CHANGE_RATIO = 0.05
        private const val ECG_MIN_VALID_SAMPLE_RATIO = 0.95
        private const val ECG_MAX_DISPLAY_DEVIATION_MV = 2.5
        private const val ECG_MIN_CENTRAL_SPAN_MV = 0.002
        private const val ECG_MIN_USABLE_TAIL_SECONDS = 10
        private const val ECG_MAX_USABLE_TAIL_SECONDS = 30
        private const val ECG_CALIBRATED_RAW_VERSION = 2
        private const val ECG_PENDING_SECONDS = 10
        private const val DEFAULT_ECG_POWER = 20
        private const val ALARM_CACHE_FALLBACK_MS = 1_000L
        private const val ALARM_CACHE_SETTLE_MS = 120L
        private const val ALARM_WRITE_VERIFY_DELAY_MS = 1_200L
        private const val MAX_ALARM_LABEL_LENGTH = 20
        private const val WATCH_FACE_PROFILE_TIMEOUT_MS = 12_000L
        private const val WATCH_FACE_READ_TIMEOUT_MS = 45_000L
        private const val WATCH_FACE_RAW_FALLBACK_TIMEOUT_MS = 15_000L
        private const val WATCH_FACE_SLOT_PREPARE_TIMEOUT_MS = 12_000L
        private const val WATCH_FACE_CURRENT_READ_DELAY_MS = 200L
        private const val WATCH_FACE_CURRENT_READ_TIMEOUT_MS = 8_000L
        private const val JL_REQUESTED_MTU = 247
        private const val JL_MTU_CALLBACK_GRACE_MS = 1_500L
        private const val JL_SESSION_PREPARE_TIMEOUT_MS = 20_000L
        private const val WATCH_FACE_SWITCH_TIMEOUT_MS = 20_000L
        private const val WATCH_FACE_UPLOAD_TIMEOUT_MS = 150_000L
        private const val WATCH_FACE_REPLACE_SETTLE_MS = 1_500L
        private const val WATCH_FACE_SWITCH_SETTLE_MS = 1_000L
        private const val WATCH_FACE_VERIFY_DELAY_MS = 1_200L
        private const val PHOTO_LAYOUT_SETTLE_MS = 180L
        private const val PHOTO_LAYOUT_TIMEOUT_MS = 15_000L
        private const val DEFAULT_ECG_SAMPLE_FREQUENCY = 250
        private const val STALE_DISCONNECT_CHECKS = 20
        private const val STALE_DISCONNECT_POLL_MS = 150L
        private const val NOTIFICATION_PREFS = "saidian_notification_settings"
        private const val LEGACY_SEDENTARY_ID = "legacy_sedentary"
        private val NOTIFICATION_KEYS =
            listOf(
                "incomingCall",
                "sms",
                "wechat",
                "qq",
                "whatsapp",
                "dingtalk",
                "wecom",
                "tiktok",
                "telegram",
                "otherApps",
            )

        private fun defaultCapabilities(): Map<String, Any?> =
            mapOf(
                "resolved" to false,
                "metrics" to emptyList<String>(),
                "manualMetrics" to emptyList<String>(),
                "sportModes" to emptyList<String>(),
                "features" to emptyList<String>(),
                "integratedFeatures" to emptyList<String>(),
                "supportsBackgroundSync" to false,
                "supportsWatchFaces" to false,
                "supportsOta" to false,
            )

        private fun EFunctionStatus?.haveFunction(): Boolean = this?.isHaveFunction == true

        private fun iso8601(date: Date): String =
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(date)

        private fun timezoneOffset(): String {
            val offset = TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60000
            return String.format(Locale.US, "%+03d:%02d", offset / 60, kotlin.math.abs(offset % 60))
        }

        private fun dateAtNoon(value: String): Date =
            parseOriginTime(value, "12:00")

        private fun sleepRecordDate(day: String, sleep: SleepData): Date {
            val sdkDate = sleep.date?.trim().orEmpty()
            if (sdkDate.isNotEmpty()) return dateAtNoon(sdkDate)
            val daysAgo = day.toIntOrNull()?.coerceAtLeast(0) ?: 0
            return Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -daysAgo)
                set(Calendar.HOUR_OF_DAY, 12)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.time
        }

        private fun parseOriginTime(date: String?, time: String?): Date {
            val input = "${date.orEmpty()} ${time ?: "00:00"}".trim()
            val patterns = listOf("yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm")
            for (pattern in patterns) {
                runCatching { SimpleDateFormat(pattern, Locale.US).parse(input) }.getOrNull()?.let { return it }
            }
            return Date()
        }
    }
}
