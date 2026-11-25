part of 'app_controller.dart';

extension RingExperienceController on AppController {
  bool get ringExperience =>
      isWellnessOnly && isGlobalEdition && !isPreviewMode;

  // Local pressure trends are available on both phone platforms. Wearable
  // readings still follow the release policy for the individual metric.
  bool get canOpenCardiovascularTrends =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) &&
      isGlobalEdition &&
      !isPreviewMode;

  bool get canAnalyzeCardiovascularTrends =>
      canOpenCardiovascularTrends &&
      isAuthenticated &&
      !_accountTransitioning &&
      _api is CardiovascularModelApi;

  Future<CardiovascularModelReply> analyzeCardiovascularTrends(
    CardiovascularModelInput input,
    String language,
  ) async {
    final member = session, generation = _sessionGeneration;
    if (!canAnalyzeCardiovascularTrends || member == null) {
      throw const ApiException('登录后可查看趋势解读');
    }
    final reply = await (_api as CardiovascularModelApi)
        .analyzeCardiovascularTrends(member, input, language);
    if (!_isCurrentAccountRequest(generation, member) ||
        !canAnalyzeCardiovascularTrends) {
      throw const ApiException('账号已变化，请重新打开');
    }
    return reply;
  }

  bool get ringSharingEnabled => ringExperience && _ringCapabilities.sharing;
  bool get ringCareEnabled => ringExperience && _ringCapabilities.care;

  String get ringExperienceOwner => '$homeHealthCardOwner:$_sessionGeneration';

  String _ringLocalKey(String owner, String section) =>
      'say-ring.v1.${sha256.convert(utf8.encode('${globalStorageNamespace(null)}:$owner'))}.$section';

  String get _ringLinkKey => _ringLocalKey('installation', 'pending-link');

  Future<PendingRingLink?> readPendingRingLink() async {
    await _ringLocalWrites;
    final raw = await safeSecureStorage.read(key: _ringLinkKey);
    if (raw == null) return null;
    final value = PendingRingLink.fromJson(jsonDecode(raw));
    return value?.isRecent(DateTime.now()) == true ? value : null;
  }

  Future<void> writePendingRingLink(
    PendingRingLink value, {
    bool consume = false,
  }) {
    final encoded = jsonEncode(value.toJson());
    final result = _ringLocalWrites.then((_) async {
      if (!consume) {
        await safeSecureStorage.write(key: _ringLinkKey, value: encoded);
      } else if (await safeSecureStorage.read(key: _ringLinkKey) == encoded) {
        await safeSecureStorage.delete(key: _ringLinkKey);
      }
    });
    _ringLocalWrites = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, Object?>> ringRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? data,
  }) async {
    final expected = session;
    final api = _api;
    final generation = _sessionGeneration;
    if (!ringExperience ||
        expected == null ||
        _accountTransitioning ||
        api is! RingExperienceApi) {
      throw const ApiException('请登录后使用');
    }
    final result = await (api as RingExperienceApi).requestRing(
      expected,
      method,
      path,
      query: query,
      data: data,
    );
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      throw const ApiException('账号已变化，请重新打开');
    }
    return result;
  }

  Future<Uint8List> ringFile(String path, int maxBytes) async {
    final expected = session;
    final api = _api;
    final generation = _sessionGeneration;
    if (!ringExperience ||
        expected == null ||
        _accountTransitioning ||
        api is! RingExperienceApi) {
      throw const ApiException('请登录后使用');
    }
    final result = await (api as RingExperienceApi).readRingBytes(
      expected,
      path,
      maxBytes,
    );
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      throw const ApiException('账号已变化，请重新打开');
    }
    return result;
  }

  Future<String> readRingWeekNote(String week) async {
    final owner = homeHealthCardOwner;
    return await safeSecureStorage.read(
          key: _ringLocalKey(owner, 'week-$week'),
        ) ??
        '';
  }

  Future<void> writeRingWeekNote(String week, String note) =>
      safeSecureStorage.write(
        key: _ringLocalKey(homeHealthCardOwner, 'week-$week'),
        value: note,
      );

  Future<void> savePressureReference(PressureSample sample) =>
      _writePressureReference(null, sample);

  Future<void> replacePressureReference(
    PressureSample original,
    PressureSample? replacement,
  ) => _writePressureReference(original, replacement);

  Future<void> _writePressureReference(
    PressureSample? original,
    PressureSample? replacement,
  ) async {
    if (!canOpenCardiovascularTrends ||
        _accountTransitioning ||
        (original != null && original.source != 'reference') ||
        (replacement != null &&
            (replacement.source != 'reference' ||
                replacement.at.isAfter(DateTime.now()) ||
                !PressureSample.validPair(
                  replacement.systolic,
                  replacement.diastolic,
                )))) {
      throw const ApiException('请检查参考值和测量时间');
    }
    final owner = homeHealthCardOwner;
    final generation = _sessionGeneration;
    final key = _ringLocalKey(owner, 'pressure-reference');
    // Serialize two edits to the same encrypted account store.
    final previous = _ringLocalWrites;
    final result = previous.then((_) async {
      if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
        return;
      }
      final raw = await safeSecureStorage.read(key: key);
      final rows = raw == null
          ? <Object?>[]
          : (jsonDecode(raw) as List).cast<Object?>();
      if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
        return;
      }
      bool matches(Object? raw, PressureSample entry) {
        final stored = PressureSample.fromReference(raw);
        return stored != null &&
            stored.at.isAtSameMomentAs(entry.at) &&
            stored.systolic == entry.systolic &&
            stored.diastolic == entry.diastolic;
      }

      if (original != null) {
        final length = rows.length;
        rows.removeWhere((row) => matches(row, original));
        if (length == rows.length) {
          throw const ApiException('这条血压参考值已变化，请刷新');
        }
      }
      final add =
          replacement != null && !rows.any((row) => matches(row, replacement));
      if (add || original != null) {
        await safeSecureStorage.write(
          key: key,
          value: jsonEncode(
            [if (add) replacement.toJson(), ...rows].take(1500).toList(),
          ),
        );
      }
    });
    _ringLocalWrites = result.then<void>((_) {}, onError: (Object _) {});
    await result;
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      throw const ApiException('账号已变化，请重新打开');
    }
  }

  /// Preserve device identities until the trend page selects its pressure source.
  Future<List<HealthRecord>> loadCardioContext(
    HealthMetric metric,
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    if (!canOpenCardiovascularTrends ||
        _accountTransitioning ||
        !isMetricAvailableInRelease(metric)) {
      return const [];
    }
    if (metric == HealthMetric.sleep) {
      return _readSleepDays(start: firstDay, end: lastDay, allDevices: true);
    }
    if (metric != HealthMetric.heartRate && metric != HealthMetric.steps) {
      return const [];
    }
    final generation = _sessionGeneration;
    // The stored display day can differ from the phone day after travel.
    final records = await _healthStore.range(
      metric: metric,
      start: ringAddDays(firstDay, -1),
      end: ringAddDays(lastDay, 2),
    );
    if (!_isCurrentSessionGeneration(generation) ||
        _accountTransitioning ||
        !isMetricAvailableInRelease(metric)) {
      return const [];
    }
    return _releaseRecords(records).toList(growable: false);
  }

  Future<List<PressureSample>> loadPressureTrend(
    DateTime from,
    DateTime until,
  ) async {
    if (!canOpenCardiovascularTrends || _accountTransitioning) return const [];
    final owner = homeHealthCardOwner;
    final generation = _sessionGeneration;
    final references = await safeSecureStorage.read(
      key: _ringLocalKey(owner, 'pressure-reference'),
    );
    final readback = await safeSecureStorage.read(
      key: _ringLocalKey(owner, 'urion-pressure-evidence'),
    );
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      return const [];
    }
    final device = isMetricAvailableInRelease(HealthMetric.bloodPressure)
        ? await _healthStore.range(
            metric: HealthMetric.bloodPressure,
            start: from,
            end: until,
          )
        : const <HealthRecord>[];
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      return const [];
    }
    final proofs = readback == null
        ? const <String>{}
        : (jsonDecode(readback) as List).whereType<String>().toSet();
    final now = DateTime.now();
    final result = <PressureSample>[
      if (references != null)
        for (final sample
            in (jsonDecode(references) as List)
                .map(PressureSample.fromReference)
                .nonNulls)
          if (!sample.at.isBefore(from) &&
              sample.at.isBefore(until) &&
              !sample.at.isAfter(now))
            sample,
    ];
    const verifiedUrion = String.fromEnvironment(
      'SAY_RING_VERIFIED_U19_PRESSURE',
    );
    final verified = verifiedUrion.split(',').toSet();
    for (final record in deduplicateHealthRecords(device)) {
      final urion =
          record.sourceVendor.trim().toLowerCase() == 'urion' ||
          WearableSdkSource.fromDeviceId(record.deviceId) ==
              WearableSdkSource.urion;
      if (urion &&
          (!verified.contains(
                '${record.sourceModel}:${record.firmwareVersion}',
              ) ||
              !proofs.contains(urionPressureEvidence(record)))) {
        continue;
      }
      final sample = PressureSample.fromDevice(record);
      if (sample != null && !sample.at.isAfter(now)) result.add(sample);
    }
    return result..sort((a, b) => a.at.compareTo(b.at));
  }

  Future<void> _confirmUrionTrendReadback(
    List<HealthRecord> records,
    int generation,
  ) async {
    const verified = String.fromEnvironment('SAY_RING_VERIFIED_U19_PRESSURE');
    if (!canOpenCardiovascularTrends ||
        verified.isEmpty ||
        session == null ||
        _accountTransitioning) {
      return;
    }
    final qualified = verified.split(',').toSet();
    final cloud = records
        .where(
          (record) =>
              qualified.contains(
                '${record.sourceModel}:${record.firmwareVersion}',
              ) &&
              urionPressureEvidence(record) != null,
        )
        .toList();
    if (cloud.isEmpty) return;
    final owner = homeHealthCardOwner;
    final now = DateTime.now();
    final start = ringAddDays(ringDate(now), -61);
    final local = await _healthStore.range(
      metric: HealthMetric.bloodPressure,
      start: start,
      end: now,
    );
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      return;
    }
    final localKeys = local.map(urionPressureEvidence).nonNulls.toSet();
    final agreed = cloud
        .map(urionPressureEvidence)
        .nonNulls
        .where(localKeys.contains);
    final key = _ringLocalKey(owner, 'urion-pressure-evidence');
    final previous = await safeSecureStorage.read(key: key);
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      return;
    }
    final existing = previous == null
        ? const <String>[]
        : (jsonDecode(previous) as List).whereType<String>();
    final combined = <String>{...agreed, ...existing.where(localKeys.contains)};
    await safeSecureStorage.write(
      key: key,
      value: jsonEncode(combined.take(6000).toList()),
    );
  }

  bool get ringCanReceiveHaptic {
    final candidate = connectedDevice;
    if (candidate == null ||
        !ringCareEnabled ||
        !_appIsForeground ||
        !_sameReadyRingTarget(candidate.id)) {
      return false;
    }
    final platform = defaultTargetPlatform.name;
    final model = WearableDeviceClassifier.coolwearModelForName(candidate.name);
    const calibrated = String.fromEnvironment('SAY_RING_VERIFIED_CARE_HAPTICS');
    return candidate.sdkSource == WearableSdkSource.coolwear &&
        model != null &&
        {'R7Pro', 'R7Ultra', 'HR05'}.contains(model) &&
        calibrated
            .split(',')
            .contains('$platform:$model:${candidate.firmwareVersion}');
  }

  bool _sameReadyRingTarget(String deviceId) =>
      !_accountTransitioning &&
      connectedDevice?.id == deviceId &&
      deviceState == DeviceConnectionState.ready &&
      !isDeviceHistorySyncing &&
      !isDeviceReconnecting &&
      !isSportStarting &&
      activeSport == null &&
      deviceFeatureBusy.isEmpty &&
      !ringReminderVibrationBusy &&
      !_ringFirmwareBusy &&
      _activeMeasurementMetric == null &&
      !_firstRingBindingPending &&
      _wearable is WearableHealthReminderHapticsBridge &&
      availabilityFor(DeviceFeature.findWatch).isReady;

  Future<bool> ringHapticPreference() async =>
      await safeSecureStorage.read(
        key: _ringLocalKey(homeHealthCardOwner, 'care-haptic'),
      ) ==
      'on';

  Future<void> saveRingHapticPreference(bool enabled) =>
      safeSecureStorage.write(
        key: _ringLocalKey(homeHealthCardOwner, 'care-haptic'),
        value: enabled ? 'on' : 'off',
      );

  Future<void> tryRingGreetingHaptic(
    String expectedContext,
    String device,
  ) async {
    if (expectedContext != ringExperienceOwner ||
        !ringCanReceiveHaptic ||
        connectedDevice?.id != device ||
        !await ringHapticPreference()) {
      return;
    }
    if (expectedContext != ringExperienceOwner ||
        !ringCanReceiveHaptic ||
        connectedDevice?.id != device) {
      return;
    }
    // A social alert never enters the medical notification pipeline.
    ringReminderVibrationBusy = true;
    try {
      await (_wearable as WearableHealthReminderHapticsBridge)
          .pulseHealthReminder(expectedDeviceId: device);
    } catch (_) {
      // The greeting is still available in the inbox. Do not replay a BLE write.
    } finally {
      ringReminderVibrationBusy = false;
    }
  }
}

