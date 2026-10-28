import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'health_reminder.dart';
import 'models.dart';

enum HeartRateObservationContext { unknown, resting, exercising, sleeping }

/// A reviewed rule is an explicit, versioned contract, not a user threshold.
/// Production currently supplies no reviewed contracts. Test fixtures cannot
/// activate the production factory or bypass the existing iOS release ceiling.
final class HeartRateReminderRule {
  const HeartRateReminderRule({
    required this.version,
    required this.reviewReference,
    required this.expiresAt,
    required this.platform,
    required this.model,
    required this.firmware,
    required this.lower,
    required this.upper,
    required this.minimumSamples,
    required this.minimumSpan,
    required this.maximumGap,
    required this.maximumAge,
    required this.acceptedQuality,
    required this.context,
    required this.recoverySamples,
    required this.recoverySpan,
  });

  final String version;
  final String reviewReference;
  final DateTime expiresAt;
  final String platform;
  final String model;
  final String firmware;
  final double lower;
  final double upper;
  final int minimumSamples;
  final Duration minimumSpan;
  final Duration maximumGap;
  final Duration maximumAge;
  final Set<String> acceptedQuality;
  final HeartRateObservationContext context;
  final int recoverySamples;
  final Duration recoverySpan;

  bool validAt(DateTime now) =>
      version.trim().isNotEmpty &&
      reviewReference.trim().isNotEmpty &&
      expiresAt.isAfter(now) &&
      platform.isNotEmpty &&
      model.isNotEmpty &&
      firmware.isNotEmpty &&
      lower.isFinite &&
      upper.isFinite &&
      lower > 0 &&
      upper > lower &&
      minimumSamples >= 2 &&
      minimumSamples <= 512 &&
      minimumSpan > Duration.zero &&
      maximumGap > Duration.zero &&
      maximumAge >= minimumSpan &&
      acceptedQuality.isNotEmpty &&
      acceptedQuality.every(
        (quality) =>
            quality.trim().isNotEmpty &&
            quality.trim().toLowerCase() != 'unknown',
      ) &&
      recoverySamples >= 2 &&
      recoverySamples <= 512 &&
      recoverySpan > Duration.zero &&
      recoverySpan <= maximumAge &&
      context != HeartRateObservationContext.unknown;
}

final class HeartRateReminderCandidate {
  const HeartRateReminderCandidate({required this.id, required this.details});
  final String id;
  final HealthReminderDetails details;
}

/// Processes fresh live observations only. A history read is not a live stream.
final class HeartRateReminderEngine {
  HeartRateReminderEngine({List<HeartRateReminderRule> rules = const []})
    : rules = List.unmodifiable(rules);

  final List<HeartRateReminderRule> rules;
  String? _scope;
  HealthReminderKind? _direction;
  final List<HealthRecord> _window = [];
  final Set<String> _seen = {};
  bool _emitted = false;
  int _recoveryCount = 0;
  DateTime? _recoveryStarted;

  bool configuredAt(DateTime now) => rules.any((rule) => rule.validAt(now));

  bool supportsDevice(DeviceInfo device, String platform, DateTime now) =>
      rules
          .where(
            (rule) =>
                rule.validAt(now) &&
                rule.platform == platform &&
                rule.model == device.model &&
                rule.firmware == device.firmwareVersion,
          )
          .length ==
      1;

  void reset() {
    _scope = null;
    _direction = null;
    _window.clear();
    _seen.clear();
    _emitted = false;
    _recoveryCount = 0;
    _recoveryStarted = null;
  }

