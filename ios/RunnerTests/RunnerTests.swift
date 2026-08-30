import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testGalleryImagePayloadAcceptsTypedBytesAndSanitizesFileName() throws {
    let typedBytes = FlutterStandardTypedData(bytes: Data([0xFF, 0xD8, 0xFF, 0xD9]))
    let payload = try XCTUnwrap(
      GalleryImagePayload(arguments: [
        "bytes": typedBytes,
        "fileName": "../saidian-photo.exe",
        "mimeType": "image/jpeg",
      ]))

    XCTAssertEqual(payload.data, Data([0xFF, 0xD8, 0xFF, 0xD9]))
    XCTAssertEqual(payload.fileName, "saidian-photo.jpg")
    XCTAssertEqual(payload.mimeType, "image/jpeg")
  }

  func testGalleryImagePayloadRejectsEmptyOversizedOrUnsupportedData() {
    XCTAssertNil(
      GalleryImagePayload(arguments: [
        "bytes": FlutterStandardTypedData(bytes: Data()),
        "fileName": "empty.jpg",
        "mimeType": "image/jpeg",
      ]))
    XCTAssertNil(
      GalleryImagePayload(arguments: [
        "bytes": FlutterStandardTypedData(bytes: Data([1, 2, 3])),
        "fileName": "not-an-image.txt",
        "mimeType": "text/plain",
      ]))
    XCTAssertNil(
      GalleryImagePayload(arguments: [
        "bytes": Data(repeating: 1, count: GalleryImagePayload.maximumByteCount + 1),
        "fileName": "too-large.jpg",
        "mimeType": "image/jpeg",
      ]))
  }

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

  func testWearableBatteryPayloadSeparatesPercentAndFourGridSemantics() throws {
    let updatedAt = Date(timeIntervalSince1970: 1_787_878_800.125)
    let percent = try XCTUnwrap(
      WearableBatterySnapshot(
        isPercent: true,
        low: true,
        chargeStateRawValue: 1,
        value: 19,
        updatedAt: updatedAt
      ))
    XCTAssertEqual(percent.value, 19)
    XCTAssertEqual(percent.scale, 100)
    XCTAssertEqual(percent.percent, 19)
    XCTAssertEqual(percent.low, true)
    XCTAssertEqual(percent.chargeState, .charging)
    XCTAssertEqual(percent.payload["value"] as? Int, 19)
    XCTAssertEqual(percent.payload["scale"] as? Int, 100)
    XCTAssertEqual(percent.payload["isPercent"] as? Bool, true)
    XCTAssertEqual(percent.payload["low"] as? Bool, true)
    XCTAssertEqual(percent.payload["chargeState"] as? String, "charging")
    XCTAssertNotNil(percent.payload["updatedAt"] as? String)

    let grid = try XCTUnwrap(
      WearableBatterySnapshot(
        isPercent: false,
        low: true,
        chargeStateRawValue: 3,
        value: 3,
        updatedAt: updatedAt
      ))
    XCTAssertEqual(grid.value, 3)
    XCTAssertEqual(grid.scale, 4)
    XCTAssertNil(grid.percent)
    XCTAssertEqual(grid.low, true)
    XCTAssertEqual(grid.chargeState, .fullUnreliable)
    XCTAssertEqual(grid.payload["low"] as? Bool, true)
    XCTAssertNil(
      WearableBatterySnapshot(
        isPercent: false,
        low: false,
        chargeStateRawValue: 0,
        value: 5,
        updatedAt: updatedAt
      ))
    XCTAssertNil(
      WearableBatterySnapshot(
        isPercent: true,
        low: false,
        chargeStateRawValue: 0,
        value: 101,
        updatedAt: updatedAt
      ))
  }

  func testWearableBatteryRefreshGateEnforcesTTLAndConnectionGeneration() {
    let now = Date(timeIntervalSince1970: 1_787_878_800)
    var gate = WearableBatteryRefreshGate()
    gate.reset()
    let sessionGeneration = gate.generation

    XCTAssertEqual(
      gate.request(now: now, lastUpdatedAt: nil, force: false, isBlocked: true),
      .deferUntilIdle
    )
    XCTAssertFalse(gate.isInFlight)
    guard case .start(let firstRequestGeneration) = gate.request(
      now: now,
      lastUpdatedAt: nil,
      force: false,
      isBlocked: false
    ) else {
      return XCTFail("first battery read should start")
    }
    XCTAssertGreaterThan(firstRequestGeneration, sessionGeneration)
    XCTAssertTrue(gate.isInFlight)
    XCTAssertEqual(
      gate.request(now: now, lastUpdatedAt: nil, force: true, isBlocked: false),
      .skip
    )
    XCTAssertFalse(gate.complete(generation: firstRequestGeneration + 1))
    XCTAssertTrue(gate.complete(generation: firstRequestGeneration))
    XCTAssertFalse(gate.isInFlight)

    XCTAssertEqual(
      gate.request(
        now: now,
        lastUpdatedAt: now.addingTimeInterval(-WearableBatteryRefreshGate.freshnessInterval),
        force: false,
        isBlocked: false
      ),
      .skip
    )
    guard case .start(let retryGeneration) = gate.request(
      now: now,
      lastUpdatedAt: now.addingTimeInterval(
        -WearableBatteryRefreshGate.freshnessInterval - 0.001),
      force: false,
      isBlocked: false
    ) else {
      return XCTFail("expired battery data should start a new read")
    }
    XCTAssertGreaterThan(retryGeneration, firstRequestGeneration)
    XCTAssertFalse(gate.complete(generation: firstRequestGeneration))
    XCTAssertTrue(gate.complete(generation: retryGeneration))
    gate.reset()
    XCTAssertFalse(gate.complete(generation: retryGeneration))
    XCTAssertFalse(gate.isInFlight)
  }

  func testWearableWatchFaceTransferGateRejectsLateCompletion() throws {
    var gate = WearableWatchFaceTransferGate()
    let oldGeneration = try XCTUnwrap(gate.begin())
    XCTAssertTrue(gate.isInFlight)
    XCTAssertNil(gate.begin())

    gate.reset()
    let currentGeneration = try XCTUnwrap(gate.begin())
    XCTAssertNotEqual(oldGeneration, currentGeneration)
    XCTAssertFalse(gate.complete(generation: oldGeneration))
    XCTAssertTrue(gate.isInFlight)
    XCTAssertTrue(gate.complete(generation: currentGeneration))
    XCTAssertFalse(gate.isInFlight)
  }

  func testWearableHealthSyncGateIsOneShotAndDeviceScoped() throws {
    var gate = WearableHealthSyncGate()
    let oldRequest = try XCTUnwrap(gate.begin(routeID: "device-a"))
    XCTAssertTrue(gate.accepts(oldRequest, currentRouteID: "DEVICE-A"))
    XCTAssertFalse(gate.accepts(oldRequest, currentRouteID: "device-b"))
    XCTAssertNil(gate.begin(routeID: "device-a"))

    gate.reset()
    let currentRequest = try XCTUnwrap(gate.begin(routeID: "device-b"))
    XCTAssertFalse(gate.complete(oldRequest))
    XCTAssertTrue(gate.isInFlight)
    XCTAssertTrue(gate.accepts(currentRequest, currentRouteID: "device-b"))
    XCTAssertTrue(gate.complete(currentRequest))
    XCTAssertFalse(gate.complete(currentRequest))
    XCTAssertFalse(gate.isInFlight)
  }

  func testWearableDeviceSessionGateRejectsLateReadsAndOldDevices() throws {
    var gate = WearableDeviceSessionGate()
    gate.beginSession(routeID: "device-a")
    let sessionA = try XCTUnwrap(gate.currentSession)
    let requestA1 = try XCTUnwrap(gate.beginRequest())
    let requestA2 = try XCTUnwrap(gate.beginRequest())
    XCTAssertTrue(gate.accepts(sessionA))
    XCTAssertFalse(gate.accepts(requestA1))
    XCTAssertTrue(gate.accepts(requestA2))

    gate.beginSession(routeID: "device-b")
    XCTAssertFalse(gate.accepts(sessionA))
    XCTAssertFalse(gate.accepts(requestA2))
    XCTAssertEqual(gate.currentSession?.routeID, "device-b")
    gate.endSession()
    XCTAssertNil(gate.currentSession)
  }

  func testNativeWatchFaceCatalogCacheIsBoundToSessionAndRejectsLateResults() throws {
    let sessionA = WearableDeviceSessionIdentity(routeID: "device-a", generation: 1)
    let sessionB = WearableDeviceSessionIdentity(routeID: "device-b", generation: 2)
    var gate = WearableNativeWatchFaceCatalogGate()

    let first = gate.begin(session: sessionA)
    let latest = gate.begin(session: sessionA)
    XCTAssertFalse(gate.commit(first, catalogIDs: ["old-id"]))
    XCTAssertTrue(gate.commit(latest, catalogIDs: ["dial-a", "dial-b"]))
    XCTAssertTrue(gate.owns(catalogID: "dial-a", session: sessionA))
    XCTAssertFalse(gate.owns(catalogID: "dial-a", session: sessionB))

    let staleAfterSwitch = gate.begin(session: sessionA)
    gate.reset()
    XCTAssertFalse(gate.commit(staleAfterSwitch, catalogIDs: ["late-id"]))
    XCTAssertFalse(gate.owns(catalogID: "dial-a", session: sessionA))
  }

  func testNativeWatchFaceCatalogPayloadUsesRealVendorFieldsAndStableID() throws {
    let payload = try XCTUnwrap(
      WearableNativeWatchFaceCatalogPayload.make(
        name: " ",
        fileURL: "https://vendor.example/WATCH001.bin",
        previewURL: "https://vendor.example/WATCH001.png",
        crc: 456_789,
        binProtocol: 2,
        dialShape: 58
      ))
    let duplicate = try XCTUnwrap(
      WearableNativeWatchFaceCatalogPayload.make(
        name: "optional display name",
        fileURL: "https://vendor.example/WATCH001.bin",
        previewURL: "https://vendor.example/WATCH001.png",
        crc: 456_789,
        binProtocol: 2,
        dialShape: 58
      ))

    XCTAssertEqual(payload["name"] as? String, "")
    XCTAssertEqual(payload["fileUrl"] as? String, "https://vendor.example/WATCH001.bin")
    XCTAssertEqual(payload["previewUrl"] as? String, "https://vendor.example/WATCH001.png")
    XCTAssertEqual(payload["crc"] as? Int, 456_789)
    XCTAssertEqual(payload["binProtocol"] as? Int, 2)
    XCTAssertEqual(payload["dialShape"] as? Int, 58)
    XCTAssertEqual(payload["id"] as? String, duplicate["id"] as? String)
    XCTAssertNotNil(
      (payload["id"] as? String)?.range(
        of: "^[0-9a-f]{64}$",
        options: .regularExpression
      )
    )
    XCTAssertNil(
      WearableNativeWatchFaceCatalogPayload.make(
        name: "",
        fileURL: "",
        previewURL: "https://vendor.example/WATCH001.png",
        crc: 0,
        binProtocol: 2,
        dialShape: 58
      ))
  }

  func testMarketDialVerificationRequiresStableReadback() {
    XCTAssertFalse(
      WearableMarketDialVerification.confirmsChangedImage(
        previousImageID: 0,
        refreshedImageID: 0
      ))
    XCTAssertFalse(
      WearableMarketDialVerification.confirmsChangedImage(
        previousImageID: 42,
        refreshedImageID: 42
      ))
    XCTAssertTrue(
      WearableMarketDialVerification.confirmsChangedImage(
        previousImageID: 42,
        refreshedImageID: 43
      ))
    XCTAssertTrue(
      WearableMarketDialVerification.confirmsResource(
        expected: "/tmp/WATCH_123.BIN",
        current: "watch_123.bin"
      ))
    XCTAssertFalse(
      WearableMarketDialVerification.confirmsResource(
        expected: "WATCH_123.BIN",
        current: "WATCH_999.BIN"
      ))
    XCTAssertFalse(WearableTransferProgress.isComplete(0.999))
    XCTAssertTrue(WearableTransferProgress.isComplete(1))
    XCTAssertTrue(WearableTransferProgress.isComplete(100))
  }

  func testWearableWatchFaceProfileUsesStrictDeviceIdentityAndFingerprint() throws {
    let payload = try XCTUnwrap(
      WearableWatchFaceProfilePayload.make(
        deviceID: " 36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D ",
        deviceLabel: " SD-Watch-W9S ",
        provider: " Vep ",
        defaultSlotCount: 6,
        marketSlotCount: 1,
        photoSlotCount: 1,
        deviceNumber: 6702,
        deviceTestVersion: " 11.95.01.00 ",
        deviceVersion: " 00.16.06.00-2128 ",
        dialShape: 58,
        binProtocol: 2,
        maxLength: 614_733,
        screenWidth: 410,
        screenHeight: 502
      ))
    XCTAssertEqual(payload["onlineMarketSupported"] as? Bool, true)
    XCTAssertEqual(payload["profileVersion"] as? Int, 1)
    XCTAssertEqual(payload["deviceId"] as? String, "36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D")
    XCTAssertEqual(payload["deviceLabel"] as? String, "SD-Watch-W9S")
    XCTAssertEqual(payload["provider"] as? String, "Vep")
    XCTAssertEqual(payload["slotCount"] as? Int, 1)
    XCTAssertEqual(payload["defaultSlotCount"] as? Int, 6)
    XCTAssertEqual(payload["photoSlotCount"] as? Int, 1)
    XCTAssertEqual(payload["deviceNumber"] as? Int, 6702)
    XCTAssertEqual(payload["deviceTestVersion"] as? String, "11.95.01.00")
    XCTAssertEqual(payload["firmware"] as? String, "11.95.01.00")
    XCTAssertEqual(payload["dialShape"] as? Int, 58)
    XCTAssertEqual(payload["binProtocol"] as? Int, 2)
    XCTAssertEqual(payload["maxLength"] as? Int, 614_733)
    XCTAssertEqual(payload["maxFileLength"] as? Int, 614_733)
    XCTAssertEqual(payload["screenWidth"] as? Int, 410)
    XCTAssertEqual(payload["screenHeight"] as? Int, 502)
    XCTAssertEqual(payload["width"] as? Int, 410)
    XCTAssertEqual(payload["height"] as? Int, 502)
    let fingerprint = try XCTUnwrap(payload["profileFingerprint"] as? String)
    XCTAssertNotNil(
      fingerprint.range(of: "^[0-9a-f]{64}$", options: .regularExpression)
    )

    let changedDevice = try XCTUnwrap(
      WearableWatchFaceProfilePayload.make(
        deviceID: "another-device",
        deviceLabel: "SD-Watch-W9S",
        provider: "Vep",
        defaultSlotCount: 6,
        marketSlotCount: 1,
        photoSlotCount: 1,
        deviceNumber: 6702,
        deviceTestVersion: "11.95.01.00",
        deviceVersion: "00.16.06.00-2128",
        dialShape: 58,
        binProtocol: 2,
        maxLength: 614_733,
        screenWidth: 410,
        screenHeight: 502
      ))
    XCTAssertNotEqual(
      changedDevice["profileFingerprint"] as? String,
      fingerprint
    )
  }

  func testWearableWatchFaceProfileRejectsIncompleteRuntimeFields() {
    func profile(
      deviceID: String = "device-id",
      deviceLabel: String = "SD-Watch-W9S",
      provider: String = "Vep",
      marketSlotCount: Int = 1,
      deviceTestVersion: String = "11.95.01.00",
      maxLength: Int = 614_733
    ) -> [String: Any]? {
      WearableWatchFaceProfilePayload.make(
        deviceID: deviceID,
        deviceLabel: deviceLabel,
        provider: provider,
        defaultSlotCount: 6,
        marketSlotCount: marketSlotCount,
        photoSlotCount: 1,
        deviceNumber: 6702,
        deviceTestVersion: deviceTestVersion,
        deviceVersion: "00.16.06.00-2128",
        dialShape: 58,
        binProtocol: 2,
        maxLength: maxLength,
        screenWidth: 410,
        screenHeight: 502
      )
    }

    XCTAssertNil(profile(deviceID: " "))
    XCTAssertNil(profile(deviceLabel: " "))
    XCTAssertNil(profile(provider: " "))
    XCTAssertNil(profile(marketSlotCount: 0))
    XCTAssertNil(profile(deviceTestVersion: " "))
    XCTAssertNil(profile(maxLength: 0))
  }

  func testWearableEcgWaveformMapperTreatsMissingAndIncompleteSignalsAsEmpty() {
    let missing = WearableEcgWaveformMapper.convert(signals: nil) { $0 }
    XCTAssertTrue(missing.samples.isEmpty)
    XCTAssertEqual(missing.sourceCount, 0)
    XCTAssertEqual(missing.rawVersion, 1)

    let single = WearableEcgWaveformMapper.convert(signals: [1]) { $0 }
    XCTAssertTrue(single.samples.isEmpty)
    XCTAssertEqual(single.sourceCount, 1)

    let flat = WearableEcgWaveformMapper.convert(signals: [0, 0, 0]) { $0 }
    XCTAssertTrue(flat.samples.isEmpty)
    XCTAssertEqual(flat.sourceCount, 3)
  }

  func testWearableEcgWaveformMapperConvertsOnlyNewValidSamples() {
    let converted = WearableEcgWaveformMapper.convert(
      signals: [0, "2", NSNumber(value: 4)],
      from: 1
    ) { $0 * 0.5 }

    XCTAssertEqual(converted.sourceCount, 3)
    XCTAssertEqual(converted.rawVersion, 2)
    XCTAssertEqual(converted.samples.map(\.doubleValue), [1, 2])
  }

  func testWearableEcgWaveformMapperRejectsNonFiniteConversion() {
    let converted = WearableEcgWaveformMapper.convert(signals: [1, 2]) { _ in
      .infinity
    }

    XCTAssertTrue(converted.samples.isEmpty)
    XCTAssertEqual(converted.sourceCount, 2)
    XCTAssertEqual(converted.rawVersion, 1)
  }

  func testWearableEcgMeasurementStatesSeparateProgressFromTerminalResults() {
    XCTAssertFalse(WearableEcgMeasurementState.start.isTerminal)
    XCTAssertFalse(WearableEcgMeasurementState.testing.isTerminal)
    XCTAssertFalse(WearableEcgMeasurementState.notLead.isTerminal)
    XCTAssertTrue(WearableEcgMeasurementState.deviceBusy.isTerminal)
    XCTAssertTrue(WearableEcgMeasurementState.over.isTerminal)
    XCTAssertTrue(WearableEcgMeasurementState.failure.isTerminal)
    XCTAssertTrue(WearableEcgMeasurementState.complete.isTerminal)
    XCTAssertTrue(WearableEcgMeasurementState.noFunction.isTerminal)
  }

}
