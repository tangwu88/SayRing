import 'global_account.dart';

enum CareInvitationMethod { contact, memberId }

class CareInvitationTarget {
  const CareInvitationTarget._(this.method, this.value);

  factory CareInvitationTarget.contact(String input) => CareInvitationTarget._(
    CareInvitationMethod.contact,
    GlobalAccountIdentity.parse(input).identifier,
  );

  factory CareInvitationTarget.memberId(String input) {
    final value = input.trim();
    if (!RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(value) ||
        int.parse(value) > 2147483647) {
      throw const FormatException('Invalid member number');
    }
    return CareInvitationTarget._(CareInvitationMethod.memberId, value);
  }

  final CareInvitationMethod method;
  final String value;
  Map<String, Object?> toJson() => {
    method == CareInvitationMethod.memberId ? 'memberNo' : 'identifier': value,
  };
}

class GlobalCareRelationship {
  const GlobalCareRelationship({
    required this.id,
    required this.status,
    required this.received,
    required this.name,
    required this.metrics,
    this.expiresAt,
    this.memberNo,
  });
  final String id;
  final String status;
  final bool received;
  final String name;
  final Set<String> metrics;
  final DateTime? expiresAt;
  final String? memberNo;
  bool get expired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());
  bool get active => status == 'active' && !expired;
  factory GlobalCareRelationship.fromJson(Map<String, Object?> value) {
    final id = value['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing care identifier');
    }
    final received = value['direction'] == 'received';
    final person = value[received ? 'inviter' : 'recipient'];
    return GlobalCareRelationship(
      id: id,
      status: '${value['status'] ?? ''}',
      received: received,
      name: person is Map ? '${person['nickname'] ?? ''}' : '',
      memberNo: person is Map ? _memberNo(person['memberNo']) : null,
      metrics: (value['metrics'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      expiresAt: DateTime.tryParse('${value['expiresAt'] ?? ''}'),
    );
  }

  static String? _memberNo(Object? value) {
    if (value is! String) return null;
    try {
      return CareInvitationTarget.memberId(value).value;
    } on FormatException {
      return null;
    }
  }
}

/// Calendar midnights, not fixed 24-hour durations, preserve DST boundaries.
({DateTime from, DateTime to}) globalLocalDayRange(DateTime date) => (
  from: DateTime(date.year, date.month, date.day).toUtc(),
  to: DateTime(date.year, date.month, date.day + 1).toUtc(),
);
