enum HealthReportStatus {
  awaitingPayment,
  queued,
  generating,
  ready,
  failed,
  revoked,
  unknown;

  factory HealthReportStatus.fromWire(Object? value) =>
      switch ('$value'.trim().toLowerCase()) {
        'awaiting_payment' => HealthReportStatus.awaitingPayment,
        'queued' => HealthReportStatus.queued,
        'generating' => HealthReportStatus.generating,
        'ready' => HealthReportStatus.ready,
        'failed' => HealthReportStatus.failed,
        'revoked' => HealthReportStatus.revoked,
        _ => HealthReportStatus.unknown,
      };

  String get label => switch (this) {
    HealthReportStatus.awaitingPayment => '待解锁',
    HealthReportStatus.queued => '排队生成中',
    HealthReportStatus.generating => '正在生成',
    HealthReportStatus.ready => '已完成',
    HealthReportStatus.failed => '生成失败',
    HealthReportStatus.revoked => '权益已退款',
    HealthReportStatus.unknown => '状态待确认',
  };
}

class HealthProfileMetric {
  const HealthProfileMetric({
    required this.metric,
    required this.recordCount,
    required this.latestObservedAt,
    required this.latestValue,
  });

  final String metric;
  final int recordCount;
  final DateTime? latestObservedAt;
  final num? latestValue;

  factory HealthProfileMetric.fromMap(Map<String, Object?> map) =>
      HealthProfileMetric(
        metric: '${map['metric'] ?? ''}'.trim(),
        recordCount: _asInt(map['recordCount']),
        latestObservedAt: _asDate(map['latestObservedAt']),
        latestValue: map['latestValue'] is num
            ? map['latestValue'] as num
            : num.tryParse('${map['latestValue'] ?? ''}'),
      );
}

class HealthProfileDevice {
  const HealthProfileDevice({
    required this.id,
    required this.model,
    required this.displayName,
    required this.firmware,
    required this.lastSeenAt,
  });

  final String id;
  final String model;
  final String displayName;
  final String? firmware;
  final DateTime? lastSeenAt;

  factory HealthProfileDevice.fromMap(Map<String, Object?> map) =>
      HealthProfileDevice(
        id: '${map['id'] ?? ''}'.trim(),
        model: '${map['model'] ?? ''}'.trim(),
        displayName: '${map['displayName'] ?? ''}'.trim(),
        firmware: _nonEmpty(map['firmware']),
        lastSeenAt: _asDate(map['lastSeenAt']),
      );
}

class HealthProfileSummary {
  const HealthProfileSummary({
    required this.memberId,
    required this.periodFrom,
    required this.periodTo,
    required this.validRecordCount,
    required this.distinctDays,
    required this.metricCount,
    required this.metrics,
    required this.devices,
    required this.activeWarningCount,
    required this.analysisConsentGranted,
    required this.analysisConsentVersion,
    this.sourcePolicy = 'all',
    this.analysisConsentAvailableVersion,
    this.analysisConsentDocument,
  });

  final String memberId;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int validRecordCount;
  final int distinctDays;
  final int metricCount;
  final List<HealthProfileMetric> metrics;
  final List<HealthProfileDevice> devices;
  final int activeWarningCount;
  final bool analysisConsentGranted;
  final String? analysisConsentVersion;
  final String sourcePolicy;
  final String? analysisConsentAvailableVersion;
  final Map<String, Object?>? analysisConsentDocument;

  factory HealthProfileSummary.fromMap(Map<String, Object?> map) {
    final period = _asMap(map['period']);
    final completeness = _asMap(map['dataCompleteness']);
    final consent = _asMap(map['analysisConsent']);
    return HealthProfileSummary(
      memberId: '${map['memberId'] ?? ''}'.trim(),
      sourcePolicy: '${map['sourcePolicy'] ?? 'all'}'.trim(),
      periodFrom: _asDate(period['from']),
      periodTo: _asDate(period['to']),
      validRecordCount: _asInt(completeness['validRecordCount']),
      distinctDays: _asInt(completeness['distinctDays']),
      metricCount: _asInt(completeness['metricCount']),
      metrics: _asMapList(map['metrics'])
          .map(HealthProfileMetric.fromMap)
          .where((metric) => metric.metric.isNotEmpty)
          .toList(growable: false),
      devices: _asMapList(map['devices'])
          .map(HealthProfileDevice.fromMap)
          .where((device) => device.id.isNotEmpty)
          .toList(growable: false),
      activeWarningCount: _asInt(map['activeWarningCount']),
      analysisConsentGranted: consent['granted'] == true,
      analysisConsentVersion: _nonEmpty(consent['version']),
      analysisConsentAvailableVersion: _nonEmpty(consent['availableVersion']),
      analysisConsentDocument: consent['document'] is Map
          ? _asMap(consent['document'])
          : null,
    );
  }
}

