import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../domain/ring_experience.dart';

final _qringFirmwareName = RegExp(
  r'^(?:SD[ _-]+RING[ _-]+)?(R8|R21)(?:[ _-]+[0-9A-F]{4,6})?$',
);

String? qringIosFirmwareModel(String name) =>
    _qringFirmwareName.firstMatch(name.trim().toUpperCase())?.group(1);

class RingFirmwareIdentity {
  const RingFirmwareIdentity({
    required this.platform,
    required this.transport,
    required this.model,
    required this.hardware,
    required this.version,
    required this.battery,
  });
  final String platform;
  final String transport;
  final String model;
  final String hardware;
  final String version;
  final int battery;

  String? get packageModel => switch ((
    transport,
    model.replaceAll(RegExp(r'[ _-]+'), '').toUpperCase(),
  )) {
    ('qring', 'R8' || 'R21') => 'R21',
    ('coolwear', 'R7PRO' || 'R7U' || 'R7ULTRA') => 'HR05',
    ('coolwear', 'R7' || 'R7Y') => 'HR01',
    _ => null,
  };

  Map<String, Object> query(int build) => {
    'platform': platform,
    'transport': transport,
    'model': model,
    'hardware': hardware,
    'fromVersion': version,
    'appBuild': build,
    'packageModel': ?packageModel,
  };

  bool describes(Map<String, Object?> payload) {
    final package = packageModel;
    return package != null &&
        package == payload['packageModel'] &&
        platform == payload['platform'] &&
        transport == payload['transport'] &&
        model == payload['model'] &&
        hardware == payload['hardware'] &&
        version == payload['fromVersion'];
  }
}

class RingFirmwarePackage {
  const RingFirmwarePackage._(
    this.id,
    this.version,
    this.sha256,
    this.bytes,
    this.minBattery,
    this.expiresAt,
    this.target,
  );

  final String id;
  final String version;
  final String sha256;
  final int bytes;
  final int minBattery;
  final DateTime expiresAt;
  final RingFirmwareIdentity target;

  static const cap = 8 * 1024 * 1024;

  static Future<RingFirmwarePackage?> verify({
    required Map<String, Object?> envelope,
    required RingFirmwareIdentity device,
    required int build,
    required String encodedPublicKey,
    required DateTime now,
  }) async {
    if (envelope['available'] != true) return null;
    final key = base64Url.decode(base64Url.normalize(encodedPublicKey));
    final encoded = '${envelope['payload']}';
    final encodedSignature = '${envelope['signature']}';
    if (key.length != 32 ||
        encoded.length > 4096 ||
        encodedSignature.length > 100) {
      throw const FormatException('Invalid firmware envelope');
    }
    final payload = base64Url.decode(base64Url.normalize(encoded));
    final signature = base64Url.decode(base64Url.normalize(encodedSignature));
    if (signature.length != 64 ||
        !await Ed25519().verify(
          payload,
          signature: Signature(
            signature,
            publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
          ),
        )) {
      throw const FormatException('Invalid firmware signature');
    }
    final row = ringMap(jsonDecode(utf8.decode(payload)));
    final signedUntil = DateTime.tryParse('${row['expiresAt']}');
    final minBuild = row['minBuild'];
    final minBattery = row['minBattery'];
    final bytes = row['bytes'];
    final id = '${row['id']}';
    final version = '${row['version']}';
    final sha = '${row['sha256']}';
    if (row['product'] != 'say-ring' ||
        !device.describes(row) ||
        signedUntil == null ||
        !signedUntil.isAfter(now) ||
        signedUntil.difference(now) > const Duration(minutes: 10) ||
        minBuild is! int ||
        minBuild <= 0 ||
        minBuild > build ||
        minBattery is! int ||
        minBattery < 1 ||
        minBattery > 100 ||
        bytes is! int ||
        bytes < 1 ||
        bytes > cap ||
        !RegExp(
          r'^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$',
        ).hasMatch(id) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9. _+-]{0,47}$').hasMatch(version) ||
        row['version'] is! String ||
        version == device.version ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) {
      throw const FormatException('Firmware does not match this device');
    }
    return RingFirmwarePackage._(
      id,
      version,
      sha,
      bytes,
      minBattery,
      signedUntil,
      device,
    );
  }

  bool accepts(Uint8List data) =>
      data.length == bytes && hashes.sha256.convert(data).toString() == sha256;
}

enum RingFirmwarePhase { download, transfer, reboot, verify, complete }

class QringIosFirmwareTransport {
  const QringIosFirmwareTransport();
  static const _channel = MethodChannel('cc.saidian.ring/qring/commands');

  Future<RingFirmwareIdentity?> identify(
    String nativeId, {
    bool fresh = false,
  }) async {
    final result = ringMap(
      await _channel
          .invokeMethod<Object?>('ringFirmwareIdentity', {
            'expectedDeviceId': nativeId,
            'fresh': fresh,
          })
          .timeout(const Duration(seconds: 15)),
    );
    if (result.isEmpty ||
        result['hardware'] is! String ||
        result['fromVersion'] is! String ||
        result['model'] is! String ||
        result['battery'] is! int) {
      return null;
    }
    final identity = RingFirmwareIdentity(
      platform: 'ios',
      transport: 'qring',
      model: result['model']! as String,
      hardware: result['hardware']! as String,
      version: result['fromVersion']! as String,
      battery: result['battery']! as int,
    );
    return identity.packageModel != null &&
            identity.packageModel == result['packageModel']
        ? identity
        : null;
  }

  Future<void> send(
    String nativeId,
    RingFirmwarePackage release,
    Uint8List data, {
    void Function(int)? onProgress,
  }) async {
    final operation = const Uuid().v4();
    final scope = {'expectedDeviceId': nativeId, 'operationId': operation};
    var reading = false, finished = false, last = -1;
    final timer = onProgress == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 400), (_) async {
            if (reading || finished) return;
            reading = true;
            try {
              final value = await _channel
                  .invokeMethod<int>('ringFirmwareProgress', scope)
                  .timeout(const Duration(seconds: 2));
              if (!finished && value != null && value > last && value <= 100) {
                last = value;
                onProgress(value);
              }
            } catch (_) {
              // Progress is informational. Only the SDK terminal result completes transfer.
            } finally {
              reading = false;
            }
          });
    try {
      await _channel
          .invokeMethod<void>('ringFirmwareTransfer', {
            ...release.target.query(0),
            ...scope,
            'data': data,
            'sha256': release.sha256,
            'minBattery': release.minBattery,
          })
          .timeout(const Duration(minutes: 7));
    } finally {
      finished = true;
      timer?.cancel();
    }
  }
}