  HeartRateReminderCandidate? observe({
    required HealthRecord record,
    required String owner,
    required DeviceInfo device,
    required String platform,
    required DateTime now,
    required bool live,
    required HeartRateObservationContext context,
  }) {
    final applicable = rules
        .where(
          (rule) =>
              rule.validAt(now) &&
              rule.platform == platform &&
              rule.model == device.model &&
              rule.firmware == device.firmwareVersion,
        )
        .toList(growable: false);
    if (applicable.length != 1 || owner.isEmpty || owner == 'anonymous') {
      reset();
      return null;
    }
    final rule = applicable.single;
    final scope = '$owner|${device.id}|${rule.version}';
    if (_scope != scope) {
      reset();
      _scope = scope;
    }
    if (record.metric != HealthMetric.heartRate) return null;
    final value = record.values['value'];
    final valid =
        live &&
        record.id.isNotEmpty &&
        record.deviceId == device.id &&
        record.firmwareVersion == rule.firmware &&
        record.source == MeasurementSource.wearable &&
        (record.origin == MeasurementOrigin.appMeasurement ||
            record.origin == MeasurementOrigin.watchHistory) &&
        record.unit == 'bpm' &&
        value != null &&
        value.isFinite &&
        value > 0 &&
        !record.measuredAt.isAfter(now) &&
        now.difference(record.measuredAt) <= rule.maximumAge &&
        rule.acceptedQuality.contains(record.quality) &&
        context == rule.context;
    if (!valid) {
      _clearWindow();
      return null;
    }
    if (_seen.contains(record.id)) return null;
    if (_window.isNotEmpty &&
        !record.measuredAt.isAfter(_window.last.measuredAt)) {
      // Out-of-order data may be stored as history but cannot extend a current
      // observation window or make a past event look current.
      return null;
    }
    final direction = value > rule.upper
        ? HealthReminderKind.highHeartRate
        : value < rule.lower
        ? HealthReminderKind.lowHeartRate
        : null;
    if (direction == null) {
      if (_emitted) {
        if (_window.isNotEmpty &&
            record.measuredAt.difference(_window.last.measuredAt) >
                rule.maximumGap) {
          _recoveryCount = 0;
          _recoveryStarted = null;
        }
        _recoveryStarted ??= record.measuredAt;
        _recoveryCount++;
        _window
          ..clear()
          ..add(record);
        _seen
          ..clear()
          ..add(record.id);
        if (_recoveryCount >= rule.recoverySamples &&
            record.measuredAt.difference(_recoveryStarted!) >=
                rule.recoverySpan) {
          _clearWindow();
        }
        return null;
      }
      _clearWindow();
      return null;
    }
    _recoveryCount = 0;
    _recoveryStarted = null;
    if (_direction != direction ||
        (_window.isNotEmpty &&
            now.difference(_window.first.measuredAt) > rule.maximumAge) ||
        (_window.isNotEmpty &&
            record.measuredAt.difference(_window.last.measuredAt) >
                rule.maximumGap)) {
      _clearWindow();
    }
    _direction = direction;
    if (_emitted) {
      _window
        ..clear()
        ..add(record);
      _seen
        ..clear()
        ..add(record.id);
      return null;
    }
    _seen.add(record.id);
    _window.add(record);
    if (_window.length > 2048) {
      _clearWindow();
      return null;
    }
    if (_window.length < rule.minimumSamples ||
        record.measuredAt.difference(_window.first.measuredAt) <
            rule.minimumSpan) {
      return null;
    }
    _emitted = true;
    final id = sha256.convert(
      utf8.encode('$scope|${direction.wireName}|${_window.first.id}'),
    );
    return HeartRateReminderCandidate(
      id: 'reminder-$id',
      details: HealthReminderDetails(
        kind: direction,
        recordedAt: now.toUtc(),
        measuredAt: record.measuredAt.toUtc(),
        reading: value.toDouble(),
        deviceName: device.displayName,
        ruleVersion: rule.version,
        sampleIds: List.unmodifiable(_window.map((item) => item.id)),
      ),
    );
  }

  void _clearWindow() {
    _window.clear();
    _seen.clear();
    _direction = null;
    _emitted = false;
    _recoveryCount = 0;
    _recoveryStarted = null;
  }
}
