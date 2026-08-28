import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testWearableSportModeAndHeartWarningMapping() {
    XCTAssertEqual(WearablePayloadMapper.sportMode("walking"), .outdoorWalk)
    XCTAssertEqual(WearablePayloadMapper.sportMode("cycling"), .outdoorRide)
    XCTAssertEqual(WearablePayloadMapper.sportMode("hiking"), .hiking)
    XCTAssertEqual(WearablePayloadMapper.sportMode("running"), .outdoorRun)
    XCTAssertNil(WearablePayloadMapper.sportMode("swimming"))
    XCTAssertEqual(WearablePayloadMapper.clampedHeartWarning(40), 70)
    XCTAssertEqual(WearablePayloadMapper.clampedHeartWarning(120), 120)
    XCTAssertEqual(WearablePayloadMapper.clampedHeartWarning(240), 190)
  }

  func testWearablePrimitivePayloadMapping() {
    XCTAssertEqual(WearablePayloadMapper.minutes(hour: 23, minute: 59), 1439)
    XCTAssertTrue(WearablePayloadMapper.bool(true))
    XCTAssertFalse(WearablePayloadMapper.bool("true"))
    XCTAssertTrue(WearablePayloadMapper.bool(nil, default: true))
  }

  func testWearableHardwareAddressMapping() {
    XCTAssertEqual(
      WearablePayloadMapper.hardwareAddress("67:97:35:81:2f:44"),
      "67:97:35:81:2F:44"
    )
    XCTAssertEqual(
      WearablePayloadMapper.hardwareAddress("5c8bbc6f26fc"),
      "5C:8B:BC:6F:26:FC"
    )
    XCTAssertEqual(
      WearablePayloadMapper.hardwareAddress("07-43-00-00-4d-e9"),
      "07:43:00:00:4D:E9"
    )
    XCTAssertNil(WearablePayloadMapper.hardwareAddress("36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D"))
    XCTAssertNil(WearablePayloadMapper.hardwareAddress(""))
  }

  func testWearableSportRecordPayloadMatchesFlutterContract() {
    XCTAssertEqual(WearablePayloadMapper.sportWireName(rawValue: 1), "running")
    XCTAssertEqual(WearablePayloadMapper.sportWireName(rawValue: 2), "walking")
    XCTAssertEqual(WearablePayloadMapper.sportWireName(rawValue: 5), "hiking")
    XCTAssertEqual(WearablePayloadMapper.sportWireName(rawValue: 11), "mountaineering")
    XCTAssertEqual(WearablePayloadMapper.sportWireName(rawValue: 7), "cycling")

    let payload = WearablePayloadMapper.sportRecord(from: [
      "type": 7,
      "beginTime": "2026-08-13 09:30:00",
      "totalTime": "1268",
      "totalDis": 3500,
      "totalCal": 125000,
      "crcValue": 47136,
    ])

    XCTAssertEqual(payload?["id"] as? String, "7-2026-08-13T09:30:00-47136")
    XCTAssertEqual(payload?["mode"] as? String, "cycling")
    XCTAssertEqual(payload?["startedAt"] as? String, "2026-08-13T09:30:00")
    XCTAssertEqual(payload?["durationSeconds"] as? Int, 1268)
    XCTAssertEqual(payload?["distanceKm"] as? Double, 3.5)
    XCTAssertEqual(payload?["calories"] as? Double, 125)
  }

  func testWearableDeviceSettingBoundaries() {
    XCTAssertEqual(WearablePayloadMapper.repeatMask(days: [1, 3, 5]), 0b00010101)
    XCTAssertEqual(WearablePayloadMapper.repeatMask(days: [1, 7]), 0b01000001)
    XCTAssertEqual(WearablePayloadMapper.repeatDays(mask: 0b01000001), [1, 7])
    XCTAssertEqual(WearablePayloadMapper.safeLabel("测试联系人", limit: 20), "测试联系人")
    XCTAssertEqual(WearablePayloadMapper.safeLabel("1234567890", limit: 5), "12345")
    XCTAssertEqual(WearablePayloadMapper.clamp(9, minimum: 1, maximum: 5), 5)
    XCTAssertEqual(WearablePayloadMapper.clamp(-1, minimum: 1, maximum: 5), 1)
  }

  func testWearableFileAndProgressMapping() {
    XCTAssertEqual(WearablePayloadMapper.progress(completed: 5, total: 20), 25)
    XCTAssertEqual(WearablePayloadMapper.progress(completed: 25, total: 20), 100)
    XCTAssertNil(WearablePayloadMapper.localFileURL(""))
    XCTAssertEqual(
      WearablePayloadMapper.localFileURL("file:///tmp/test.bin")?.path,
      "/tmp/test.bin"
    )
  }

  func testWearableWeatherTemperatureMapping() {
    XCTAssertEqual(WearablePayloadMapper.fahrenheit(celsius: 0), 32, accuracy: 0.001)
    XCTAssertEqual(WearablePayloadMapper.fahrenheit(celsius: 25), 77, accuracy: 0.001)
    XCTAssertEqual(WearablePayloadMapper.fahrenheit(celsius: -40), -40, accuracy: 0.001)
  }

  func testWearableWatchFaceEntriesMatchCurrentDial() {
    let entries = WearablePayloadMapper.watchFaceEntries(
      defaultCount: 2,
      marketCount: 1,
      photoCount: 1,
      marketInstalled: true,
      currentType: 2,
      currentStyle: 1
    )
    XCTAssertEqual(entries.count, 4)
    XCTAssertEqual(entries[0]["id"] as? String, "default:0")
    XCTAssertEqual(entries[2]["id"] as? String, "market:1")
    XCTAssertEqual(entries[3]["id"] as? String, "photo:1")
    XCTAssertEqual(entries[3]["isCurrent"] as? Bool, true)

    let emptyMarket = WearablePayloadMapper.watchFaceEntries(
      defaultCount: 2,
      marketCount: 1,
      photoCount: 0,
      marketInstalled: false,
      currentType: 0,
      currentStyle: 0
    )
    XCTAssertEqual(emptyMarket.count, 2)
    XCTAssertEqual(WearablePayloadMapper.screenSize(deviceShape: 0x3A)?.width, 410)
    XCTAssertEqual(WearablePayloadMapper.screenSize(deviceShape: 0x3A)?.height, 502)
    XCTAssertNil(WearablePayloadMapper.screenSize(deviceShape: 0xFF))
  }

}
