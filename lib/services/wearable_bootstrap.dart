import 'package:flutter/foundation.dart';

import 'coolwear_wearable_bridge.dart';
import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'yucheng_wearable_bridge.dart';

WearableBridge createProductionWearableBridge({
  WearableBridge? veepoo,
  WearableBridge? yucheng,
  WearableBridge? coolwear,
}) => RoutedWearableBridge(
  veepoo: veepoo ?? MethodChannelWearableBridge(),
  yucheng: yucheng ?? YuchengWearableBridge(),
  coolwear:
      coolwear ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? CoolWearWearableBridge()
          : null),
  restoreOnlyBoundDevice: true,
);
