part of 'app_controller.dart';

extension HealthReminderController on AppController {
  Future<void> _loadReadingReminderSettings(int generation) async {
    var value = const ReadingReminderSettings();
    final store = _healthStore;
    try {
      if (store is ReadingReminderSettingsStore) {
        value =
            ReadingReminderSettings.parse(
              await (store as ReadingReminderSettingsStore)
                  .readReadingReminderSettings(),
            ) ??
            value;
      }
    } catch (_) {
      /* Failed configuration reads keep all reminders disabled. */
    }
    if (!_isCurrentSessionGeneration(generation)) return;
    readingReminderSettings = value;
    _readingReminderSettingsRevision++;
    _readingReminderEngine.reset();
  }

  Future<bool> _saveReadingReminderSettings(
    ReadingReminderSettings value,
    String expectedOwner,
  ) async {
    if (!value.valid ||
        expectedOwner != homeHealthCardOwner ||
        !canSaveHealthReminder ||
        readingReminderSettingsSaving ||
        _healthStore is! ReadingReminderSettingsStore) {
      return false;
    }
    final generation = _sessionGeneration;
    readingReminderSettingsSaving = true;
    _notifyHealthReminderListeners();
    try {
      await (_healthStore as ReadingReminderSettingsStore)
          .saveReadingReminderSettings(jsonEncode(value.toJson()));
      if (!_isCurrentSessionGeneration(generation) || !canSaveHealthReminder) {
        return false;
      }
      readingReminderSettings = value;
      _readingReminderSettingsRevision++;
      _readingReminderEngine.reset();
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_isCurrentSessionGeneration(generation)) {
        readingReminderSettingsSaving = false;
        _notifyHealthReminderListeners();
      }
    }
  }

  void _observePersonalReading(HealthRecord record, int generation, bool live) {
    final device = connectedDevice;
    if (device == null ||
        !canSaveHealthReminder ||
        !_isCurrentSessionGeneration(generation) ||
        !isMetricAvailableInRelease(record.metric) ||
        (isWellnessOnly &&
            !healthReleasePolicy.allowsManualMeasurement(record.metric))) {
      return;
    }
    final candidate = _readingReminderEngine.observe(
      record: record,
      device: device,
      owner: _healthOwnerFor(session),
      settings: readingReminderSettings,
      now: DateTime.now().toUtc(),
      live: live,
    );
    if (candidate == null ||
        healthWarningAlerts.any((e) => e.id == candidate.id)) {
      return;
    }
    final unit = candidate.metric == HealthMetric.bloodOxygen ? '%' : 'bpm';
    final settingsRevision = _readingReminderSettingsRevision;
    bool canPresent() =>
        _isCurrentSessionGeneration(generation) &&
        canSaveHealthReminder &&
        connectedDevice?.id == device.id &&
        settingsRevision == _readingReminderSettingsRevision &&
        isMetricAvailableInRelease(record.metric) &&
        (!isWellnessOnly ||
            healthReleasePolicy.allowsManualMeasurement(record.metric)) &&
        DateTime.now().toUtc().difference(record.measuredAt) <=
            const Duration(seconds: 90);
    final event = HealthWarningAlert(
      id: candidate.id,
      metric: candidate.metric,
      title: candidate.details.kind.label,
      message:
          '本次测量 ${candidate.details.reading!.toStringAsFixed(0)} $unit 超出设定范围，请静坐并复测。',
      triggeredAt: record.measuredAt,
      origin: record.origin,
      reminder: candidate.details,
    );
    unawaited(() async {
      if (!await _saveReminderEvent(event, generation) || !canPresent()) {
        return;
      }
      activeHealthWarningAlert = event;
      _notifyHealthReminderListeners();
      try {
        final owner = _healthOwnerFor(session);
        final requested = await _healthReminderNotifications.show(
          owner: owner,
          eventId: event.id,
        );
        if (requested && _isCurrentSessionGeneration(generation)) {
          await updateHealthReminderAction(
            event.id,
            expectedOwner: owner,
            notificationRequested: true,
          );
        }
      } catch (_) {
        /* Local alert remains usable when the system cannot notify. */
      }
    }());
  }

  bool get _canSaveHealthReminder =>
      isAuthenticated &&
      !isPreviewMode &&
      _notificationStorageReady &&
      _activeHealthOwner == _healthOwnerFor(session);

  bool get _automaticHealthRemindersAvailable {
    final device = connectedDevice;
    return healthAlertsAvailable &&
        device != null &&
        capabilities?.metrics.contains(HealthMetric.heartRate) == true &&
        _heartRateReminders.supportsDevice(
          device,
          defaultTargetPlatform.name,
          DateTime.now(),
        );
  }

  List<HealthWarningAlert> get _healthReminderEvents => healthWarningAlerts
      .where((event) => event.reminder != null)
      .toList(growable: false);

  bool _canOpenHealthReminderEvent(String? id) =>
      id != null && healthReminderEvents.any((event) => event.id == id);

  Future<void> _refreshHealthReminderPermissions({bool request = false}) async {
    final generation = _sessionGeneration;
    final permission = await _healthReminderNotifications.permission(
      request: request,
    );
    if (!_isCurrentSessionGeneration(generation)) return;
    healthReminderNotificationPermission = permission;
    _notifyHealthReminderListeners();
  }

  Future<HealthWarningAlert?> _recordHealthReminderSymptoms(
    Set<HealthReminderSymptom> symptoms,
  ) async {
    if (!canSaveHealthReminder || symptoms.isEmpty) return null;
    final generation = _sessionGeneration;
    final now = DateTime.now().toUtc();
    final details = HealthReminderDetails(
      kind: HealthReminderKind.symptoms,
      recordedAt: now,
      symptoms: Set.unmodifiable(symptoms),
    );
    final event = HealthWarningAlert(
      id: 'symptom-${const Uuid().v4()}',
      metric: HealthMetric.heartRate,
      title: '不适记录',
      message: symptoms.map((item) => item.label).join('、'),
      triggeredAt: now,
      origin: MeasurementOrigin.manualEntry,
      reminder: details,
    );
    final saved = await _saveReminderEvent(event, generation);
    return saved ? event : null;
  }

  Future<bool> _saveReminderEvent(
    HealthWarningAlert event,
    int generation,
  ) async {
    if (!_isCurrentSessionGeneration(generation) || !canSaveHealthReminder) {
      return false;
    }
    try {
      await _healthStore.saveHealthWarningAlert(event);
      if (!_isCurrentSessionGeneration(generation)) return false;
      healthWarningAlerts = [
        event,
        ...healthWarningAlerts.where((item) => item.id != event.id),
      ]..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      _notifyHealthReminderListeners();
      return true;
    } catch (_) {
      if (_isCurrentSessionGeneration(generation)) {
        errorMessage = '本机记录暂时无法保存，请稍后重试';
        _notifyHealthReminderListeners();
      }
      return false;
    }
  }

  Future<bool> _updateHealthReminderAction(
    String id, {
    required String expectedOwner,
    bool acknowledged = false,
    bool dialRequested = false,
    bool notificationRequested = false,
  }) {
    final generation = _sessionGeneration;
    final result = _healthReminderWrites.then((_) async {
      if (!_isCurrentSessionGeneration(generation) ||
          expectedOwner != homeHealthCardOwner ||
          !canSaveHealthReminder) {
        return false;
      }
      final event = healthReminderEvents
          .where((item) => item.id == id)
          .firstOrNull;
      if (event == null) return false;
      final detail = event.reminder!;
      final now = DateTime.now().toUtc();
      return _saveReminderEvent(
        event.withReminder(
          detail.copyWith(
            acknowledgedAt: acknowledged ? detail.acknowledgedAt ?? now : null,
            dialRequestedAt: dialRequested
                ? detail.dialRequestedAt ?? now
                : null,
            notificationRequestedAt: notificationRequested
                ? detail.notificationRequestedAt ?? now
                : null,
          ),
        ),
        generation,
      );
    });
    _healthReminderWrites = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  String? _healthReminderCsv(String id, {required String expectedOwner}) {
    if (!canSaveHealthReminder || expectedOwner != homeHealthCardOwner) {
      return null;
    }
    final event = healthWarningAlerts
        .where((item) => item.id == id)
        .firstOrNull;
    return event == null ? null : buildHealthReminderCsv(event);
  }

  Future<bool> _deleteHealthReminder(
    String id, {
    required String expectedOwner,
  }) {
    final generation = _sessionGeneration;
    final result = _healthReminderWrites.then((_) async {
      final store = _healthStore;
      if (!_isCurrentSessionGeneration(generation) ||
          expectedOwner != homeHealthCardOwner ||
          !canSaveHealthReminder ||
          !canOpenHealthReminderEvent(id) ||
          store is! HealthReminderDeletionStore) {
        return false;
      }
      try {
        await (store as HealthReminderDeletionStore).deleteHealthReminder(id);
        if (!_isCurrentSessionGeneration(generation)) return false;
        healthWarningAlerts = healthWarningAlerts
            .where((item) => item.id != id)
            .toList();
        if (activeHealthWarningAlert?.id == id) activeHealthWarningAlert = null;
        _notifyHealthReminderListeners();
        await _healthReminderNotifications.cancel(id);
        return _isCurrentSessionGeneration(generation);
      } catch (_) {
        return false;
      }
    });
    _healthReminderWrites = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _consumeHealthReminderOpen() async {
    final generation = _sessionGeneration;
    final opened = await _healthReminderNotifications.consumeOpen();
    if (!_isCurrentSessionGeneration(generation) ||
        session == null ||
        opened == null ||
        opened.owner != _healthOwnerFor(session) ||
        !canOpenHealthReminderEvent(opened.eventId)) {
      return;
    }
    pendingNotificationRoute = NotificationRouteIntent(
      target: NotificationRouteTarget.healthWarningHistory,
      eventId: 'local-${opened.eventId}',
      entityId: opened.eventId,
    );
    _notifyHealthReminderListeners();
  }

  void _observeHealthReminder(
    HealthRecord record, {
    required int expectedGeneration,
    required bool live,
  }) {
    _observePersonalReading(record, expectedGeneration, live);
    if (!_isCurrentSessionGeneration(expectedGeneration) ||
        !automaticHealthRemindersAvailable ||
        !canSaveHealthReminder) {
      return;
    }
    final device = connectedDevice;
    if (device == null) return;
    final candidate = _heartRateReminders.observe(
      record: record,
      owner: _healthOwnerFor(session),
      device: device,
      platform: defaultTargetPlatform.name,
      now: DateTime.now().toUtc(),
      live: live && record.origin == MeasurementOrigin.appMeasurement,
      // No verified context contract exists in the current ring adapters.
      // A future adapter must provide a reviewed context, never infer rest
      // from a low step total, a settings interval or a user-entered number.
      context: HeartRateObservationContext.unknown,
    );
    if (candidate == null ||
        healthWarningAlerts.any((event) => event.id == candidate.id)) {
      return;
    }
    final event = HealthWarningAlert(
      id: candidate.id,
      metric: HealthMetric.heartRate,
      title: candidate.details.kind.label,
      message: '心率记录 ${candidate.details.reading} bpm，请查看测量时间与记录。',
      triggeredAt: record.measuredAt,
      origin: record.origin,
      reminder: candidate.details,
    );
    unawaited(() async {
      if (!await _saveReminderEvent(event, expectedGeneration) ||
          !_isCurrentSessionGeneration(expectedGeneration)) {
        return;
      }
      activeHealthWarningAlert = event;
      _notifyHealthReminderListeners();
      try {
        final owner = _healthOwnerFor(session);
        final requested = await _healthReminderNotifications.show(
          owner: owner,
          eventId: event.id,
        );
        if (requested && _isCurrentSessionGeneration(expectedGeneration)) {
          await updateHealthReminderAction(
            event.id,
            expectedOwner: owner,
            notificationRequested: true,
          );
        }
      } catch (_) {
        // The event remains visible locally; a request failure is not delivery.
      }
    }());
  }
}
