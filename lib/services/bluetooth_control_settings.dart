import 'package:flutter/services.dart';

/// Opens system settings only. Does not change bonds, permissions or radio state.
Future<void> openBluetoothControlSettings({MethodChannel? channel}) =>
    (channel ?? const MethodChannel('cc.saidian.ring/qring/commands'))
        .invokeMethod<void>('openBluetoothControlSettings');