extension RingFirmwareController on AppController {
  bool get ringFirmwareCandidate {
    const key = String.fromEnvironment('SAY_RING_FIRMWARE_PUBLIC_KEY');
    return ringExperience &&
        _ringCapabilities.firmware &&
        isAuthenticated &&
        key.isNotEmpty &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        connectedDevice?.sdkSource == WearableSdkSource.qring;
  }

  bool get ringFirmwareBusy => _ringFirmwareBusy;

  Future<RingFirmwarePackage?> findRingFirmware() async {
    if (!ringFirmwareCandidate || !_ringFirmwareIdle) return null;
    final device = connectedDevice!;
    final owner = ringExperienceOwner;
    final adapter = const QringIosFirmwareTransport();
    final identity = await adapter.identify(device.nativeId);
    if (identity == null || !_ringFirmwareSameTarget(owner, device)) {
      return null;
    }
    final build = int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
    if (build == null || !_ringFirmwareSameTarget(owner, device)) return null;

    final stateKey = _ringLocalKey(
      homeHealthCardOwner,
      'firmware-${sha256.convert(utf8.encode(device.id))}',
    );
    final pending = await safeSecureStorage.read(key: stateKey);
    if (!_ringFirmwareSameTarget(owner, device)) return null;
    if (pending != null) {
      final last = await adapter.identify(device.nativeId, fresh: true);
      if (last?.version != pending || !_ringFirmwareSameTarget(owner, device)) {
        throw const ApiException('上次升级待确认，请连接原设备核对固件版本');
      }
      await safeSecureStorage.delete(key: stateKey);
    }

    final envelope = await ringRequest(
      'POST',
      'firmware/lookup',
      data: identity.query(build),
    );
    if (!_ringFirmwareSameTarget(owner, device)) return null;
    return RingFirmwarePackage.verify(
      envelope: envelope,
      device: identity,
      build: build,
      now: DateTime.now(),
      encodedPublicKey: const String.fromEnvironment(
        'SAY_RING_FIRMWARE_PUBLIC_KEY',
      ),
    );
  }

