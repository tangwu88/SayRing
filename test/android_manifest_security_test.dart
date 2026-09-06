import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android host overrides unsafe transitive manifest defaults', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final networkConfig = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    final extractionRules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(networkConfig, contains('cleartextTrafficPermitted="false"'));
    expect(extractionRules, contains('<cloud-backup>'));
    expect(extractionRules, contains('<device-transfer>'));
    expect(
      RegExp(
        r'<exclude domain="database" path="\."\s*/>',
      ).allMatches(extractionRules).length,
      2,
    );

    for (final feature in const <String>[
      'android.hardware.camera',
      'android.hardware.camera.autofocus',
      'android.hardware.camera.any',
    ]) {
      expect(
        RegExp(
          'android:name="$feature"\\s+android:required="false"',
        ).hasMatch(manifest),
        isTrue,
        reason: '$feature must remain optional',
      );
    }

    expect(
      RegExp(
        'android:name="android.permission.QUERY_ALL_PACKAGES"[\\s\\S]*?'
        'tools:node="remove"',
      ).hasMatch(manifest),
      isTrue,
    );

    for (final permission in const <String>[
      'android.permission.BLUETOOTH_ADVERTISE',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.RECORD_AUDIO',
    ]) {
      expect(
        RegExp(
          '<uses-permission\\s+android:name="$permission"\\s+'
          'tools:node="remove"\\s*/>',
        ).hasMatch(manifest),
        isTrue,
        reason: '$permission must not leak in from a vendor manifest',
      );
    }

    for (final component in const <String>[
      'com.yucheng.ycbtsdk.upgrade.utils.DfuService',
      'org.eclipse.paho.android.service.MqttService',
      'no.nordicsemi.android.support.v18.scanner.PendingIntentReceiver',
    ]) {
      expect(
        RegExp(
          'android:name="$component"[\\s\\S]*?'
          'android:exported="false"[\\s\\S]*?'
          'tools:replace="android:exported"',
        ).hasMatch(manifest),
        isTrue,
        reason: '$component must remain app-internal',
      );
    }
  });
}
