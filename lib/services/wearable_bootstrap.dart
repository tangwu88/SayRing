import 'package:flutter/foundation.dart';
import '../domain/wellness_release_policy.dart';

import 'coolwear_wearable_bridge.dart';
import 'qring_wearable_bridge.dart';
import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'yucheng_wearable_bridge.dart';

WearableBridge createProductionWearableBridge({
  WearableBridge? veepoo,
  WearableBridge? yucheng,
  WearableBridge? coolwear,
  WearableBridge? qring,
  WearableTransportPreferenceStore? preferenceStore,
  WellnessReleasePolicy? healthReleasePolicy,
}) => RoutedWearableBridge(
  // The iOS activity/sleep release supports only the two verified ring SDKs.
  // Do not instantiate legacy transports or adopt their saved SDK targets.
  veepoo: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? null
      : veepoo ?? MethodChannelWearableBridge(),
  yucheng: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? null
      : yucheng ?? YuchengWearableBridge(),
  coolwear:
      coolwear ??
      (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? (defaultTargetPlatform == TargetPlatform.iOS
                ? CoolWearIosWearableBridge(
                    healthReleasePolicy: healthReleasePolicy,
                  )
                : CoolWearWearableBridge())
          : null),
  qring:
      qring ??
      (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? QRingWearableBridge(healthReleasePolicy: healthReleasePolicy)
          : null),
  restoreOnlyBoundDevice: true,
  requireOwnerScopedBinding: true,
  preferenceStore: preferenceStore,
);
