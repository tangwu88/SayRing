import Foundation

enum WearableSportMode: Equatable {
  case outdoorRun
  case outdoorWalk
  case outdoorRide
  case hiking
}

enum WearablePayloadMapper {
  static func sportMode(_ wireName: String) -> WearableSportMode? {
    switch wireName {
    case "running": .outdoorRun
    case "walking": .outdoorWalk
    case "cycling": .outdoorRide
    case "hiking": .hiking
    default: nil
    }
  }

  static func clampedHeartWarning(_ value: Int) -> Int {
    min(190, max(70, value))
  }

  static func minutes(hour: Int, minute: Int) -> Int {
    hour * 60 + minute
  }

  static func bool(_ value: Any?, `default` fallback: Bool = false) -> Bool {
    value as? Bool ?? fallback
  }

  static func hardwareAddress(_ rawValue: String?) -> String? {
    let value = (rawValue ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased()
      .replacingOccurrences(of: "-", with: ":")
    if value.range(
      of: "^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$",
      options: .regularExpression
    ) != nil {
      return value
    }
    guard value.range(of: "^[0-9A-F]{12}$", options: .regularExpression) != nil else {
      return nil
    }
    return stride(from: 0, to: value.count, by: 2).map { offset in
      let start = value.index(value.startIndex, offsetBy: offset)
      let end = value.index(start, offsetBy: 2)
      return String(value[start..<end])
    }.joined(separator: ":")
  }

  static func sportWireName(rawValue: Int) -> String {
    switch rawValue {
    case 2, 4: "walking"
    case 5: "hiking"
    case 11: "mountaineering"
    case 7, 8: "cycling"
    default: "running"
    }
  }

  static func sportRecord(from source: [String: Any]) -> [String: Any]? {
    guard let startedAt = source["beginTime"] as? String, !startedAt.isEmpty else {
      return nil
    }
    let type = integer(source["type"])
    let crc = integer(source["crcValue"])
    let normalizedStartedAt = startedAt.replacingOccurrences(of: " ", with: "T")
    return [
      "id": "\(type)-\(normalizedStartedAt)-\(crc)",
      "mode": sportWireName(rawValue: type),
      "startedAt": normalizedStartedAt,
      "durationSeconds": integer(source["totalTime"]),
      "distanceKm": number(source["totalDis"]) / 1_000,
      "calories": number(source["totalCal"]) / 1_000,
    ]
  }

  static func repeatMask(days: Set<Int>) -> UInt8 {
    days.reduce(0) { mask, day in
      guard (1...7).contains(day) else { return mask }
      return mask | UInt8(1 << (day - 1))
    }
  }

  static func repeatDays(mask: UInt8) -> [Int] {
    (1...7).filter { day in
      mask & UInt8(1 << (day - 1)) != 0
    }
  }

  static func safeLabel(_ value: String, limit: Int) -> String {
    guard limit > 0 else { return "" }
    var result = ""
    for character in value {
      let candidate = result + String(character)
      if candidate.lengthOfBytes(using: .utf8) > limit { break }
      result = candidate
    }
    return result
  }

  static func clamp(_ value: Int, minimum: Int, maximum: Int) -> Int {
    min(maximum, max(minimum, value))
  }

  static func progress(completed: Int, total: Int) -> Int {
    guard total > 0 else { return 0 }
    return clamp(Int((Double(completed) / Double(total) * 100).rounded()), minimum: 0, maximum: 100)
  }

  static func localFileURL(_ value: String) -> URL? {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    if let url = URL(string: value), url.isFileURL { return url }
    return URL(fileURLWithPath: value)
  }

  static func fahrenheit(celsius: Double) -> Double {
    celsius * 9 / 5 + 32
  }

  static func watchFaceEntries(
    defaultCount: Int,
    marketCount: Int,
    photoCount: Int,
    marketInstalled: Bool,
    currentType: Int,
    currentStyle: Int
  ) -> [[String: Any]] {
    var entries: [[String: Any]] = []
    for index in 0..<max(defaultCount, 0) {
      entries.append([
        "id": "default:\(index)",
        "name": "内置表盘 \(index + 1)",
        "type": "default",
        "index": index,
        "isCurrent": currentType == 0 && currentStyle == index,
        "status": "手表内置",
      ])
    }
    if marketCount > 0 && marketInstalled {
      entries.append([
        "id": "market:1",
        "name": "已安装市场表盘",
        "type": "market",
        "index": 1,
        "isCurrent": currentType == 1,
        "status": "设备市场表盘位",
      ])
    }
    if photoCount > 0 {
      entries.append([
        "id": "photo:1",
        "name": "照片表盘",
        "type": "photo",
        "index": 1,
        "isCurrent": currentType == 2,
        "status": "可用照片表盘位",
      ])
    }
    return entries
  }

  static func screenSize(deviceShape: Int) -> (width: Int, height: Int)? {
    switch deviceShape {
    case 0x01, 0x02, 0x05, 0x0B, 0x3C, 0x4C, 0x51, 0x7A:
      return (240, 240)
    case 0x03, 0x04, 0x09, 0x31, 0x44, 0x5E, 0x6A:
      return (240, 280)
    case 0x0F, 0x32, 0x45, 0x5F, 0x64, 0x6B:
      return (240, 284)
    case 0x10, 0x33, 0x46:
      return (240, 286)
    case 0x38, 0x42, 0x5D, 0x62, 0x69:
      return (240, 296)
    case 0x3B, 0x4B:
      return (240, 292)
    case 0x0D, 0x3E, 0x65, 0x6E:
      return (172, 320)
    case 0x12, 0x3D, 0x61, 0x6C:
      return (200, 320)
    case 0x11, 0x37, 0x48:
      return (320, 380)
    case 0x39, 0x49, 0x59, 0x5A:
      return (320, 386)
    case 0x34, 0x47, 0x63, 0x6D:
      return (368, 448)
    case 0x3A, 0x4A, 0x55, 0x70, 0x71, 0x79, 0x7D, 0x7E:
      return (410, 502)
    case 0x08, 0x30, 0x4D, 0x54, 0x5C, 0x68, 0x74, 0x75, 0x76:
      return (360, 360)
    case 0x35, 0x4F, 0x5B, 0x67, 0x78, 0x7B:
      return (466, 466)
    case 0x36, 0x4E:
      return (412, 412)
    case 0x3F:
      return (390, 390)
    case 0x40, 0x72, 0x73:
      return (390, 450)
    case 0x41:
      return (416, 416)
    case 0x43:
      return (320, 320)
    case 0x50, 0x57:
      return (480, 480)
    default:
      return nil
    }
  }

  private static func integer(_ value: Any?) -> Int {
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? String { return Int(value) ?? 0 }
    return 0
  }

  private static func number(_ value: Any?) -> Double {
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) ?? 0 }
    return 0
  }
}
