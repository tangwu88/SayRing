import Flutter
import UIKit
import UserNotifications
#if canImport(VeepooBleSDK) && !targetEnvironment(simulator)
import VeepooBleSDK
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let wearableStreamHandler = WearableStreamHandler()
  private var wearableAdapter: WearableAdapter?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if canImport(VeepooBleSDK) && !targetEnvironment(simulator)
    wearableAdapter = VeepooWearableAdapter(events: wearableStreamHandler)
    #else
    wearableAdapter = UnconfiguredWearableAdapter()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "SaydianWearableBridge"
    ) else {
      return
    }

    let methods = FlutterMethodChannel(
      name: "cc.saidian/wearable_methods",
      binaryMessenger: registrar.messenger()
    )
    methods.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        self?.handleWearableCall(call, result: result)
      }
    }
    methodChannel = methods

    let events = FlutterEventChannel(
      name: "cc.saidian/wearable_events",
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(wearableStreamHandler)
    eventChannel = events
  }

  private func handleWearableCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let adapter = wearableAdapter else {
      result(FlutterError(code: "SDK_NOT_CONFIGURED", message: "设备连接服务暂时无法使用", details: nil))
      return
    }
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "scanDevices":
      adapter.scanDevices(result)
    case "connect":
      adapter.connect(
        arguments?["deviceId"] as? String ?? "",
        profile: arguments?["profile"] as? [String: Any] ?? [:],
        result: result
      )
    case "disconnect":
      adapter.disconnect(result)
    case "getDeviceDetails":
      adapter.getDeviceDetails(result)
    case "getCapabilities":
      result(adapter.capabilities())
    case "syncHealthData":
      adapter.syncHealthData(cursor: arguments?["cursor"] as? String, result: result)
    case "startMeasurement":
      adapter.startMeasurement(arguments?["metric"] as? String ?? "", result: result)
    case "stopMeasurement":
      adapter.stopMeasurement(arguments?["metric"] as? String ?? "", result: result)
    case "startSport":
      adapter.startSport(arguments?["mode"] as? String ?? "", result: result)
    case "stopSport":
      adapter.stopSport(result)
    case "readSportRecords":
      adapter.readSportRecords(result)
    case "readAutoMeasureSettings":
      adapter.readAutoMeasureSettings(result)
    case "setAutoMeasureSetting":
      adapter.setAutoMeasureSetting(
        arguments?["type"] as? String ?? "",
        enabled: arguments?["enabled"] as? Bool ?? false,
        result: result
      )
    case "readHeartRateWarning":
      adapter.readHeartRateWarning(result)
    case "setHeartRateWarning":
      adapter.setHeartRateWarning(arguments?["value"] as? Int ?? 120, result: result)
    case "readDeviceFeature":
      adapter.readDeviceFeature(arguments?["feature"] as? String ?? "", result: result)
    case "writeDeviceFeature":
      adapter.writeDeviceFeature(
        arguments?["feature"] as? String ?? "",
        values: arguments?["values"] as? [String: Any] ?? [:],
        result: result
      )
    case "triggerDeviceAction":
      adapter.triggerDeviceAction(
        arguments?["feature"] as? String ?? "",
        enabled: arguments?["enabled"] as? Bool ?? true,
        result: result
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private protocol WearableAdapter: AnyObject {
  func scanDevices(_ result: @escaping FlutterResult)
  func connect(
    _ deviceID: String,
    profile: [String: Any],
    result: @escaping FlutterResult
  )
  func disconnect(_ result: @escaping FlutterResult)
  func getDeviceDetails(_ result: @escaping FlutterResult)
  func capabilities() -> [String: Any]
  func syncHealthData(cursor: String?, result: @escaping FlutterResult)
  func startMeasurement(_ metric: String, result: @escaping FlutterResult)
  func stopMeasurement(_ metric: String, result: @escaping FlutterResult)
  func startSport(_ mode: String, result: @escaping FlutterResult)
  func stopSport(_ result: @escaping FlutterResult)
  func readSportRecords(_ result: @escaping FlutterResult)
  func readAutoMeasureSettings(_ result: @escaping FlutterResult)
  func setAutoMeasureSetting(_ type: String, enabled: Bool, result: @escaping FlutterResult)
  func readHeartRateWarning(_ result: @escaping FlutterResult)
  func setHeartRateWarning(_ value: Int, result: @escaping FlutterResult)
  func readDeviceFeature(_ feature: String, result: @escaping FlutterResult)
  func writeDeviceFeature(
    _ feature: String,
    values: [String: Any],
    result: @escaping FlutterResult
  )
  func triggerDeviceAction(
    _ feature: String,
    enabled: Bool,
    result: @escaping FlutterResult
  )
}

private final class UnconfiguredWearableAdapter: WearableAdapter {
  private func missing(_ result: @escaping FlutterResult) {
    result(FlutterError(code: "SDK_NOT_CONFIGURED", message: "设备连接服务暂时无法使用", details: nil))
  }

  func scanDevices(_ result: @escaping FlutterResult) { missing(result) }
  func connect(
    _ deviceID: String,
    profile: [String: Any],
    result: @escaping FlutterResult
  ) { missing(result) }
  func disconnect(_ result: @escaping FlutterResult) { missing(result) }
  func getDeviceDetails(_ result: @escaping FlutterResult) { missing(result) }
  func capabilities() -> [String: Any] { ["resolved": false] }
  func syncHealthData(cursor: String?, result: @escaping FlutterResult) { missing(result) }
  func startMeasurement(_ metric: String, result: @escaping FlutterResult) { missing(result) }
  func stopMeasurement(_ metric: String, result: @escaping FlutterResult) { missing(result) }
  func startSport(_ mode: String, result: @escaping FlutterResult) { missing(result) }
  func stopSport(_ result: @escaping FlutterResult) { missing(result) }
  func readSportRecords(_ result: @escaping FlutterResult) { missing(result) }
  func readAutoMeasureSettings(_ result: @escaping FlutterResult) { missing(result) }
  func setAutoMeasureSetting(_ type: String, enabled: Bool, result: @escaping FlutterResult) {
    missing(result)
  }
  func readHeartRateWarning(_ result: @escaping FlutterResult) { missing(result) }
  func setHeartRateWarning(_ value: Int, result: @escaping FlutterResult) { missing(result) }
  func readDeviceFeature(_ feature: String, result: @escaping FlutterResult) { missing(result) }
  func writeDeviceFeature(
    _ feature: String,
    values: [String: Any],
    result: @escaping FlutterResult
  ) { missing(result) }
  func triggerDeviceAction(
    _ feature: String,
    enabled: Bool,
    result: @escaping FlutterResult
  ) { missing(result) }
}

#if canImport(VeepooBleSDK) && !targetEnvironment(simulator)
private final class VeepooWearableAdapter: WearableAdapter {
  private let manager = VPBleCentralManage.sharedBleManager()!
  private weak var events: WearableStreamHandler?
  private var scanned: [String: VPPeripheralModel] = [:]
  private var connected: VPPeripheralModel?
  private var connectedRouteID: String?
  private var scanResult: FlutterResult?
  private var connectResult: FlutterResult?
  private var awaitingAutomaticReconnect = false
  private var userProfile: [String: Any] = [:]
  private var autoMeasureModels: [String: VPAutoMonitTestModel] = [:]
  private var activeSportMode: String?
  private var cameraRemoteActive = false
  private var screenBrightModel: VPDeviceBrightModel?
  private var screenDurationModel: VPScreenDurationModel?
  private var screenRaiseHandModel: VPDeviceRaiseHandModel?
  private var worldClockModels: [VPWorldClockModel] = []
  private var weatherConfigModel: VPWeatherConfigModel?
  private var photoDialModel: VPPhotoDialModel?
  private var phoneCallState: [String: Any] = [
    "connectionStatus": "unknown",
    "paired": false,
    "enabled": false,
    "audioEnabled": false,
  ]

  init(events: WearableStreamHandler) {
    self.events = events
    manager.isLogEnable = false
    // The SDK defaults to -85 dBm. W9-family watches with a slow/weak
    // advertisement can otherwise disappear from the discovery list even
    // while they are still connectable at close range.
    manager.rrisLimit = -100
    manager.manufacturerIDFilter = false
    manager.automaticConnection = true
    manager.is24HourFormat = true
    manager.peripheralManage.vpbtConnectStateChangeBlock = { [weak self] state, btOpen, mediaOpen in
      guard let self else { return }
      let status: String = switch state {
      case .connected: "connected"
      case .advertising: "broadcasting"
      default: "disconnected"
      }
      self.phoneCallState = [
        "connectionStatus": status,
        "paired": state == .connected,
        "enabled": btOpen,
        "audioEnabled": mediaOpen,
      ]
      self.emit("phoneCallState", self.phoneCallState)
    }
    manager.vpBleConnectStateChangeBlock = { [weak self] state in
      if state == .connectStateTimeout || state == .confirmStateTimeout {
        self?.failConnect("CONNECT_FAILED", "设备连接失败或超时")
      } else if state == .connectStateVerifyPasswordFailure {
        self?.failConnect("PASSWORD_FAILED", "设备密码校验失败")
      } else if state == .connectStateConnect {
        self?.emit("state", ["value": "authenticating"])
      } else if state == .connectStateVerifyPasswordSuccess {
        self?.connected = self?.manager.peripheralModel
        self?.synchronizePersonalInformation()
      } else if state == .connectStateDisConnect {
        self?.awaitingAutomaticReconnect = self?.connectResult == nil
        self?.connected = nil
        self?.emit("disconnected", [:])
      }
    }
  }

  func scanDevices(_ result: @escaping FlutterResult) {
    if scanResult != nil {
      result(FlutterError(code: "SCAN_IN_PROGRESS", message: "正在扫描设备", details: nil))
      return
    }
    scanned.removeAll()
    scanResult = result
    emit("state", ["value": "scanning"])
    manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] model in
      guard let self,
            let model else { return }
      let routeID = Self.routeIdentifier(model)
      guard !routeID.isEmpty else { return }
      self.scanned[routeID] = model
    }
    // Match the Android HBand scan window. Some W9-family firmware advertises
    // less frequently and can be missed by the former eight-second window.
    DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
      guard let self, let callback = self.scanResult else { return }
      self.manager.veepooSDKStopScanDevice()
      self.scanResult = nil
      let payload = self.scanned.values.sorted { $0.rssi.intValue > $1.rssi.intValue }.map { model in
        let deviceID = Self.routeIdentifier(model)
        let deviceName = Self.displayName(model.deviceName)
        return [
          "id": deviceID,
          "name": deviceName,
          "model": deviceName,
          "rssi": model.rssi.intValue,
        ] as [String: Any]
      }
      self.emit("state", ["value": "disconnected"])
      callback(payload)
    }
  }

  func connect(
    _ deviceID: String,
    profile: [String: Any],
    result: @escaping FlutterResult
  ) {
    guard let model = scanned[deviceID] else {
      result(FlutterError(code: "DEVICE_NOT_FOUND", message: "设备已离开扫描范围，请重新扫描", details: nil))
      return
    }
    connectResult = result
    userProfile = profile
    connected = model
    connectedRouteID = deviceID
    emit("state", ["value": "connecting"])
    manager.veepooSDKStopScanDevice()
    manager.veepooSDKConnectDevice(model) { [weak self] state in
      guard let self else { return }
      if state == .BleConnectFailed || state == .BleConnectTimeout || state == .BleConfirmTimeout {
        self.failConnect("CONNECT_FAILED", "设备连接失败或超时")
      }
    }
  }

  private func synchronizePersonalInformation() {
    guard connectResult != nil || awaitingAutomaticReconnect,
          let device = connected else { return }
    emit("state", ["value": "syncing"])
    manager.peripheralManage.veepooSDKSynchronousPersonalInformation(
      withStature: UInt(clamping: profileInt("heightCm", fallback: 175)),
      weight: UInt(clamping: profileInt("weightKg", fallback: 70)),
      birth: UInt(clamping: profileInt("birthYear", fallback: 1990)),
      sex: UInt(clamping: profileInt("gender", fallback: 1)),
      targetStep: UInt(clamping: profileInt("targetSteps", fallback: 8000))
    ) { [weak self] status in
      guard let self else { return }
      if status == 1 {
        let details = self.deviceDetails(device)
        self.emit("deviceDetails", details)
        self.emit("capabilitiesUpdated", self.capabilities())
        if let callback = self.connectResult {
          self.connectResult = nil
          self.emit("state", ["value": "ready"])
          callback(nil)
        } else if self.awaitingAutomaticReconnect {
          self.awaitingAutomaticReconnect = false
          self.emit("reconnected", details)
        }
      } else {
        self.awaitingAutomaticReconnect = false
        self.emit("error", ["code": "PERSON_SYNC_FAILED", "message": "个人信息同步失败"])
        if let callback = self.connectResult {
          self.connectResult = nil
          callback(FlutterError(code: "PERSON_SYNC_FAILED", message: "个人信息同步失败", details: nil))
        }
      }
    }
  }

  private func failConnect(_ code: String, _ message: String) {
    guard let callback = connectResult else { return }
    connectResult = nil
    emit("error", ["code": code, "message": message])
    callback(FlutterError(code: code, message: message, details: nil))
  }

  func disconnect(_ result: @escaping FlutterResult) {
    manager.veepooSDKDisconnectDevice()
    connected = nil
    connectedRouteID = nil
    emit("disconnected", [:])
    result(nil)
  }

  func getDeviceDetails(_ result: @escaping FlutterResult) {
    guard let device = connected else {
      result(nil)
      return
    }
    result(deviceDetails(device))
  }

  func capabilities() -> [String: Any] {
    guard let model = connected else {
      return [
        "resolved": false,
        "metrics": [],
        "manualMetrics": [],
        "features": [],
        "integratedFeatures": [],
        "supportsBackgroundSync": false,
        "supportsWatchFaces": false,
        "supportsOta": false,
      ]
    }
    var metrics = ["steps", "distance", "calories", "sleep"]
    if model.heartRateType > 0 { metrics.append("heart_rate") }
    if model.bloodPressureType > 0 { metrics.append("blood_pressure") }
    if model.bloodOxygenType > 0 || model.oxygenType > 0 { metrics.append("blood_oxygen") }
    if model.temperatureType > 0 { metrics.append("body_temperature") }
    if model.bloodGlucoseType > 0 { metrics.append("blood_glucose") }
    if model.ecgType > 0 { metrics.append("ecg") }
    if model.hrvType > 0 { metrics.append("hrv") }
    if model.bodyCompositionType > 0 { metrics.append("body_composition") }
    if model.bloodAnalysisType > 0 { metrics.append("blood_composition") }
    let manualMetrics = metrics.filter { !["steps", "distance", "calories", "sleep"].contains($0) }
    var features = ["health_monitoring"]
    if model.dialCount > 0 || model.marketDialCount > 0 { features.append("watch_faces") }
    if model.photoDialCount > 0 { features.append("photo_watch_face") }
    if model.searchDeviceFunction > 0 { features.append("find_watch") }
    if Self.supportsCamera(model) { features.append("camera") }
    if model.contactType > 0 { features.append("contacts") }
    if model.deviceBTInfoData.count > 0 { features.append("phone_calls") }
    if model.deviceAncsData.count > 0 { features.append("notifications") }
    if Self.alarmKind(model) != nil { features.append("alarms") }
    if model.weatherType > 0 { features.append("weather") }
    if model.worldClockType > 0 { features.append("world_clock") }
    if Self.supportsLongSeat(model) { features.append("health_reminders") }
    if model.screenTypes > 0 || model.screenDurationType > 0 || Self.supportsBrightness(model) || Self.supportsRaiseHand(model) {
      features.append("screen_display")
    }
    if model.funcAssessmentType.rawValue > 0 {
      features.append("health_assessment")
    }
    return [
      "resolved": true,
      "metrics": metrics,
      "manualMetrics": manualMetrics,
      "features": features,
      "integratedFeatures": features.filter { ["health_monitoring", "watch_faces", "photo_watch_face", "find_watch", "camera", "phone_calls", "contacts", "notifications", "alarms", "weather", "world_clock", "health_reminders", "health_assessment", "screen_display"].contains($0) },
      "supportsBackgroundSync": true,
      "supportsWatchFaces": features.contains("watch_faces"),
      "supportsOta": false,
    ]
  }

  func syncHealthData(cursor: String?, result: @escaping FlutterResult) {
    guard connected != nil else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    emit("syncProgress", [
      "deviceId": connectedRouteID ?? "",
      "progress": 0.0,
      "cursor": cursor as Any,
    ])
    manager.peripheralManage.veepooSdkStartReadDeviceAllData { [weak self] state, totalDays, currentDay, progress in
      guard let self else { return }
      let total = max(totalDays, 1)
      let fraction = min(1.0, (Double(currentDay) + Double(progress) / 100.0) / Double(total))
      self.emit("syncProgress", [
        "deviceId": self.connectedRouteID ?? "",
        "progress": fraction,
        "cursor": cursor as Any,
      ])
      if state == .complete {
        let records = self.recordsFromDatabase()
        self.emit("syncProgress", [
          "deviceId": self.connectedRouteID ?? "",
          "progress": 1.0,
          "cursor": cursor as Any,
        ])
        result(records)
      } else if state == .invalid {
        result(FlutterError(code: "SYNC_UNSUPPORTED", message: "当前设备不支持健康数据同步", details: nil))
      }
    }
  }

  func startMeasurement(_ metric: String, result: @escaping FlutterResult) {
    guard connected != nil else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard (capabilities()["metrics"] as? [String])?.contains(metric) == true else {
      result(FlutterError(code: "UNSUPPORTED_METRIC", message: "当前设备不支持该指标", details: nil))
      return
    }
    emit("state", ["value": "measuring", "metric": metric])
    switch metric {
    case "heart_rate":
      manager.peripheralManage.veepooSDKTestHeartStart(true) { [weak self] state, value in
        if state.rawValue == 1, (20...300).contains(value) {
          self?.emitRecord(type: metric, values: ["value": NSNumber(value: value)], unit: "bpm")
        }
      }
    case "blood_oxygen":
      manager.peripheralManage.veepooSDKTestOxygenStart(true) { [weak self] state, value in
        if state.rawValue == 1, (2...100).contains(value) {
          self?.emitRecord(type: metric, values: ["value": NSNumber(value: value)], unit: "%")
        }
      }
    case "blood_pressure":
      manager.peripheralManage.veepooSDKTestBloodStart(true, testMode: 0) { [weak self] state, progress, high, low in
        if state.rawValue == 4,
           progress >= 100,
           (60...300).contains(high),
           (20...200).contains(low),
           high > low {
          self?.emitRecord(type: metric, values: ["systolic": NSNumber(value: high), "diastolic": NSNumber(value: low)], unit: "mmHg")
        }
      }
    case "body_temperature":
      manager.peripheralManage.veepooSDK_temperatureTestStart(true) { [weak self] state, busy, progress, value, _ in
        let temperature = Double(value) / 10.0
        if state.rawValue == 1,
           !busy,
           progress >= 100,
           (20.0...45.0).contains(temperature) {
          self?.emitRecord(type: metric, values: ["value": NSNumber(value: temperature)], unit: "℃")
        }
      }
    case "blood_glucose":
      manager.peripheralManage.veepooSDKTestBloodGlucoseStart(true, isPersonalModel: false) { [weak self] state, progress, value, _ in
        if state.rawValue == 1, progress >= 100, value > 0 {
          self?.emitRecord(type: metric, values: ["value": NSNumber(value: Double(value) / 100.0)], unit: "mmol/L")
        }
      }
    case "ecg":
      manager.peripheralManage.veepooSDKTestECGStart(true) { [weak self] _, _, model in
        guard let self, let model else { return }
        let values = self.ecgValues(model)
        if !values.isEmpty {
          let samples = model.filterSignals
            .compactMap(Self.number)
            .filter { $0.int64Value != Int64(Int32.max) }
          self.emitRecord(type: metric, values: values, unit: "", samples: samples)
        }
      }
    case "body_composition":
      manager.peripheralManage.veepooSDKTestBodyCompositionStart(true, progress: { _, _ in }) { [weak self] _, model in
        guard let self, let model else { return }
        let values = self.bodyCompositionValues(model)
        if !values.isEmpty { self.emitRecord(type: metric, values: values, unit: "") }
      }
    case "blood_composition":
      manager.peripheralManage.veepooSDKTestBloodAnalysisStart(true, isPersonalModel: false, progress: { _ in }) { [weak self] _, model in
        guard let self, let model else { return }
        let values = self.bloodAnalysisValues(model)
        if !values.isEmpty { self.emitRecord(type: metric, values: values, unit: "") }
      }
    default:
      result(FlutterError(code: "MEASUREMENT_NOT_AVAILABLE", message: "该指标仅支持同步手表历史数据", details: nil))
      return
    }
    result(nil)
  }

  func stopMeasurement(_ metric: String, result: @escaping FlutterResult) {
    switch metric {
    case "heart_rate":
      manager.peripheralManage.veepooSDKTestHeartStart(false, testResult: nil)
    case "blood_oxygen":
      manager.peripheralManage.veepooSDKTestOxygenStart(false, testResult: nil)
    case "blood_pressure":
      manager.peripheralManage.veepooSDKTestBloodStart(false, testMode: 0, testResult: nil)
    case "body_temperature":
      manager.peripheralManage.veepooSDK_temperatureTestStart(false) { _, _, _, _, _ in }
    case "blood_glucose":
      manager.peripheralManage.veepooSDKTestBloodGlucoseStart(false, isPersonalModel: false, testResult: nil)
    case "ecg":
      manager.peripheralManage.veepooSDKTestECGStart(false, testResult: nil)
    case "body_composition":
      manager.peripheralManage.veepooSDKTestBodyCompositionStart(false, progress: { _, _ in }, testResult: { _, _ in })
    case "blood_composition":
      manager.peripheralManage.veepooSDKTestBloodAnalysisStart(false, isPersonalModel: false, progress: { _ in }, testResult: { _, _ in })
    default:
      result(FlutterError(code: "MEASUREMENT_NOT_AVAILABLE", message: "该指标没有可停止的实时测量", details: nil))
      return
    }
    result(nil)
  }

  func startSport(_ mode: String, result: @escaping FlutterResult) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard model.runningSaveTimes > 0,
          let mappedMode = WearablePayloadMapper.sportMode(mode) else {
      result(FlutterError(code: "SPORT_UNSUPPORTED", message: "当前手表不支持该运动模式", details: nil))
      return
    }
    let sdkMode: VPDeviceRuningMode = switch mappedMode {
    case .outdoorRun: .outdoorRun
    case .outdoorWalk: .outdoorWalk
    case .outdoorRide: .outdoorCycle
    case .hiking: .hiking
    }
    manager.peripheralManage.veepooSDKSettingDeviceRunning(1, run: sdkMode) { [weak self] state, success in
      guard let self else { return }
      if success {
        self.activeSportMode = mode
        self.emit("sportState", ["value": "running", "mode": mode, "deviceStatus": state])
        result(nil)
      } else {
        result(FlutterError(code: "SPORT_START_FAILED", message: state == 2 ? "手表正在执行其他操作" : "运动模式暂时无法开启", details: ["deviceStatus": state]))
      }
    }
  }

  func stopSport(_ result: @escaping FlutterResult) {
    guard connected != nil else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    manager.peripheralManage.veepooSDKSettingDeviceRunning(0, run: .common) { [weak self] state, success in
      guard let self else { return }
      if success || state == 0 {
        self.emit("sportState", ["value": "stopped", "mode": self.activeSportMode as Any])
        self.activeSportMode = nil
        result(nil)
      } else {
        result(FlutterError(code: "SPORT_STOP_FAILED", message: "运动模式暂时无法结束", details: ["deviceStatus": state]))
      }
    }
  }

  func readSportRecords(_ result: @escaping FlutterResult) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard model.runningSaveTimes > 0 else {
      result(FlutterError(code: "SPORT_UNSUPPORTED", message: "当前手表不支持运动记录", details: nil))
      return
    }
    manager.peripheralManage.veepooSDKStartReadDeviceRunningData { [weak self] state, total, current, progress in
      guard let self else { return }
      let denominator = max(total, 1)
      let fraction = min(1.0, (Double(current) + Double(progress) / 100.0) / Double(denominator))
      self.emit("sportSyncProgress", [
        "deviceId": self.connectedRouteID ?? "",
        "progress": fraction,
      ])
      if state == .complete {
        let records = (VPDataBaseOperation.veepooSDKGetDeviceRunningData(withDate: nil, andTableID: model.deviceAddress) as? [[String: Any]] ?? [])
          .compactMap(WearablePayloadMapper.sportRecord)
        result(Dictionary(grouping: records, by: { $0["id"] as? String ?? UUID().uuidString }).compactMap { $0.value.first })
      } else if state == .invalid {
        result(FlutterError(code: "SPORT_UNSUPPORTED", message: "当前手表不支持运动记录", details: nil))
      }
    }
  }

  func readAutoMeasureSettings(_ result: @escaping FlutterResult) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard model.autoMonitSwitchType > 0 else {
      autoMeasureModels.removeAll()
      result([String: Bool]())
      return
    }
    manager.peripheralManage.veepooSDKReadAutoMonitSwitchInfo { [weak self] models in
      guard let self else { return }
      guard let models else {
        result(FlutterError(code: "AUTO_MEASURE_READ_FAILED", message: "自动检测设置暂时无法读取", details: nil))
        return
      }
      self.autoMeasureModels.removeAll()
      for model in models {
        guard let name = Self.autoMeasureName(model.type) else { continue }
        self.autoMeasureModels[name] = model
      }
      result(self.autoMeasureModels.mapValues(\.on))
    }
  }

  func setAutoMeasureSetting(_ type: String, enabled: Bool, result: @escaping FlutterResult) {
    guard connected != nil else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard let model = autoMeasureModels[type] else {
      result(FlutterError(code: "AUTO_MEASURE_UNSUPPORTED", message: "当前手表不支持该自动检测功能，请先刷新设置", details: nil))
      return
    }
    let previous = model.on
    model.on = enabled
    manager.peripheralManage.veepooSDKSetAutoMonitSwitch(with: model) { success, _ in
      if success {
        result(nil)
      } else {
        model.on = previous
        result(FlutterError(code: "AUTO_MEASURE_WRITE_FAILED", message: "自动检测设置写入失败", details: nil))
      }
    }
  }

  func readHeartRateWarning(_ result: @escaping FlutterResult) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard Self.supportsHeartWarning(model) else {
      result(nil)
      return
    }
    manager.peripheralManage.veepooSDKSettingDeviceHeartAlarm(
      with: VPDeviceHeartAlarmModel(),
      settingMode: 2,
      successResult: { heartAlarm in
        result(heartAlarm?.isOpen == true ? Int(heartAlarm?.heartMaxValue ?? 0) : 0)
      },
      failureResult: {
        result(FlutterError(code: "HEART_WARNING_READ_FAILED", message: "心率预警暂时无法读取", details: nil))
      }
    )
  }

  func setHeartRateWarning(_ value: Int, result: @escaping FlutterResult) {
    guard let device = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    guard Self.supportsHeartWarning(device) else {
      result(FlutterError(code: "HEART_WARNING_UNSUPPORTED", message: "当前手表不支持心率过高预警", details: nil))
      return
    }
    let bounded = WearablePayloadMapper.clampedHeartWarning(value)
    let model = VPDeviceHeartAlarmModel(heartMaxValue: UInt(bounded), heartMinValue: 40, openState: true)
    manager.peripheralManage.veepooSDKSettingDeviceHeartAlarm(
      with: model,
      settingMode: 1,
      successResult: { _ in result(nil) },
      failureResult: {
        result(FlutterError(code: "HEART_WARNING_WRITE_FAILED", message: "心率预警设置失败", details: nil))
      }
    )
  }

  func readDeviceFeature(_ feature: String, result: @escaping FlutterResult) {
    guard connected != nil else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    if feature == "camera" {
      result(["enabled": cameraRemoteActive])
      return
    }
    if feature == "notifications" {
      readNotificationSettings(result)
      return
    }
    if feature == "screen_display" {
      readScreenSettings(result)
      return
    }
    if feature == "health_reminders" {
      readLongSeat(result)
      return
    }
    if feature == "world_clock" {
      readWorldClocks(result)
      return
    }
    if feature == "contacts" {
      readContacts(result)
      return
    }
    if feature == "alarms" {
      readAlarms(result)
      return
    }
    if feature == "weather" {
      readWeather(result)
      return
    }
    if feature == "health_assessment" {
      readHealthAssessment(result)
      return
    }
    if feature == "phone_calls" {
      readPhoneCalls(result)
      return
    }
    if feature == "watch_faces" {
      readWatchFaces(result)
      return
    }
    if feature == "photo_watch_face" {
      readPhotoWatchFace(result)
      return
    }
    result(FlutterError(
      code: "FEATURE_UNAVAILABLE",
      message: "此功能暂时无法使用，请稍后再试",
      details: nil
    ))
  }

  func writeDeviceFeature(
    _ feature: String,
    values: [String: Any],
    result: @escaping FlutterResult
  ) {
    guard connected != nil else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    if feature == "notifications" {
      let entries = Self.notificationTypes.compactMap { key, type -> VPDeviceMessageTypeModel? in
        guard let enabled = values[key] as? Bool else { return nil }
        let model = VPDeviceMessageTypeModel()
        model.messageType = type
        model.open = enabled
        return model
      }
      guard !entries.isEmpty else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "没有可保存的通知设置", details: nil))
        return
      }
      manager.peripheralManage.veepooSDKBatchSetting(with: entries) { state in
        if state == .functionCompleteFailure || state == .functionCompleteUnknown {
          result(FlutterError(code: "NOTIFICATION_WRITE_FAILED", message: "消息通知设置保存失败", details: nil))
        } else {
          result(nil)
        }
      }
      return
    }
    if feature == "screen_display" {
      writeScreenSettings(values, result: result)
      return
    }
    if feature == "health_reminders" {
      writeLongSeat(values, result: result)
      return
    }
    if feature == "world_clock" {
      writeWorldClock(values, result: result)
      return
    }
    if feature == "contacts" {
      writeContact(values, result: result)
      return
    }
    if feature == "alarms" {
      writeAlarm(values, result: result)
      return
    }
    if feature == "weather" {
      writeWeather(values, result: result)
      return
    }
    if feature == "health_assessment" {
      writeHealthAssessment(values, result: result)
      return
    }
    if feature == "phone_calls" {
      writePhoneCalls(values, result: result)
      return
    }
    if feature == "watch_faces" {
      switchWatchFace(values, result: result)
      return
    }
    if feature == "photo_watch_face" {
      uploadPhotoWatchFace(values, result: result)
      return
    }
    result(FlutterError(
      code: "FEATURE_UNAVAILABLE",
      message: "此功能暂时无法使用，请稍后再试",
      details: nil
    ))
  }

  func triggerDeviceAction(
    _ feature: String,
    enabled: Bool,
    result: @escaping FlutterResult
  ) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    if feature == "find_watch" {
      guard model.searchDeviceFunction > 0 else {
        result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持查找功能", details: nil))
        return
      }
      manager.peripheralManage.veepooSDK_searchDeviceFuntion(withState: enabled) { open, state in
        if state == .unsupported {
          result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持查找功能", details: nil))
        } else {
          result(nil)
        }
      }
      return
    }
    if feature == "camera" {
      guard Self.supportsCamera(model) else {
        result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持相机遥控", details: nil))
        return
      }
      manager.peripheralManage.veepooSDKSettingCameraType(enabled ? .enter : .exit) { [weak self] type in
        guard let self else { return }
        if type == .photo {
          self.emit("cameraShutter", ["deviceId": self.connectedRouteID ?? ""])
          return
        }
        self.cameraRemoteActive = type == .enter
        result(nil)
      }
      return
    }
    if feature == "notifications" {
      let settingsURL: String
      if #available(iOS 16.0, *) {
        settingsURL = UIApplication.openNotificationSettingsURLString
      } else {
        settingsURL = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: settingsURL) else {
        result(FlutterError(code: "SETTINGS_UNAVAILABLE", message: "无法打开系统通知设置", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        opened ? result(nil) : result(FlutterError(code: "SETTINGS_UNAVAILABLE", message: "无法打开系统通知设置", details: nil))
      }
      return
    }
    result(FlutterError(
      code: "FEATURE_UNAVAILABLE",
      message: "此功能暂时无法使用，请稍后再试",
      details: nil
    ))
  }

  private func recordsFromDatabase() -> [[String: Any]] {
    guard let model = connected else { return [] }
    let tableID = model.deviceAddress
    let days = max(Int(model.saveDays), 1)
    var records: [[String: Any]] = []
    for offset in 0..<days {
      guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
      let dateString = Self.dayFormatter.string(from: date)
      let dayAtNoon = Self.parseDate("\(dateString) 12:00") ?? date

      VPDataBaseOperation.veepooSDKGetStepData(
        withDate: dateString,
        andTableID: tableID,
        changeUserStature: UInt(clamping: profileInt("heightCm", fallback: 175))
      ) { [weak self] dictionary in
        guard let self, let dictionary else { return }
        if let value = Self.number(dictionary["Step"]), value.doubleValue > 0 {
          records.append(self.record(type: "steps", values: ["value": value], unit: "步", at: dayAtNoon))
        }
        if let value = Self.number(dictionary["Dis"]), value.doubleValue > 0 {
          records.append(self.record(type: "distance", values: ["value": value], unit: "km", at: dayAtNoon))
        }
        if let value = Self.number(dictionary["Cal"]), value.doubleValue > 0 {
          records.append(self.record(type: "calories", values: ["value": value], unit: "kcal", at: dayAtNoon))
        }
      }

      if let heartData = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(
        withDate: dateString,
        andTableID: tableID
      ) as? [String: [String: Any]] {
        var daySteps = 0.0
        var dayDistance = 0.0
        var dayCalories = 0.0
        for (time, item) in heartData {
          if let value = Self.number(item["heartValue"]), value.doubleValue > 0 {
            records.append(record(type: "heart_rate", values: ["value": value], unit: "bpm", at: Self.parseDate("\(dateString) \(time)") ?? date))
          }
          daySteps += Self.number(item["stepValue"])?.doubleValue ?? 0
          dayDistance += Self.number(item["disValue"])?.doubleValue ?? 0
          dayCalories += Self.number(item["calValue"])?.doubleValue ?? 0
        }
        if daySteps > 0 { records.append(record(type: "steps", values: ["value": NSNumber(value: daySteps)], unit: "步", at: dayAtNoon)) }
        if dayDistance > 0 { records.append(record(type: "distance", values: ["value": NSNumber(value: dayDistance)], unit: "km", at: dayAtNoon)) }
        if dayCalories > 0 { records.append(record(type: "calories", values: ["value": NSNumber(value: dayCalories)], unit: "kcal", at: dayAtNoon)) }
      }

      if let bloodData = VPDataBaseOperation.veepooSDKGetBloodData(withDate: dateString, andTableID: tableID) as? [[String: Any]] {
        for item in bloodData {
          guard let high = Self.number(item["systolic"]), let low = Self.number(item["diastolic"]), high.doubleValue > 0, low.doubleValue > 0 else { continue }
          let at = Self.parseDate("\(dateString) \(item["Time"] as? String ?? "12:00")") ?? date
          records.append(record(type: "blood_pressure", values: ["systolic": high, "diastolic": low], unit: "mmHg", at: at))
        }
      }

      if let sleepData = VPDataBaseOperation.veepooSDKGetSleepData(withDate: dateString, andTableID: tableID) as? [[String: Any]] {
        for item in sleepData {
          let hours = Self.number(item["SLE_HOUR"])?.doubleValue ?? 0
          let minutes = Self.number(item["SLE_MINUTE"])?.doubleValue ?? 0
          let duration = hours + minutes / 60.0
          guard duration > 0 else { continue }
          let at = Self.parseDate(item["SLEEP_TIME"] as? String ?? "") ?? dayAtNoon
          var values: [String: NSNumber] = ["value": NSNumber(value: duration)]
          if let deep = Self.number(item["DEEP_HOUR"]), deep.doubleValue >= 0 { values["deepHours"] = deep }
          if let light = Self.number(item["LIGHT_HOUR"]), light.doubleValue >= 0 { values["lightHours"] = light }
          if let wake = Self.number(item["WakeUpTime"]), wake.intValue >= 0 { values["wakeCount"] = wake }
          records.append(record(type: "sleep", values: values, unit: "h", at: at))
        }
      }

      if model.oxygenType > 0,
         let oxygenData = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: dateString, andTableID: tableID) as? [[String: Any]] {
        for item in oxygenData {
          guard let value = Self.number(item["oxygenValue"] ?? item["Oxygen"]), value.doubleValue > 0 else { continue }
          let time = item["Time"] as? String ?? item["time"] as? String ?? "12:00"
          records.append(record(type: "blood_oxygen", values: ["value": value], unit: "%", at: Self.parseDate("\(dateString) \(time)") ?? date))
        }
      }

      if model.temperatureType > 0,
         let temperatureData = VPDataBaseOperation.veepooSDKGetDeviceTemperatureData(withDate: dateString, andTableID: tableID) as? [[String: Any]] {
        for item in temperatureData {
          guard let value = Self.number(item["value"]), value.doubleValue > 0 else { continue }
          let hour = Self.number(item["hour"])?.intValue ?? 12
          let minute = Self.number(item["minute"])?.intValue ?? 0
          let at = Self.parseDate(String(format: "%@ %02d:%02d", dateString, hour, minute)) ?? date
          records.append(record(type: "body_temperature", values: ["value": value], unit: "℃", at: at))
        }
      }

      if model.hrvType > 0,
         let hrvData = VPDataBaseOperation.veepooSDKGetDeviceHrvData(withDate: dateString, andTableID: tableID) as? [[String: Any]] {
        for item in hrvData {
          guard let value = Self.number(item["hrvValue"] ?? item["HRV"]), value.doubleValue > 0 else { continue }
          let time = item["Time"] as? String ?? item["time"] as? String ?? "12:00"
          records.append(record(type: "hrv", values: ["value": value], unit: "ms", at: Self.parseDate("\(dateString) \(time)") ?? date))
        }
      }

      if model.bloodGlucoseType > 0,
         let glucoseData = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateString, andTableID: tableID) as? [[String: Any]] {
        for item in glucoseData {
          let time = item["time"] as? String ?? "12:00"
          let base = Self.parseDate("\(dateString) \(time)") ?? date
          let values = item["bloodGlucoses"] as? [Any] ?? []
          for (index, raw) in values.enumerated() {
            guard let value = Self.number(raw), value.doubleValue > 0 else { continue }
            let at = Calendar.current.date(byAdding: .minute, value: index, to: base) ?? base
            records.append(record(type: "blood_glucose", values: ["value": value], unit: "mmol/L", at: at))
          }
        }
      }

      if model.ecgType > 0,
         let ecgData = VPDataBaseOperation.veepooSDKGetDeviceOffStoreECG(withDate: dateString, andTableID: tableID) {
        for item in ecgData {
          let values = ecgValues(item)
          guard !values.isEmpty else { continue }
          let itemDate = item.date ?? dateString
          let itemTime = item.testTime ?? "12:00"
          let at = Self.parseDate("\(itemDate) \(itemTime)") ?? date
          records.append(record(type: "ecg", values: values, unit: "", at: at, samples: item.filterSignals.compactMap(Self.number)))
        }
      }

      if model.bodyCompositionType > 0,
         let bodyData = VPDataBaseOperation.veepooSDKGetDeviceOffStoreBodyComposition(withDate: dateString, andTableID: tableID) {
        for item in bodyData {
          let values = bodyCompositionValues(item)
          guard !values.isEmpty else { continue }
          let itemDate = item.date
          let itemTime = item.testTime
          let at = Self.parseDate("\(itemDate) \(itemTime)") ?? date
          records.append(record(type: "body_composition", values: values, unit: "", at: at))
        }
      }

      if model.bloodAnalysisType > 0 {
        let bloodData = VPDataBaseOperation.veepooSDKGetDeviceBloodAnalysisData(withDate: dateString, andTableID: tableID) ?? []
        for item in bloodData {
          let groups: [(String, [String])] = [
            ("uricAcid", item.uricAcids),
            ("totalCholesterol", item.totalCholesterols),
            ("triglycerides", item.triglycerides),
            ("highDensityLipoprotein", item.highDensityLipoproteins),
            ("lowDensityLipoprotein", item.lowDensityLipoproteins),
          ]
          let count = groups.map { $0.1.count }.max() ?? 0
          let base = Self.parseDate("\(dateString) \(item.time)") ?? date
          for index in 0..<count {
            var values: [String: NSNumber] = [:]
            for (key, source) in groups where index < source.count {
              if let value = Self.number(source[index]), value.doubleValue > 0 { values[key] = value }
            }
            guard !values.isEmpty else { continue }
            let at = Calendar.current.date(byAdding: .minute, value: index, to: base) ?? base
            records.append(record(type: "blood_composition", values: values, unit: "", at: at))
          }
        }
      }
    }
    return Dictionary(grouping: records, by: { $0["id"] as? String ?? UUID().uuidString }).compactMap { $0.value.first }
  }

  private func emitRecord(type: String, values: [String: NSNumber], unit: String, samples: [NSNumber] = []) {
    emit("healthRecord", record(type: type, values: values, unit: unit, at: Date(), samples: samples))
  }

  private func record(type: String, values: [String: NSNumber], unit: String, at: Date, samples: [NSNumber] = []) -> [String: Any] {
    let timestamp = Self.isoFormatter.string(from: at)
    let deviceID = connectedRouteID ?? ""
    var payload: [String: Any] = [
      "id": "\(deviceID):\(type):\(timestamp)",
      "type": type,
      "values": values,
      "unit": unit,
      "measuredAt": timestamp,
      "timezone": Self.timezoneOffset(),
      "deviceId": deviceID,
      "firmwareVersion": connected?.deviceVersion ?? "",
      "quality": "device_reported",
      "source": "wearable",
      "rawVersion": 1,
    ]
    if !samples.isEmpty { payload["samples"] = samples }
    return payload
  }

  private func ecgValues(_ model: VPECGTestDataModel) -> [String: NSNumber] {
    var values: [String: NSNumber] = [:]
    if let value = Self.number(model.aveHeart), value.doubleValue > 0 { values["meanHeartRate"] = value }
    if let value = Self.number(model.aveHrv), value.doubleValue > 0 { values["averageHRV"] = value }
    if let value = Self.number(model.aveQT), value.doubleValue > 0 { values["averageTimeInterval"] = value }
    return values
  }

  private func bodyCompositionValues(_ model: VPBodyCompositionValueModel) -> [String: NSNumber] {
    let source: [(String, Any)] = [
      ("BMI", model.bmi),
      ("bodyFatPercentage", model.bodyFatPercentage),
      ("fatMass", model.fatMass),
      ("muscleMass", model.muscleMass),
      ("bodyMoisture", model.bodyMoisture),
      ("boneMass", model.boneMass),
      ("basalMetabolism", model.basalMetabolicRate),
    ]
    return source.reduce(into: [:]) { result, entry in
      if let value = Self.number(entry.1), value.doubleValue > 0 { result[entry.0] = value }
    }
  }

  private func bloodAnalysisValues(_ model: VPBloodAnalysisResultModel) -> [String: NSNumber] {
    let source: [(String, Double)] = [
      ("uricAcid", model.uricAcidValue),
      ("totalCholesterol", model.totalCholesterolValue),
      ("triglycerides", model.triglycerideValue),
      ("highDensityLipoprotein", model.highDensityLipoproteinValue),
      ("lowDensityLipoprotein", model.lowDensityLipoproteinValue),
    ]
    return source.reduce(into: [:]) { result, entry in
      if entry.1 > 0 { result[entry.0] = NSNumber(value: entry.1) }
    }
  }

  private func profileInt(_ key: String, fallback: Int) -> Int {
    if let value = userProfile[key] as? NSNumber { return value.intValue }
    if let value = userProfile[key] as? String, let parsed = Int(value) { return parsed }
    return fallback
  }

  private func deviceDetails(_ device: VPPeripheralModel) -> [String: Any] {
    let deviceName = Self.displayName(device.deviceName)
    return [
      "id": connectedRouteID ?? Self.routeIdentifier(device),
      "name": deviceName,
      "model": deviceName,
      "firmwareVersion": device.deviceVersion ?? "",
      "rssi": device.rssi.intValue,
    ]
  }

  /// CoreBluetooth UUID is the only stable iOS connection key. Veepoo's
  /// `deviceAddress` can be a privacy/BLE address and can change after
  /// authentication, so it must never be presented as the watch's MAC.
  private static func routeIdentifier(_ device: VPPeripheralModel) -> String {
    device.peripheral.identifier.uuidString
  }

  private static func displayName(_ rawName: String?) -> String {
    let withoutControls = (rawName ?? "")
      .components(separatedBy: .controlCharacters)
      .joined()
      .replacingOccurrences(of: "\u{FFFD}", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let cleaned = withoutControls.replacingOccurrences(
      of: "\\s+",
      with: " ",
      options: .regularExpression
    )
    let normalized = cleaned.uppercased().replacingOccurrences(
      of: "[^A-Z0-9]",
      with: "",
      options: .regularExpression
    )
    if normalized.contains("W9S") { return "SD-Watch-W9S" }
    if normalized.contains("W9") { return "SD-Watch-W9" }
    return cleaned.isEmpty ? "未知设备" : cleaned
  }

  private func emit(_ type: String, _ payload: [String: Any]) {
    events?.emit(type: type, payload: payload)
  }

  private static func autoMeasureName(_ type: VPAutoMonitTestType) -> String? {
    switch type {
    case .heartRate: "heartRate"
    case .bloodPressure: "bloodPressure"
    case .bloodGlucose: "bloodGlucose"
    case .bloodOxygen: "bloodOxygen"
    case .bodyTemperature: "bodyTemperature"
    case .stress: "stress"
    case .HRV: "hrv"
    case .bloodComponents: "bloodComponents"
    case .lorentz: nil
    @unknown default: nil
    }
  }

  private static func supportsHeartWarning(_ model: VPPeripheralModel) -> Bool {
    var bytes = [UInt8](repeating: 0, count: max(model.deviceFuctionData.count, 20))
    model.deviceFuctionData.copyBytes(to: &bytes, count: min(model.deviceFuctionData.count, bytes.count))
    return bytes.count > 10 && bytes[10] == 1
  }

  private static func supportsCamera(_ model: VPPeripheralModel) -> Bool {
    var bytes = [UInt8](repeating: 0, count: max(model.deviceFuctionData.count, 20))
    model.deviceFuctionData.copyBytes(to: &bytes, count: min(model.deviceFuctionData.count, bytes.count))
    return bytes.count > 6 && bytes[6] == 1
  }

  private func readNotificationSettings(_ result: @escaping FlutterResult) {
    let entries = Array(Self.notificationTypes)
    var values: [String: Any] = ["supportedKeys": entries.map(\.key)]
    func read(_ index: Int) {
      if index >= entries.count {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          values["notificationAccess"] = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
          DispatchQueue.main.async { result(values) }
        }
        return
      }
      let entry = entries[index]
      manager.peripheralManage.veepooSDKSettingMessageType(entry.value, settingState: .readFunctionState) { state in
        if state == .functionCompleteUnknown {
          if let supported = values["supportedKeys"] as? [String] {
            values["supportedKeys"] = supported.filter { $0 != entry.key }
          }
        } else if state == .functionCompleteFailure {
          result(FlutterError(code: "NOTIFICATION_READ_FAILED", message: "消息通知设置暂时无法读取", details: nil))
          return
        } else {
          values[entry.key] = state == .functionCompleteOpen
        }
        read(index + 1)
      }
    }
    read(0)
  }

  private static let notificationTypes: [(key: String, value: VPSettingMessageSwitchType)] = [
    ("incomingCall", .settingCall),
    ("sms", .settingSMS),
    ("wechat", .settingWechat),
    ("qq", .settingQQ),
    ("whatsapp", .settingwhatsapp),
    ("dingtalk", .settingDingTalk),
    ("wecom", .settingWeChatWork),
    ("tiktok", .settingOtherTikTok),
    ("telegram", .settingOtherTelegram),
    ("otherApps", .settingOtherPlatform),
  ]

  private func readScreenSettings(_ result: @escaping FlutterResult) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    var payload: [String: Any] = [
      "brightness": 1,
      "maximumBrightness": 1,
      "automaticBrightness": false,
      "raiseToWakeEnabled": false,
      "raiseToWakeSupported": Self.supportsRaiseHand(model),
      "raiseToWakeCustomTimeSupported": Self.supportsRaiseHand(model),
    ]
    func readRaiseHand() {
      guard Self.supportsRaiseHand(model) else {
        result(payload)
        return
      }
      manager.peripheralManage.veepooSDKSettingRaiseHand(
        with: VPDeviceRaiseHandModel(),
        settingMode: 2,
        successResult: { [weak self] value in
          guard let value else {
            result(FlutterError(code: "SCREEN_READ_FAILED", message: "抬腕亮屏设置暂时无法读取", details: nil))
            return
          }
          self?.screenRaiseHandModel = value
          payload["raiseToWakeEnabled"] = value.raiseHandState > 0
          payload["raiseToWakeStartMinutes"] = Int(value.raiseHandStartHour * 60 + value.raiseHandStartMinute)
          payload["raiseToWakeEndMinutes"] = Int(value.raiseHandEndHour * 60 + value.raiseHandEndMinute)
          payload["raiseToWakeSensitivity"] = Int(value.sensitive)
          payload["raiseToWakeCustomTimeSupported"] = value.defaultSensitive > 0
          result(payload)
        },
        failureResult: {
          result(FlutterError(code: "SCREEN_READ_FAILED", message: "抬腕亮屏设置暂时无法读取", details: nil))
        }
      )
    }
    func readDuration() {
      guard model.screenDurationType > 0 else {
        readRaiseHand()
        return
      }
      manager.peripheralManage.veepooSDKSettingScreenDuration(
        VPScreenDurationModel(),
        settingMode: 2,
        successResult: { [weak self] value in
          guard let value else {
            result(FlutterError(code: "SCREEN_READ_FAILED", message: "亮屏时长暂时无法读取", details: nil))
            return
          }
          self?.screenDurationModel = value
          payload["durationSeconds"] = value.currentDuration
          payload["minimumDurationSeconds"] = value.minDuration
          payload["maximumDurationSeconds"] = value.maxDuration
          readRaiseHand()
        },
        failureResult: {
          result(FlutterError(code: "SCREEN_READ_FAILED", message: "亮屏时长暂时无法读取", details: nil))
        }
      )
    }
    guard Self.supportsBrightness(model) else {
      readDuration()
      return
    }
    manager.peripheralManage.veepooSDKSettingBright(
      with: VPDeviceBrightModel(),
      settingMode: 2,
      successResult: { [weak self] value in
        guard let value else {
          result(FlutterError(code: "SCREEN_READ_FAILED", message: "屏幕亮度暂时无法读取", details: nil))
          return
        }
        self?.screenBrightModel = value
        payload["brightness"] = value.otherBrightValue
        payload["maximumBrightness"] = max(value.maxBrightValue, 1)
        payload["automaticBrightness"] = value.isAutomatic
        readDuration()
      },
      failureResult: {
        result(FlutterError(code: "SCREEN_READ_FAILED", message: "屏幕亮度暂时无法读取", details: nil))
      }
    )
  }

  private func writeScreenSettings(_ values: [String: Any], result: @escaping FlutterResult) {
    guard let model = connected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "请先连接赛电设备", details: nil))
      return
    }
    func writeRaiseHand() {
      guard Self.supportsRaiseHand(model) else {
        result(nil)
        return
      }
      let start = (values["raiseToWakeStartMinutes"] as? NSNumber)?.intValue ?? 0
      let end = (values["raiseToWakeEndMinutes"] as? NSNumber)?.intValue ?? 1439
      let enabled = values["raiseToWakeEnabled"] as? Bool ?? false
      let sensitivity = (values["raiseToWakeSensitivity"] as? NSNumber)?.intValue ?? Int(screenRaiseHandModel?.sensitive ?? 0)
      let setting = VPDeviceRaiseHandModel(
        raiseHandStartHour: UInt(start / 60),
        raiseHandStartMinute: UInt(start % 60),
        raiseHandEndHour: UInt(end / 60),
        raiseHandEndMinute: UInt(end % 60),
        raiseHandState: enabled ? 1 : 0,
        raiseHandSensitive: UInt(max(sensitivity, 0))
      )
      manager.peripheralManage.veepooSDKSettingRaiseHand(
        with: setting,
        settingMode: enabled ? 1 : 0,
        successResult: { [weak self] value in self?.screenRaiseHandModel = value; result(nil) },
        failureResult: { result(FlutterError(code: "SCREEN_WRITE_FAILED", message: "抬腕亮屏设置保存失败", details: nil)) }
      )
    }
    func writeDuration() {
      guard model.screenDurationType > 0, let setting = screenDurationModel,
            let requested = (values["durationSeconds"] as? NSNumber)?.intValue else {
        writeRaiseHand()
        return
      }
      setting.currentDuration = WearablePayloadMapper.clamp(requested, minimum: setting.minDuration, maximum: setting.maxDuration)
      manager.peripheralManage.veepooSDKSettingScreenDuration(
        setting,
        settingMode: 1,
        successResult: { [weak self] value in self?.screenDurationModel = value; writeRaiseHand() },
        failureResult: { result(FlutterError(code: "SCREEN_WRITE_FAILED", message: "亮屏时长保存失败", details: nil)) }
      )
    }
    guard Self.supportsBrightness(model), let setting = screenBrightModel else {
      writeDuration()
      return
    }
    let maximum = max(setting.maxBrightValue, 1)
    let requested = (values["brightness"] as? NSNumber)?.intValue ?? setting.otherBrightValue
    setting.otherBrightValue = WearablePayloadMapper.clamp(requested, minimum: 1, maximum: maximum)
    setting.firstBrightValue = min(setting.firstBrightValue, maximum)
    setting.isAutomatic = values["automaticBrightness"] as? Bool ?? setting.isAutomatic
    manager.peripheralManage.veepooSDKSettingBright(
      with: setting,
      settingMode: 1,
      successResult: { [weak self] value in self?.screenBrightModel = value; writeDuration() },
      failureResult: { result(FlutterError(code: "SCREEN_WRITE_FAILED", message: "屏幕亮度保存失败", details: nil)) }
    )
  }

  private static func functionBytes(_ model: VPPeripheralModel) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: max(model.deviceFuctionData.count, 20))
    model.deviceFuctionData.copyBytes(to: &bytes, count: min(model.deviceFuctionData.count, bytes.count))
    return bytes
  }

  private static func supportsRaiseHand(_ model: VPPeripheralModel) -> Bool {
    let bytes = functionBytes(model)
    return bytes.count > 11 && bytes[11] == 1
  }

  private static func supportsBrightness(_ model: VPPeripheralModel) -> Bool {
    let bytes = functionBytes(model)
    return bytes.count > 13 && bytes[13] == 1
  }

  private static func supportsLongSeat(_ model: VPPeripheralModel) -> Bool {
    let bytes = functionBytes(model)
    return bytes.count > 3 && bytes[3] == 1
  }

  private enum AlarmKind {
    case standard
    case text
  }

  private static func alarmKind(_ model: VPPeripheralModel) -> AlarmKind? {
    let bytes = functionBytes(model)
    guard bytes.count > 17 else { return nil }
    switch bytes[17] {
    case 1...4: return .standard
    case 5...6: return .text
    default: return nil
    }
  }

  private func readLongSeat(_ result: @escaping FlutterResult) {
    guard let model = connected, Self.supportsLongSeat(model) else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持久坐提醒", details: nil))
      return
    }
    manager.peripheralManage.veepooSDKSettingDeviceLongSeat(
      with: VPDeviceLongSeatModel(),
      settingMode: 2,
      successResult: { value in
        guard let value else {
          result(FlutterError(code: "REMINDER_READ_FAILED", message: "健康提醒暂时无法读取", details: nil))
          return
        }
        result(["items": [[
          "id": "sedentary",
          "label": "久坐提醒",
          "enabled": value.longSeatState > 0,
          "startMinutes": Int(value.longSeatStartHour * 60 + value.longSeatStartMinute),
          "endMinutes": Int(value.longSeatEndHour * 60 + value.longSeatEndMinute),
          "intervalMinutes": Int(value.longSeatGateValue),
        ]]])
      },
      failureResult: { result(FlutterError(code: "REMINDER_READ_FAILED", message: "健康提醒暂时无法读取", details: nil)) }
    )
  }

  private func writeLongSeat(_ values: [String: Any], result: @escaping FlutterResult) {
    guard let device = connected, Self.supportsLongSeat(device) else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持久坐提醒", details: nil))
      return
    }
    let start = (values["startMinutes"] as? NSNumber)?.intValue ?? 480
    let end = (values["endMinutes"] as? NSNumber)?.intValue ?? 1320
    let interval = WearablePayloadMapper.clamp((values["intervalMinutes"] as? NSNumber)?.intValue ?? 60, minimum: 30, maximum: 240)
    guard end > start, end - start > interval else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "结束时间必须晚于开始时间，并大于提醒间隔", details: nil))
      return
    }
    let enabled = values["enabled"] as? Bool ?? false
    let model = VPDeviceLongSeatModel(
      longSeatStartHour: UInt(start / 60),
      longSeatStartMinute: UInt(start % 60),
      longSeatEndHour: UInt(end / 60),
      longSeatEndMinute: UInt(end % 60),
      longSeatGateValue: UInt(interval),
      longSeatState: enabled ? 1 : 0
    )
    manager.peripheralManage.veepooSDKSettingDeviceLongSeat(
      with: model,
      settingMode: enabled ? 1 : 0,
      successResult: { _ in result(nil) },
      failureResult: { result(FlutterError(code: "REMINDER_WRITE_FAILED", message: "健康提醒保存失败", details: nil)) }
    )
  }

  private func readWorldClocks(_ result: @escaping FlutterResult) {
    guard connected?.worldClockType ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持世界时钟", details: nil))
      return
    }
    manager.peripheralManage.veepooSDKWorldClockRead(with: worldClockModels) { [weak self] success, models in
      guard let self else { return }
      guard success else {
        result(FlutterError(code: "WORLD_CLOCK_READ_FAILED", message: "世界时钟暂时无法读取", details: nil))
        return
      }
      self.worldClockModels = models ?? []
      result(["items": self.worldClockModels.map(Self.worldClockPayload)])
    }
  }

  private func writeWorldClock(_ values: [String: Any], result: @escaping FlutterResult) {
    guard connected?.worldClockType ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持世界时钟", details: nil))
      return
    }
    let operation = values["operation"] as? String ?? "add"
    if operation == "delete" {
      let id = (values["id"] as? NSNumber)?.intValue ?? Int(values["id"] as? String ?? "") ?? 0
      guard (1...10).contains(id) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "世界时钟编号无效", details: nil))
        return
      }
      manager.peripheralManage.veepooSDKWorldClockDelete(withID: UInt8(id)) { [weak self] success in
        if success {
          self?.worldClockModels.removeAll { $0.dataID == UInt8(id) }
          result(nil)
        } else {
          result(FlutterError(code: "WORLD_CLOCK_WRITE_FAILED", message: "世界时钟删除失败", details: nil))
        }
      }
      return
    }
    guard worldClockModels.count < 10 else {
      result(FlutterError(code: "WORLD_CLOCK_FULL", message: "世界时钟已满", details: nil))
      return
    }
    let city = WearablePayloadMapper.safeLabel(values["city"] as? String ?? "", limit: 18)
    guard !city.isEmpty else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "城市名称不能为空", details: nil))
      return
    }
    let offset = (values["utcOffsetMinutes"] as? NSNumber)?.intValue ?? 0
    guard offset % 15 == 0, (-720...840).contains(offset) else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "时区必须是 15 分钟的整数倍", details: nil))
      return
    }
    let model = VPWorldClockModel()
    model.cityName = city
    model.dataID = UInt8((1...10).first { id in !worldClockModels.contains { $0.dataID == UInt8(id) } } ?? 1)
    model.standardTimeZoneDiffer = NSNumber(value: Int8(offset / 15))
    manager.peripheralManage.veepooSDKWorldClockAdd(with: model) { [weak self] success in
      if success {
        self?.worldClockModels.append(model)
        result(nil)
      } else {
        result(FlutterError(code: "WORLD_CLOCK_WRITE_FAILED", message: "世界时钟添加失败", details: nil))
      }
    }
  }

  private static func worldClockPayload(_ model: VPWorldClockModel) -> [String: Any] {
    [
      "id": Int(model.dataID),
      "city": model.cityName,
      "utcOffsetMinutes": model.standardTimeZoneDiffer.intValue * 15,
    ]
  }

  private func readContacts(_ result: @escaping FlutterResult) {
    guard connected?.contactType ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持联系人", details: nil))
      return
    }
    manager.peripheralManage.veepooSDKSettingDeviceContacts(with: .read, opModel: VPDeviceContactsModel(), toID: 0) { state, models in
      switch state {
      case .complete:
        result(["items": (models ?? []).map(Self.contactPayload)])
      case .noFunction:
        result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持联系人", details: nil))
      case .failure:
        result(FlutterError(code: "CONTACT_READ_FAILED", message: "联系人暂时无法读取", details: nil))
      case .reading:
        break
      @unknown default:
        result(FlutterError(code: "CONTACT_READ_FAILED", message: "联系人暂时无法读取", details: nil))
      }
    }
  }

  private func writeContact(_ values: [String: Any], result: @escaping FlutterResult) {
    guard connected?.contactType ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持联系人", details: nil))
      return
    }
    let operation = values["operation"] as? String ?? "add"
    let model = VPDeviceContactsModel()
    let contactID = (values["id"] as? NSNumber)?.intValue ?? Int(values["id"] as? String ?? "") ?? 0
    model.contactID = Int32(clamping: contactID)
    model.nickName = WearablePayloadMapper.safeLabel(values["name"] as? String ?? "", limit: 20)
    model.phoneNumber = (values["phone"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    model.isSOS = values["isEmergency"] as? Bool ?? false
    let code: VPDeviceContactsOpCode
    switch operation {
    case "delete":
      guard model.contactID > 0 else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "联系人编号无效", details: nil))
        return
      }
      code = .delete
    case "emergency":
      guard model.contactID > 0 else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "联系人编号无效", details: nil))
        return
      }
      code = .edit
    default:
      guard !model.nickName.isEmpty, !model.phoneNumber.isEmpty else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "联系人姓名和电话不能为空", details: nil))
        return
      }
      code = .add
    }
    manager.peripheralManage.veepooSDKSettingDeviceContacts(with: code, opModel: model, toID: 0) { state, _ in
      switch state {
      case .complete: result(nil)
      case .noFunction: result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持联系人", details: nil))
      case .failure: result(FlutterError(code: "CONTACT_WRITE_FAILED", message: "联系人保存失败", details: nil))
      case .reading: break
      @unknown default: result(FlutterError(code: "CONTACT_WRITE_FAILED", message: "联系人保存失败", details: nil))
      }
    }
  }

  private static func contactPayload(_ model: VPDeviceContactsModel) -> [String: Any] {
    [
      "id": model.contactID,
      "name": model.nickName,
      "phone": model.phoneNumber,
      "isEmergency": model.isSOS,
      "supportsEmergency": true,
    ]
  }

  private func readAlarms(_ result: @escaping FlutterResult) {
    guard let device = connected, let kind = Self.alarmKind(device) else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持可管理闹钟", details: nil))
      return
    }
    switch kind {
    case .standard:
      manager.peripheralManage.veepooSDKSettingDeviceNewAlarm(
        with: VPDeviceNewAlarmModel(),
        settingMode: 2,
        successResult: { alarms in
          result(["items": (alarms as? [VPDeviceNewAlarmModel] ?? []).map(Self.standardAlarmPayload)])
        },
        failureResult: {
          result(FlutterError(code: "ALARM_READ_FAILED", message: "闹钟暂时无法读取", details: nil))
        }
      )
    case .text:
      manager.peripheralManage.veepooSDKSettingDeviceTextAlarm(
        with: VPDeviceTextAlarmModel(),
        settingMode: .read,
        successResult: { alarms in
          result(["items": (alarms as? [VPDeviceTextAlarmModel] ?? []).map(Self.textAlarmPayload)])
        },
        failureResult: {
          result(FlutterError(code: "ALARM_READ_FAILED", message: "闹钟暂时无法读取", details: nil))
        }
      )
    }
  }

  private func writeAlarm(_ values: [String: Any], result: @escaping FlutterResult) {
    guard let device = connected, let kind = Self.alarmKind(device) else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持可管理闹钟", details: nil))
      return
    }
    let operation = values["operation"] as? String ?? "add"
    let hour = WearablePayloadMapper.clamp((values["hour"] as? NSNumber)?.intValue ?? 8, minimum: 0, maximum: 23)
    let minute = WearablePayloadMapper.clamp((values["minute"] as? NSNumber)?.intValue ?? 0, minimum: 0, maximum: 59)
    let days = Set((values["repeatDays"] as? [NSNumber] ?? []).map(\.intValue))
    let repeatState = String(WearablePayloadMapper.repeatMask(days: days))
    let alarmID = values["id"] as? String ?? (values["id"] as? NSNumber)?.stringValue
    if operation != "add", alarmID?.isEmpty != false {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "闹钟编号无效", details: nil))
      return
    }

    switch kind {
    case .standard:
      let model = VPDeviceNewAlarmModel()
      model.alarmID = alarmID ?? model.alarmID
      model.alarmHour = String(format: "%02d", hour)
      model.alarmMinute = String(format: "%02d", minute)
      model.alarmState = (values["enabled"] as? Bool ?? true) ? "1" : "0"
      model.repeatState = repeatState
      model.alarmScene = values["scene"] as? String ?? "0"
      model.alarmDate = days.isEmpty ? Self.nextAlarmDate(hour: hour, minute: minute) : "0000-00-00"
      manager.peripheralManage.veepooSDKSettingDeviceNewAlarm(
        with: model,
        settingMode: operation == "delete" ? 0 : 1,
        successResult: { _ in result(nil) },
        failureResult: {
          result(FlutterError(code: "ALARM_WRITE_FAILED", message: operation == "delete" ? "闹钟删除失败" : "闹钟保存失败", details: nil))
        }
      )
    case .text:
      let model = VPDeviceTextAlarmModel()
      model.alarmID = alarmID ?? model.alarmID
      model.alarmHour = String(format: "%02d", hour)
      model.alarmMinute = String(format: "%02d", minute)
      model.alarmState = (values["enabled"] as? Bool ?? true) ? "1" : "0"
      model.repeatState = repeatState
      model.alarmText = WearablePayloadMapper.safeLabel(values["label"] as? String ?? "闹钟", limit: 60)
      manager.peripheralManage.veepooSDKSettingDeviceTextAlarm(
        with: model,
        settingMode: operation == "delete" ? .delete : .addOrChange,
        successResult: { _ in result(nil) },
        failureResult: {
          result(FlutterError(code: "ALARM_WRITE_FAILED", message: operation == "delete" ? "闹钟删除失败" : "闹钟保存失败", details: nil))
        }
      )
    }
  }

  private static func standardAlarmPayload(_ model: VPDeviceNewAlarmModel) -> [String: Any] {
    let mask = UInt8(model.repeatState) ?? 0
    return [
      "id": model.alarmID ?? "",
      "hour": Int(model.alarmHour) ?? 0,
      "minute": Int(model.alarmMinute) ?? 0,
      "enabled": model.alarmState == "1",
      "label": "闹钟",
      "repeatDays": WearablePayloadMapper.repeatDays(mask: mask),
      "scene": model.alarmScene ?? "",
      "date": model.alarmDate ?? "",
    ]
  }

  private static func textAlarmPayload(_ model: VPDeviceTextAlarmModel) -> [String: Any] {
    let mask = UInt8(model.repeatState) ?? 0
    return [
      "id": model.alarmID,
      "hour": Int(model.alarmHour) ?? 0,
      "minute": Int(model.alarmMinute) ?? 0,
      "enabled": model.alarmState == "1",
      "label": model.alarmText,
      "repeatDays": WearablePayloadMapper.repeatDays(mask: mask),
    ]
  }

  private static func nextAlarmDate(hour: Int, minute: Int) -> String {
    let calendar = Calendar.current
    let now = Date()
    let candidate = calendar.nextDate(
      after: now,
      matching: DateComponents(hour: hour, minute: minute),
      matchingPolicy: .nextTime
    ) ?? calendar.date(byAdding: .day, value: 1, to: now) ?? now
    return dayFormatter.string(from: candidate)
  }

  private func readWeather(_ result: @escaping FlutterResult) {
    guard connected?.weatherType ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持天气", details: nil))
      return
    }
    VPWeatherHandle.share().readWeatherInfo { [weak self] state, config in
      guard let self else { return }
      guard state == .success, let config else {
        result(FlutterError(code: "WEATHER_READ_FAILED", message: "天气设置暂时无法读取", details: nil))
        return
      }
      self.weatherConfigModel = config
      let cached = VPWeatherServerModel.lastSave()
      result([
        "enabled": config.switchState == 1,
        "useCelsius": config.weatherUnit == 0,
        "city": cached.city,
        "updatedAt": Self.weatherTimestamp(cached.update),
      ])
    }
  }

  private func writeWeather(_ values: [String: Any], result: @escaping FlutterResult) {
    guard connected?.weatherType ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持天气", details: nil))
      return
    }
    let config = weatherConfigModel ?? VPWeatherConfigModel()
    config.switchState = (values["enabled"] as? Bool ?? true) ? 1 : 0
    config.weatherUnit = (values["useCelsius"] as? Bool ?? true) ? 0 : 1
    VPWeatherHandle.share().settingWeatherInfo(config) { [weak self] state in
      guard let self else { return }
      guard state == .success else {
        result(FlutterError(code: "WEATHER_WRITE_FAILED", message: "天气设置保存失败", details: nil))
        return
      }
      self.weatherConfigModel = config
      guard values["operation"] as? String == "sync" else {
        result(nil)
        return
      }
      guard let server = Self.weatherServerModel(values) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "天气数据不完整", details: nil))
        return
      }
      guard server.weatherValid(withWeatherType: Int32(self.connected?.weatherType ?? 0)) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "天气数据与当前手表不兼容", details: nil))
        return
      }
      VPWeatherHandle.share().syncWeatherDataToDevice(with: server) { state in
        if state == .success {
          server.save()
          result(nil)
        } else {
          result(FlutterError(code: "WEATHER_SYNC_FAILED", message: "天气同步到手表失败", details: nil))
        }
      }
    }
  }

  private static func weatherServerModel(_ values: [String: Any]) -> VPWeatherServerModel? {
    let city = (values["city"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let hourlyValues = values["hourly"] as? [[String: Any]] ?? []
    let dailyValues = values["daily"] as? [[String: Any]] ?? []
    guard !city.isEmpty, !hourlyValues.isEmpty, !dailyValues.isEmpty else { return nil }
    let server = VPWeatherServerModel()
    server.city = WearablePayloadMapper.safeLabel(city, limit: 30)
    server.update = weatherDateTimeFormatter.string(from: weatherDate(values["updatedAt"]))
    server.type = 1
    server.hourly = hourlyValues.prefix(24).map { item in
      let model = VPWeatherServerHourlyModel()
      model.time = weatherDateTimeFormatter.string(from: weatherDate(item["time"]))
      model.temp = WearablePayloadMapper.fahrenheit(celsius: number(item["temperatureC"])?.doubleValue ?? 0)
      model.uvi = number(item["uvIndex"]) ?? 0
      model.code = number(item["weatherCode"])?.int32Value ?? 0
      model.wind_sc = item["windLevel"] as? String ?? "0"
      model.vis = NSNumber(value: (number(item["visibilityMeters"])?.doubleValue ?? 0) / 1_000)
      return model
    }
    server.forecast = dailyValues.prefix(7).map { item in
      let model = VPWeatherServerForecastModel()
      model.date = dayFormatter.string(from: weatherDate(item["time"]))
      model.maxTemp = WearablePayloadMapper.fahrenheit(celsius: number(item["maximumC"])?.doubleValue ?? 0)
      model.minTemp = WearablePayloadMapper.fahrenheit(celsius: number(item["minimumC"])?.doubleValue ?? 0)
      model.uvi = number(item["uvIndex"]) ?? 0
      model.dayCode = number(item["dayWeatherCode"]) ?? 0
      model.nightCode = number(item["nightWeatherCode"]) ?? 0
      model.wind_sc = item["windLevel"] as? String ?? "0"
      model.vis = NSNumber(value: (number(item["visibilityMeters"])?.doubleValue ?? 0) / 1_000)
      return model
    }
    return server
  }

  private static func weatherDate(_ value: Any?) -> Date {
    let milliseconds = number(value)?.doubleValue ?? Date().timeIntervalSince1970 * 1_000
    return Date(timeIntervalSince1970: milliseconds / 1_000)
  }

  private static func weatherTimestamp(_ value: String?) -> Int64 {
    guard let value, let date = weatherDateTimeFormatter.date(from: value) else { return 0 }
    return Int64(date.timeIntervalSince1970 * 1_000)
  }

  private func readHealthAssessment(_ result: @escaping FlutterResult) {
    guard let device = connected, device.funcAssessmentType.rawValue > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持辅助评估设置", details: nil))
      return
    }
    manager.peripheralManage.veepooSDK_readFuncAssessment { models in
      guard let models else {
        result(FlutterError(code: "ASSESSMENT_READ_FAILED", message: "辅助评估设置暂时无法读取", details: nil))
        return
      }
      result(["items": models.compactMap(Self.healthAssessmentPayload)])
    }
  }

  private func writeHealthAssessment(_ values: [String: Any], result: @escaping FlutterResult) {
    guard let device = connected, device.funcAssessmentType.rawValue > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持辅助评估设置", details: nil))
      return
    }
    guard let type = Self.healthAssessmentType(values["id"] as? String ?? "") else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "辅助评估类型无效", details: nil))
      return
    }
    manager.peripheralManage.veepooSDK_setFuncAssessment(
      with: type,
      open: values["enabled"] as? Bool ?? false
    ) { success in
      success ? result(nil) : result(FlutterError(code: "ASSESSMENT_WRITE_FAILED", message: "辅助评估设置保存失败", details: nil))
    }
  }

  private static func healthAssessmentPayload(_ model: VPHealthFunctionModel) -> [String: Any]? {
    guard model.support else { return nil }
    let value: (String, String)? = switch model.type {
    case .bloodGlucose: ("blood_glucose", "血糖辅助评估")
    case .bloodComp: ("blood_composition", "血液成分辅助评估")
    case .bodyComp: ("body_composition", "身体成分辅助评估")
    default: nil
    }
    guard let value else { return nil }
    return ["id": value.0, "label": value.1, "enabled": model.open]
  }

  private static func healthAssessmentType(_ value: String) -> VPFuncAssessmentType? {
    switch value {
    case "blood_glucose": .bloodGlucose
    case "blood_composition": .bloodComp
    case "body_composition": .bodyComp
    default: nil
    }
  }

  private func readPhoneCalls(_ result: @escaping FlutterResult) {
    guard connected?.deviceBTInfoData.count ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持蓝牙通话", details: nil))
      return
    }
    result(phoneCallState)
  }

  private func writePhoneCalls(_ values: [String: Any], result: @escaping FlutterResult) {
    guard connected?.deviceBTInfoData.count ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持蓝牙通话", details: nil))
      return
    }
    guard values["enabled"] as? Bool == true else {
      result(FlutterError(code: "FEATURE_UNAVAILABLE", message: "请在手表或手机蓝牙设置中断开通话连接", details: nil))
      return
    }
    phoneCallState["connectionStatus"] = "broadcasting"
    manager.peripheralManage.veepooSDK_openDeviceBTSwitch()
    result(nil)
  }

  private func readWatchFaces(_ result: @escaping FlutterResult) {
    guard let device = connected, device.dialCount > 0 || device.marketDialCount > 0 || device.photoDialCount > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持表盘管理", details: nil))
      return
    }
    manager.peripheralManage.veepooSDKSettingDeviceScreenStyle(
      0,
      settingMode: 2,
      dialType: .default
    ) { dialType, style, success in
      guard success else {
        result(FlutterError(code: "WATCH_FACE_READ_FAILED", message: "表盘信息暂时无法读取", details: nil))
        return
      }
      result(["items": WearablePayloadMapper.watchFaceEntries(
        defaultCount: Int(device.dialCount),
        marketCount: Int(device.marketDialCount),
        photoCount: Int(device.photoDialCount),
        currentType: Int(dialType.rawValue),
        currentStyle: Int(style)
      )])
    }
  }

  private func switchWatchFace(_ values: [String: Any], result: @escaping FlutterResult) {
    guard connected != nil, values["operation"] as? String == "switch" else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "表盘切换参数无效", details: nil))
      return
    }
    let type: VPDeviceDialType
    switch values["type"] as? String {
    case "default": type = .default
    case "market": type = .market
    case "photo": type = .photo
    default:
      result(FlutterError(code: "INVALID_ARGUMENT", message: "表盘类型无效", details: nil))
      return
    }
    let index = (values["index"] as? NSNumber)?.int32Value ?? (type == .default ? 0 : 1)
    manager.peripheralManage.veepooSDKSettingDeviceScreenStyle(
      index,
      settingMode: 1,
      dialType: type
    ) { _, _, success in
      success ? result(nil) : result(FlutterError(code: "WATCH_FACE_SWITCH_FAILED", message: "表盘切换失败", details: nil))
    }
  }

  private func readPhotoWatchFace(_ result: @escaping FlutterResult) {
    guard connected?.photoDialCount ?? 0 > 0 else {
      result(FlutterError(code: "FEATURE_UNSUPPORTED", message: "当前手表不支持照片表盘", details: nil))
      return
    }
    manager.peripheralManage.veepooSDK_dialChannel(
      with: .read,
      dialType: .photo,
      photoDialModel: nil,
      result: { [weak self] model, _, error in
        guard let self else { return }
        guard error == nil, let model else {
          result(FlutterError(code: "PHOTO_WATCH_FACE_READ_FAILED", message: "照片表盘信息暂时无法读取", details: error?.localizedDescription))
          return
        }
        self.photoDialModel = model
        result([
          "ready": true,
          "width": Int(model.configModel.screenSize.width),
          "height": Int(model.configModel.screenSize.height),
          "isCircle": model.configModel.isCircle,
        ])
      },
      transformProgress: nil
    )
  }

  private func uploadPhotoWatchFace(_ values: [String: Any], result: @escaping FlutterResult) {
    guard connected?.photoDialCount ?? 0 > 0,
          values["operation"] as? String == "upload_photo",
          let url = WearablePayloadMapper.localFileURL(values["imagePath"] as? String ?? ""),
          FileManager.default.fileExists(atPath: url.path),
          let source = UIImage(contentsOfFile: url.path) else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "请选择有效的表盘照片", details: nil))
      return
    }
    func upload(_ model: VPPhotoDialModel) {
      guard model.configModel.screenSize.width > 0, model.configModel.screenSize.height > 0 else {
        result(FlutterError(code: "PHOTO_WATCH_FACE_UNSUPPORTED", message: "SDK 尚未适配当前手表屏幕", details: nil))
        return
      }
      model.isDefaultBG = false
      model.transformImage = Self.aspectFill(source, size: model.configModel.screenSize)
      var finished = false
      func finish(_ error: FlutterError?) {
        guard !finished else { return }
        finished = true
        result(error)
      }
      self.manager.peripheralManage.veepooSDK_dialChannel(
        with: .setupPhotoDial,
        dialType: .photo,
        photoDialModel: model,
        result: { _, _, error in
          if let error {
            finish(FlutterError(code: "PHOTO_WATCH_FACE_UPLOAD_FAILED", message: "照片表盘传输失败", details: error.localizedDescription))
          } else {
            finish(nil)
          }
        },
        transformProgress: { [weak self] progress in
          let percentage = WearablePayloadMapper.progress(completed: Int((progress * 1_000).rounded()), total: 1_000)
          self?.emit("deviceFeatureProgress", ["feature": "photo_watch_face", "progress": percentage])
          if progress >= 0.999 { finish(nil) }
        }
      )
    }
    if let model = photoDialModel {
      upload(model)
      return
    }
    manager.peripheralManage.veepooSDK_dialChannel(
      with: .read,
      dialType: .photo,
      photoDialModel: nil,
      result: { [weak self] model, _, error in
        guard let self else { return }
        guard error == nil, let model else {
          result(FlutterError(code: "PHOTO_WATCH_FACE_READ_FAILED", message: "照片表盘信息暂时无法读取", details: error?.localizedDescription))
          return
        }
        self.photoDialModel = model
        upload(model)
      },
      transformProgress: nil
    )
  }

  private static func aspectFill(_ image: UIImage, size: CGSize) -> UIImage {
    let sourceSize = image.size
    let scale = max(size.width / max(sourceSize.width, 1), size.height / max(sourceSize.height, 1))
    let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: origin, size: drawSize))
    }
  }

  private static func number(_ value: Any?) -> NSNumber? {
    if let number = value as? NSNumber { return number }
    if let string = value as? String, let number = Double(string) { return NSNumber(value: number) }
    return nil
  }

  private static func parseDate(_ value: String) -> Date? {
    for formatter in dateTimeFormatters {
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }

  private static func timezoneOffset() -> String {
    let seconds = TimeZone.current.secondsFromGMT()
    return String(format: "%+03d:%02d", seconds / 3600, abs(seconds / 60) % 60)
  }

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let weatherDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
  }()

  private static let dateTimeFormatters: [DateFormatter] = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm"].map {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = $0
    return formatter
  }
}
#endif

private final class WearableStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func emit(type: String, payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(["type": type, "payload": payload])
    }
  }
}