  bool get _ringFirmwareIdle =>
      _appIsForeground &&
      !_ringFirmwareBusy &&
      deviceState == DeviceConnectionState.ready &&
      !isDeviceHistorySyncing &&
      !isDeviceReconnecting &&
      !ringReminderVibrationBusy &&
      !isSportStarting &&
      activeSport == null &&
      deviceFeatureBusy.isEmpty &&
      _activeMeasurementMetric == null &&
      !_firstRingBindingPending;

  bool _ringFirmwareSameTarget(String owner, DeviceInfo target) =>
      ringExperienceOwner == owner &&
      !_accountTransitioning &&
      connectedDevice?.id == target.id;

  Future<void> upgradeRingFirmware(
    RingFirmwarePackage release,
    void Function(RingFirmwarePhase) phase, {
    void Function(int)? onProgress,
  }) async {
    final device = connectedDevice;
    final owner = ringExperienceOwner;
    if (device == null ||
        !ringFirmwareCandidate ||
        !_ringFirmwareIdle ||
        !release.expiresAt.isAfter(DateTime.now())) {
      throw const ApiException('请刷新升级信息后重试');
    }
    final adapter = const QringIosFirmwareTransport();
    phase(RingFirmwarePhase.download);
    final bytes = await ringFile(
      'firmware/packages/${release.id}',
      RingFirmwarePackage.cap,
    );
    if (!release.accepts(bytes)) throw const ApiException('固件校验未通过');
    if (!_ringFirmwareSameTarget(owner, device) || !_ringFirmwareIdle) {
      throw const ApiException('设备状态已变化，请重试');
    }

    final freshOffer = await findRingFirmware();
    if (freshOffer?.id != release.id ||
        freshOffer?.sha256 != release.sha256 ||
        !_ringFirmwareSameTarget(owner, device) ||
        !_ringFirmwareIdle) {
      throw const ApiException('固件分发状态已变化，请重新检查');
    }
    if (freshOffer!.target.battery < release.minBattery) {
      throw const ApiException('设备电量不足，请充电后再试');
    }

    _setRingFirmwareBusy(true);
    final stateKey = _ringLocalKey(
      homeHealthCardOwner,
      'firmware-${sha256.convert(utf8.encode(device.id))}',
    );
    try {
      await safeSecureStorage.write(key: stateKey, value: release.version);
      if (!_ringFirmwareSameTarget(owner, device) || !_appIsForeground) {
        await safeSecureStorage.delete(key: stateKey);
        throw const ApiException('设备状态已变化，请重试');
      }
      phase(RingFirmwarePhase.transfer);
      await adapter.send(
        device.nativeId,
        release,
        bytes,
        onProgress: (value) {
          if (_ringFirmwareSameTarget(owner, device)) onProgress?.call(value);
        },
      );
      phase(RingFirmwarePhase.reboot);
      final deadline = DateTime.now().add(const Duration(seconds: 85));
      var verifying = false;
      while (DateTime.now().isBefore(deadline) &&
          owner == ringExperienceOwner &&
          !_disposed) {
        if (_ringFirmwareSameTarget(owner, device) &&
            deviceState == DeviceConnectionState.ready) {
          try {
            if (!verifying) {
              phase(RingFirmwarePhase.verify);
              verifying = true;
            }
            final actual = await adapter.identify(device.nativeId, fresh: true);
            if (_ringFirmwareSameTarget(owner, device) &&
                actual?.version == release.version &&
                actual?.hardware == release.target.hardware) {
              await safeSecureStorage.delete(key: stateKey);
              phase(RingFirmwarePhase.complete);
              return;
            }
          } catch (_) {
            // A reboot may temporarily close the link; poll readback only.
          }
        }
        await Future<void>.delayed(const Duration(seconds: 4));
      }
      throw const ApiException('尚未读回目标版本，请连接原设备核对');
    } finally {
      _setRingFirmwareBusy(false);
    }
  }
}