class HealthReportEligibility {
  const HealthReportEligibility({
    required this.eligible,
    required this.periodFrom,
    required this.periodTo,
    required this.validRecordCount,
    required this.distinctDays,
    required this.minimumDistinctDays,
    required this.missing,
    required this.consentRequired,
    required this.availableCredits,
    this.sourcePolicy = 'all',
  });

  final bool eligible;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int validRecordCount;
  final int distinctDays;
  final int minimumDistinctDays;
  final List<String> missing;
  final bool consentRequired;
  final int availableCredits;
  final String sourcePolicy;

  factory HealthReportEligibility.fromMap(Map<String, Object?> map) {
    final period = _asMap(map['period']);
    return HealthReportEligibility(
      eligible: map['eligible'] == true,
      sourcePolicy: '${map['sourcePolicy'] ?? 'all'}'.trim(),
      periodFrom: _asDate(period['from']),
      periodTo: _asDate(period['to']),
      validRecordCount: _asInt(map['validRecordCount']),
      distinctDays: _asInt(map['distinctDays']),
      minimumDistinctDays: _asInt(map['minimumDistinctDays']),
      missing: _asStrings(map['missing']),
      consentRequired: map['consentRequired'] == true,
      availableCredits: _asInt(map['availableCredits']),
    );
  }
}

class HealthReportSummary {
  const HealthReportSummary({
    required this.id,
    required this.status,
    required this.periodFrom,
    required this.periodTo,
    required this.validRecordCount,
    required this.distinctDays,
    required this.freePreview,
    required this.aiGenerated,
    required this.aiLabel,
    required this.generatedAt,
    required this.createdAt,
    required this.needsPayment,
    this.sourcePolicy = 'all',
  });

  final String id;
  final HealthReportStatus status;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int validRecordCount;
  final int distinctDays;
  final Map<String, Object?> freePreview;
  final bool aiGenerated;
  final String aiLabel;
  final DateTime? generatedAt;
  final DateTime? createdAt;
  final bool needsPayment;
  final String sourcePolicy;

  String get previewTitle => _nonEmpty(freePreview['title']) ?? '近30天健康概览';

  String get previewSummary => _nonEmpty(freePreview['summary']) ?? '报告信息正在准备';

  factory HealthReportSummary.fromMap(Map<String, Object?> map) {
    final period = _asMap(map['period']);
    final completeness = _asMap(map['dataCompleteness']);
    final status = HealthReportStatus.fromWire(map['status']);
    return HealthReportSummary(
      id: '${map['id'] ?? ''}'.trim(),
      sourcePolicy: '${map['sourcePolicy'] ?? 'all'}'.trim(),
      status: status,
      periodFrom: _asDate(period['from']),
      periodTo: _asDate(period['to']),
      validRecordCount: _asInt(completeness['validRecordCount']),
      distinctDays: _asInt(completeness['distinctDays']),
      freePreview: _asMap(map['freePreview']),
      aiGenerated: map['aiGenerated'] == true,
      aiLabel: _nonEmpty(map['aiLabel']) ?? '健康数据概览',
      generatedAt: _asDate(map['generatedAt']),
      createdAt: _asDate(map['createdAt']),
      needsPayment:
          map['needsPayment'] == true ||
          status == HealthReportStatus.awaitingPayment,
    );
  }
}

enum HealthReportEntitlement { singleReport, membership, unknown }

