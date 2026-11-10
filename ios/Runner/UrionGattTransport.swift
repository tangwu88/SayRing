import CoreBluetooth
import Flutter
import Foundation

/// CoreBluetooth transports verified EB1 advertisements and 16-byte frames.
/// All health interpretation is shared with Android in Dart.
final class UrionGattTransport: NSObject, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
  private let serviceID = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
  private let writeID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
  private let notifyID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
  private let infoID = CBUUID(string: "180A")
  private let firmwareID = CBUUID(string: "2A26")
  private let hardwareID = CBUUID(string: "2A27")
  private lazy var central = CBCentralManager(delegate: self, queue: .main)
  private var sink: FlutterEventSink?
  private var devices: [String: CBPeripheral] = [:]
  private var descriptions: [String: [String: Any]] = [:]
  private var active: CBPeripheral?
  private var retiring: [UUID: CBPeripheral] = [:]
  private var retirementWaiters: [(Bool) -> Void] = []
  private var retirementTimer: Timer?
  private var nativeID: String?
  private var writer: CBCharacteristic?
  private var notify: CBCharacteristic?
  private var pendingScan: FlutterResult?
  private var pendingConnect: FlutterResult?
  private var pendingWrite: FlutterResult?
  private var scanTimer: Timer?
  private var firmware: String?
  private var hardware: String?
  private var generation = 0
  private var retriedFullServiceDiscovery = false
  private var readMetrics = Set<String>()
  private var manualMetrics = Set<String>()
  private var healthExpiresAt: TimeInterval = 0
  private let cachePrefix = "sayring.u19.verified."

  // 仅发送连接阶段和系统错误码；不包含设备标识、账号或健康原始包。
  private func connectionPhase(_ phase: String, error: Error? = nil) {
    var payload: [String: Any] = ["phase": phase]
    if let error { payload["code"] = (error as NSError).code }
    sink?(["type": "connectionPhase", "payload": payload])
  }

  // 独立的单调时钟许可。新的血压目录不扩大原有戒指协议目录。
  private func configureHealth(_ args: [String: Any]?, result: FlutterResult) {
    let ceiling: Set<String> = ["blood_pressure", "heart_rate", "blood_oxygen"]
    guard let args, let reads = args["readMetrics"] as? [String],
      let manual = args["manualMetrics"] as? [String],
      let seconds = args["validForSeconds"] as? Int,
      seconds >= 0, seconds <= 300,
      ceiling.isSuperset(of: reads), Set(reads).isSuperset(of: manual),
      seconds > 0 || (reads.isEmpty && manual.isEmpty) else {
      result(FlutterError(code: "INVALID_U19_POLICY", message: "Invalid device configuration", details: nil)); return
    }
    readMetrics = Set(reads); manualMetrics = Set(manual)
    healthExpiresAt = ProcessInfo.processInfo.systemUptime + Double(seconds)
    result(nil)
  }
  private func allowsHealthCommand(_ command: UInt8) -> Bool {
    let metric: String
    switch command {
    case 0x14, 0x32: metric = "blood_pressure"
    case 0x15, 0x38: metric = "heart_rate"
    case 0x2d, 0x39: metric = "blood_oxygen"
    default: return true
    }
    guard ProcessInfo.processInfo.systemUptime < healthExpiresAt, readMetrics.contains(metric) else { return false }
    return ![UInt8(0x32), 0x38, 0x39].contains(command) || manualMetrics.contains(metric)
  }


  override init() {
    super.init()
    _ = central
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configureHealthPolicy":
      configureHealth(call.arguments as? [String: Any], result: result)
    case "rememberVerifiedDevice":
      guard let id = nativeID, let peripheral = active,
        let args = call.arguments as? [String: Any], args["deviceId"] as? String == id,
        let description = descriptions[id], writer != nil, notify != nil else { result(nil); return }
      UserDefaults.standard.set(["uuid": peripheral.identifier.uuidString, "description": description], forKey: cachePrefix + id)
      result(nil)
    case "prepareRememberedDevice":
      guard let args = call.arguments as? [String: Any], let id = args["deviceId"] as? String,
        let cached = UserDefaults.standard.dictionary(forKey: cachePrefix + id),
        let rawUUID = cached["uuid"] as? String, let uuid = UUID(uuidString: rawUUID),
        let description = cached["description"] as? [String: Any], description["id"] as? String == id,
        let peripheral = central.retrievePeripherals(withIdentifiers: [uuid]).first else { result(nil); return }
      devices[id] = peripheral; descriptions[id] = description
      result(description)
    case "scanDevices":
      finishScan()
      devices.removeAll()
      descriptions.removeAll()
      if central.state == .poweredOff {
        result(FlutterError(code: "BLUETOOTH_DISABLED", message: "请开启手机蓝牙后再试", details: nil))
        return
      }
      if central.state == .unauthorized {
        result(FlutterError(code: "BLE_PERMISSION_REQUIRED", message: "允许相关权限后使用", details: nil))
        return
      }
      pendingScan = result
      beginScanIfReady()
      scanTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
        self?.finishScan()
      }
    case "stopScan":
      finishScan()
      result(nil)
    case "connect":
      connectionPhase("requested")
      guard pendingConnect == nil else {
        result(FlutterError(code: "CONNECT_IN_PROGRESS", message: "正在连接手表", details: nil))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let id = arguments["deviceId"] as? String,
        let peripheral = devices[id] else {
        result(FlutterError(code: "DEVICE_NOT_FOUND", message: "请重新搜索并选择手表", details: nil))
        return
      }
      finishScan()
      closeConnection()
      generation += 1
      let requestGeneration = generation
      pendingConnect = result
      whenRetired { [weak self] closed in
        guard let self, self.generation == requestGeneration, self.pendingConnect != nil else { return }
        guard closed else {
          self.connectionPhase("retirementPending")
          self.pendingConnect = nil
          result(FlutterError(code: "DISCONNECT_PENDING", message: "手表连接尚未关闭，请稍后重试", details: nil))
          return
        }
        self.nativeID = id
        self.active = peripheral
        peripheral.delegate = self
        self.connectionPhase("connecting")
        self.central.connect(peripheral, options: nil)
      }
    case "disconnect":
      closeConnection()
      whenRetired { closed in
        result(closed ? nil : FlutterError(code: "DISCONNECT_PENDING", message: "手表连接尚未关闭，请稍后重试", details: nil))
      }
    case "getDeviceDetails":
      result(details())
    case "writeFrame":
      let arguments = call.arguments as? [String: Any]
      let bytes = arguments?["bytes"] as? FlutterStandardTypedData
      if let command = bytes?.data.first,
        !allowsHealthCommand(command) {
        result(FlutterError(code: "IOS_WELLNESS_SCOPE", message: "Not available in this iOS edition.", details: nil))
        return
      }
      guard let peripheral = active, let characteristic = writer,
        let bytes, bytes.data.count == 16, pendingWrite == nil else {
        result(FlutterError(code: "WRITE_UNAVAILABLE", message: "手表暂时无响应，请重试", details: nil))
        return
      }
      pendingWrite = result
      peripheral.writeValue(bytes.data, for: characteristic, type: .withResponse)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func beginScanIfReady() {
    if central.state == .poweredOn && pendingScan != nil {
      central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
  }

  private func finishScan() {
    scanTimer?.invalidate()
    scanTimer = nil
    if central.isScanning { central.stopScan() }
    if let completion = pendingScan {
      pendingScan = nil
      completion(Array(descriptions.values))
    }
  }

  private func details() -> [String: Any]? {
    guard let id = nativeID, writer != nil else { return nil }
    var value = descriptions[id] ?? ["id": id, "name": "U19", "hardwareAddress": id]
    if let firmware { value["firmwareVersion"] = firmware }
    if let hardware { value["model"] = hardware }
    return value
  }

  private func closeConnection() {
    generation += 1
    pendingConnect?(FlutterError(code: "DISCONNECTED", message: "手表已断开连接", details: nil))
    pendingConnect = nil
    pendingWrite?(FlutterError(code: "DISCONNECTED", message: "手表已断开连接", details: nil))
    pendingWrite = nil
    let previous = active
    active = nil
    nativeID = nil
    writer = nil
    notify = nil
    firmware = nil
    hardware = nil
    retriedFullServiceDiscovery = false
    if let peripheral = previous {
      peripheral.delegate = nil
      if peripheral.state != .disconnected {
        retiring[peripheral.identifier] = peripheral
        central.cancelPeripheralConnection(peripheral)
      }
    }
  }

  private func whenRetired(_ completion: @escaping (Bool) -> Void) {
    if retiring.isEmpty {
      completion(true)
      return
    }
    retirementWaiters.append(completion)
    guard retirementTimer == nil else { return }
    retirementTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
      guard let self else { return }
      self.retirementTimer = nil
      // CoreBluetooth has no close() primitive. A timeout must not pretend
      // that cancellation completed or allow a second connection to start.
      let waiters = self.retirementWaiters
      self.retirementWaiters.removeAll()
      waiters.forEach { $0(false) }
    }
  }

  @discardableResult
  private func finishRetirement(_ peripheral: CBPeripheral) -> Bool {
    guard retiring[peripheral.identifier] === peripheral else { return false }
    retiring.removeValue(forKey: peripheral.identifier)
    if retiring.isEmpty {
      retirementTimer?.invalidate()
      retirementTimer = nil
      let waiters = retirementWaiters
      retirementWaiters.removeAll()
      waiters.forEach { $0(true) }
    }
    return true
  }

  private func failConnection() {
    pendingConnect?(FlutterError(code: "CONNECT_FAILED", message: "暂时无法连接手表，请重试", details: nil))
    pendingConnect = nil
    closeConnection()
  }

  private func completeConnection() {
    guard let completion = pendingConnect, writer != nil, notify != nil else { return }
    pendingConnect = nil
    connectionPhase("nativeReady")
    completion(["generation": generation])
    if let value = details() { sink?(["type": "deviceDetails", "payload": value.merging(["generation": generation]) { _, new in new }]) }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      beginScanIfReady()
      return
    }
    if pendingScan != nil { finishScan() }
    if active != nil {
      let id = nativeID
      let ready = writer != nil
      let endedGeneration = generation
      closeConnection()
      if ready, let id {
        sink?(["type": "disconnected", "payload": ["deviceId": id, "generation": endedGeneration]])
      }
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber) {
    guard let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else { return }
    let data = [UInt8](manufacturer)
    guard data.count >= 10, data[0] == 0x34, data[1] == 0x12,
      data[2] == 0xFE, data[3] == 0xE7 else { return }
    let id = data[4..<10].map { String(format: "%02X", $0) }.joined(separator: ":")
    let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
      ?? peripheral.name ?? "U19"
    let value: [String: Any] = ["id": id, "name": name,
      "hardwareAddress": id, "rssi": RSSI.intValue]
    devices[id] = peripheral
    descriptions[id] = value
    sink?(["type": "scanDevice", "payload": value])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    if retiring[peripheral.identifier] === peripheral {
      central.cancelPeripheralConnection(peripheral)
      return
    }
    guard peripheral === active else { return }
    connectionPhase("connected")
    peripheral.discoverServices([serviceID, infoID])
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    if finishRetirement(peripheral) { return }
    if peripheral === active { connectionPhase("failed", error: error); failConnection() }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    if finishRetirement(peripheral) { return }
    guard peripheral === active else { return }
    connectionPhase("disconnected", error: error)
    let id = nativeID
    let ready = writer != nil
    let endedGeneration = generation
    if pendingConnect != nil { failConnection() } else { closeConnection() }
    if ready, let id { sink?(["type": "disconnected", "payload": ["deviceId": id, "generation": endedGeneration]]) }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if peripheral === active { connectionPhase("services", error: error) }
    guard peripheral === active else { return }
    guard error == nil else { failConnection(); return }
    guard let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else {
      // 缓存直连后，部分固件/系统缓存只交付筛选服务的子集。只补一次完整发现；
      // 仍必须找到同一协议服务并完成 EB1 握手，不接纳其他 UUID 或改写手表。
      if !retriedFullServiceDiscovery {
        retriedFullServiceDiscovery = true
        connectionPhase("retryAllServices")
        peripheral.discoverServices(nil)
      } else {
        connectionPhase("protocolServiceMissing")
        failConnection()
      }
      return
    }
    peripheral.discoverCharacteristics([writeID, notifyID], for: service)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard peripheral === active else { return }
    connectionPhase(service.uuid == serviceID ? "gattCharacteristics" : "infoCharacteristics", error: error)
    if service.uuid == serviceID {
      guard error == nil,
        let write = service.characteristics?.first(where: { $0.uuid == writeID }),
        let notification = service.characteristics?.first(where: { $0.uuid == notifyID }),
        write.properties.contains(.write), notification.properties.contains(.notify) else {
        failConnection()
        return
      }
      writer = write
      notify = notification
      peripheral.setNotifyValue(true, for: notification)
    } else if service.uuid == infoID {
      if let firmwareCharacteristic = service.characteristics?.first(where: { $0.uuid == firmwareID }) {
        peripheral.readValue(for: firmwareCharacteristic)
      } else if let hardwareCharacteristic = service.characteristics?.first(where: { $0.uuid == hardwareID }) {
        peripheral.readValue(for: hardwareCharacteristic)
      } else {
        completeConnection()
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?) {
    guard peripheral === active, characteristic.uuid == notifyID else { return }
    connectionPhase("notifications", error: error)
    guard error == nil, characteristic.isNotifying else { failConnection(); return }
    if let info = peripheral.services?.first(where: { $0.uuid == infoID }) {
      peripheral.discoverCharacteristics([firmwareID, hardwareID], for: info)
    } else {
      completeConnection()
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard peripheral === active else { return }
    if characteristic.uuid == notifyID {
      guard error == nil, let bytes = characteristic.value, let id = nativeID else { return }
      sink?(["type": "bytes", "bytes": FlutterStandardTypedData(bytes: bytes),
        "deviceId": id, "generation": generation])
      return
    }
    if error == nil, let bytes = characteristic.value {
      let value = String(data: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
      if characteristic.uuid == firmwareID { firmware = value }
      if characteristic.uuid == hardwareID { hardware = value }
    }
    if characteristic.uuid == firmwareID,
      let info = peripheral.services?.first(where: { $0.uuid == infoID }),
      let hardwareCharacteristic = info.characteristics?.first(where: { $0.uuid == hardwareID }) {
      peripheral.readValue(for: hardwareCharacteristic)
    } else {
      completeConnection()
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    guard peripheral === active, characteristic.uuid == writeID, let completion = pendingWrite else { return }
    pendingWrite = nil
    if error == nil { completion(nil) }
    else { completion(FlutterError(code: "WRITE_FAILED", message: "手表暂时无响应，请重试", details: nil)) }
  }
}
