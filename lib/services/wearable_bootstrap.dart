import 'package:flutter/foundation.dart';
import '../domain/wellness_release_policy.dart';

import 'coolwear_wearable_bridge.dart';
import 'urion_wearable_bridge.dart';
import 'qring_wearable_bridge.dart';
import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'yucheng_wearable_bridge.dart';

WearableBridge createProductionWearableBridge({
  WearableBridge? veepoo,
  WearableBridge? yucheng,
  WearableBridge? coolwear,
  WearableBridge? qring,
  WearableBridge? urion,
  WearableTransportPreferenceStore? preferenceStore,
  WellnessReleasePolicy? healthReleasePolicy,
}) => RoutedWearableBridge(
  urion:
      urion ??
      (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? UrionWearableBridge(healthPolicy: healthReleasePolicy)
          : null),
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
                : CoolWearAndroidWearableBridge())
          : null),
  qring:
      qring ??
      (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? (defaultTargetPlatform == TargetPlatform.iOS
                ? QRingIosWearableBridge(
                    healthReleasePolicy: healthReleasePolicy,
                  )
                : QRingWearableBridge(healthReleasePolicy: healthReleasePolicy))
          : null),
  restoreOnlyBoundDevice: true,
  requireOwnerScopedBinding: true,
  includeSystemConnectedCandidates:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android),
  preferenceStore: preferenceStore,
);
