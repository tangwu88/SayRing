import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// No query, headers, response bodies, member IDs or health values in logs.
abstract final class NetworkAudit {
  static final List<Map<String, Object?>> _recent = [];
  static List<Map<String, Object?>> get recent =>
      List.unmodifiable(_recent.map(Map<String, Object?>.unmodifiable));

  static void record(
    Uri uri,
    String method,
    String kind, {
    int? status,
    String? requestId,
    String? outcome,
  }) {
    final safeId =
        requestId != null && RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(requestId)
        ? requestId
        : null;
    final event = <String, Object?>{
      'host': uri.host,
      'port': uri.port,
      'method': method,
      'kind': kind,
      'routeHash': sha256
          .convert(utf8.encode(uri.path))
          .toString()
          .substring(0, 12),
      'status': ?status,
      'requestId': ?safeId,
      'outcome': ?outcome,
    };
    if (kDebugMode) {
      _recent.add(Map.unmodifiable(event));
      if (_recent.length > 200) _recent.removeAt(0);
      debugPrint('[SaydianNetwork] ${jsonEncode(event)}');
    }
  }
}
