import 'package:flutter/foundation.dart';

import 'global_environment.dart';

/// 渠道由构建固定，不能由服务器、账号或审核状态临时切换。
abstract final class AppDistribution {
  static const channel = String.fromEnvironment(
    'SAY_RING_DISTRIBUTION_CHANNEL',
    defaultValue: 'direct',
  );

  static bool usesGooglePlay(
    TargetPlatform platform, {
    String distributionChannel = channel,
  }) {
    if (!const {'direct', 'google-play'}.contains(distributionChannel)) {
      throw ArgumentError('Unsupported app distribution channel');
    }
    return platform == TargetPlatform.android &&
        distributionChannel == 'google-play';
  }

  static Uri get googlePlayUri => Uri.https(
    'play.google.com',
    '/store/apps/details',
    {'id': GlobalEnvironment.packageId},
  );
}