class HealthReportOffer {
  const HealthReportOffer({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.entitlement,
    required this.priceCents,
    required this.currency,
    required this.creditCount,
    required this.durationDays,
    required this.appleProductId,
    required this.version,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final HealthReportEntitlement entitlement;
  final int priceCents;
  final String currency;
  final int creditCount;
  final int? durationDays;
  final String? appleProductId;
  final int version;

  bool get isMembership => entitlement == HealthReportEntitlement.membership;

  factory HealthReportOffer.fromMap(Map<String, Object?> map) {
    final entitlement = switch ('${map['entitlement'] ?? ''}') {
      'single_report' => HealthReportEntitlement.singleReport,
      'membership' => HealthReportEntitlement.membership,
      _ => HealthReportEntitlement.unknown,
    };
    return HealthReportOffer(
      id: '${map['id'] ?? ''}'.trim(),
      code: '${map['code'] ?? ''}'.trim(),
      title: '${map['title'] ?? ''}'.trim(),
      description: '${map['description'] ?? ''}'.trim(),
      entitlement: entitlement,
      priceCents: _asInt(map['priceCents']),
      currency: '${map['currency'] ?? 'CNY'}'.trim(),
      creditCount: _asInt(map['creditCount']),
      durationDays: _asNullableInt(map['durationDays']),
      appleProductId: _nonEmpty(map['appleProductId']),
      version: _asInt(map['version']),
    );
  }
}

class HealthReportEntitlements {
  const HealthReportEntitlements({
    required this.availableReportCredits,
    required this.membershipId,
    required this.membershipExpiresAt,
    required this.membershipRemainingCredits,
  });

  final int availableReportCredits;
  final String? membershipId;
  final DateTime? membershipExpiresAt;
  final int membershipRemainingCredits;

  bool get hasActiveMembership => membershipId != null;

  factory HealthReportEntitlements.fromMap(Map<String, Object?> map) {
    final membership = _asMap(map['activeMembership']);
    return HealthReportEntitlements(
      availableReportCredits: _asInt(map['availableReportCredits']),
      membershipId: _nonEmpty(membership['id']),
      membershipExpiresAt: _asDate(membership['expiresAt']),
      membershipRemainingCredits: _asInt(membership['remainingCredits']),
    );
  }
}

enum HealthPaymentStatus {
  created,
  pending,
  succeeded,
  failed,
  closed,
  refunding,
  partialRefunded,
  refunded,
  unknown;

  factory HealthPaymentStatus.fromWire(Object? value) =>
      switch ('$value'.trim().toLowerCase()) {
        'created' => HealthPaymentStatus.created,
        'pending' => HealthPaymentStatus.pending,
        'succeeded' => HealthPaymentStatus.succeeded,
        'failed' => HealthPaymentStatus.failed,
        'closed' => HealthPaymentStatus.closed,
        'refunding' => HealthPaymentStatus.refunding,
        'partial_refunded' => HealthPaymentStatus.partialRefunded,
        'refunded' => HealthPaymentStatus.refunded,
        _ => HealthPaymentStatus.unknown,
      };
}

class HealthPaymentIntent {
  const HealthPaymentIntent({
    required this.id,
    required this.paymentNo,
    required this.businessType,
    required this.businessId,
    required this.channel,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.invoke,
    required this.createdAt,
  });

  final String id;
  final String paymentNo;
  final String businessType;
  final String businessId;
  final String channel;
  final HealthPaymentStatus status;
  final int amountCents;
  final String currency;
  final Map<String, Object?> invoke;
  final DateTime? createdAt;

  factory HealthPaymentIntent.fromMap(Map<String, Object?> map) =>
      HealthPaymentIntent(
        id: '${map['id'] ?? ''}'.trim(),
        paymentNo: '${map['paymentNo'] ?? ''}'.trim(),
        businessType: '${map['businessType'] ?? ''}'.trim(),
        businessId: '${map['businessId'] ?? ''}'.trim(),
        channel: '${map['channel'] ?? ''}'.trim(),
        status: HealthPaymentStatus.fromWire(map['status']),
        amountCents: _asInt(map['amountCents']),
        currency: '${map['currency'] ?? 'CNY'}'.trim(),
        invoke: _asMap(map['invoke']),
        createdAt: _asDate(map['createdAt']),
      );
}

class HealthReportDashboard {
  const HealthReportDashboard({
    required this.profile,
    required this.eligibility,
    required this.entitlements,
    required this.offers,
    required this.reports,
  });

  final HealthProfileSummary profile;
  final HealthReportEligibility eligibility;
  final HealthReportEntitlements entitlements;
  final List<HealthReportOffer> offers;
  final List<HealthReportSummary> reports;
}

enum HealthPurchaseFlowState {
  succeeded,
  awaitingConfirmation,
  pendingApproval,
  cancelled,
}

class HealthPurchaseFlowResult {
  const HealthPurchaseFlowResult({
    required this.state,
    required this.intent,
    required this.message,
  });

  final HealthPurchaseFlowState state;
  final HealthPaymentIntent intent;
  final String message;
}

Map<String, Object?> _asMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, Object?>{};

List<Map<String, Object?>> _asMapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((map) => map.map((key, value) => MapEntry('$key', value)))
          .toList(growable: false)
    : const [];

List<String> _asStrings(Object? value) => value is List
    ? value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

int _asInt(Object? value) => _asNullableInt(value) ?? 0;

int? _asNullableInt(Object? value) => switch (value) {
  int number => number,
  num number when number.isFinite => number.toInt(),
  _ => int.tryParse('$value'.trim()),
};

DateTime? _asDate(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : DateTime.tryParse(text);
}

String? _nonEmpty(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}
