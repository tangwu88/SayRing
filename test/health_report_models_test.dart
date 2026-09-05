import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_report_models.dart';

void main() {
  test(
    'health profile preserves unknown values instead of inventing zeroes',
    () {
      final profile = HealthProfileSummary.fromMap(const {
        'memberId': 'member-1',
        'period': {'from': '2026-08-01T00:00:00.000Z'},
        'dataCompleteness': {
          'validRecordCount': 8,
          'distinctDays': 3,
          'metricCount': 2,
        },
        'metrics': [
          {
            'metric': 'heart_rate',
            'recordCount': 5,
            'latestObservedAt': '2026-08-03T08:00:00.000Z',
            'latestValue': 72,
          },
          {'metric': 'blood_oxygen', 'recordCount': 3, 'latestValue': null},
        ],
        'devices': [
          {'id': 'device-1', 'model': 'W8', 'displayName': '赛电手表'},
        ],
        'activeWarningCount': 1,
        'analysisConsent': {'granted': true, 'version': 'consent-v1'},
      });

      expect(profile.distinctDays, 3);
      expect(profile.metrics, hasLength(2));
      expect(profile.metrics.last.latestValue, isNull);
      expect(profile.devices.single.displayName, '赛电手表');
      expect(profile.analysisConsentGranted, isTrue);
      expect(profile.periodTo, isNull);
    },
  );

  test('report eligibility and status parse server wire values', () {
    final eligibility = HealthReportEligibility.fromMap(const {
      'eligible': false,
      'validRecordCount': 1,
      'distinctDays': 1,
      'minimumDistinctDays': 3,
      'missing': ['还需要至少2天有效记录'],
      'consentRequired': true,
      'availableCredits': 0,
    });
    final report = HealthReportSummary.fromMap(const {
      'id': 'report-12345678',
      'status': 'awaiting_payment',
      'dataCompleteness': {'validRecordCount': 12, 'distinctDays': 4},
      'freePreview': {'title': '近30天健康概览', 'summary': '已有4天数据'},
      'aiGenerated': false,
    });

    expect(eligibility.eligible, isFalse);
    expect(eligibility.missing.single, contains('2天'));
    expect(report.status, HealthReportStatus.awaitingPayment);
    expect(report.needsPayment, isTrue);
    expect(report.previewSummary, '已有4天数据');
  });

  test('offers, entitlements and payment keep versioned server values', () {
    final offer = HealthReportOffer.fromMap(const {
      'id': 'offer-1',
      'code': 'membership-30d',
      'title': '30天健康会员',
      'description': '含4份详细报告',
      'entitlement': 'membership',
      'priceCents': 1990,
      'currency': 'CNY',
      'creditCount': 4,
      'durationDays': 30,
      'appleProductId': 'cc.saidian.health.membership.30d',
      'version': 3,
    });
    final entitlement = HealthReportEntitlements.fromMap(const {
      'availableReportCredits': 3,
      'activeMembership': {
        'id': 'membership-1',
        'expiresAt': '2026-09-01T00:00:00.000Z',
        'remainingCredits': 3,
      },
    });
    final payment = HealthPaymentIntent.fromMap(const {
      'id': 'payment-1',
      'paymentNo': 'PAY001',
      'businessType': 'health_membership',
      'businessId': 'membership-1',
      'channel': 'apple_iap',
      'status': 'succeeded',
      'amountCents': 1990,
      'currency': 'CNY',
      'invoke': null,
      'createdAt': '2026-08-01T00:00:00.000Z',
    });

    expect(offer.isMembership, isTrue);
    expect(offer.version, 3);
    expect(entitlement.hasActiveMembership, isTrue);
    expect(entitlement.membershipRemainingCredits, 3);
    expect(payment.status, HealthPaymentStatus.succeeded);
    expect(payment.invoke, isEmpty);
  });
}
