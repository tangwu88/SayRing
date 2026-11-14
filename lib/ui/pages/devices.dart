part of '../pages.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({required this.controller, super.key});

  final AppController controller;

  Future<void> _confirmUnbind(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiCopy(context, "解绑设备？")),
        content: Text(uiCopy(context, "解绑后将停止自动连接此设备。本机健康记录会保留。")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(uiCopy(context, "取消")),
          ),
          FilledButton(
            key: const Key('device-confirm-unbind'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(uiCopy(context, "确认解绑")),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.unbindDevice();
  }

  @override
  Widget build(BuildContext context) {
    final connected = controller.connectedDevice;
    final bound = connected ?? controller.rememberedDevice;
    final visibleFeatures = controller.visibleDeviceFeatures;
    final watchFaceFeatures = const [
      DeviceFeature.watchFaces,
      DeviceFeature.photoWatchFace,
    ].where(visibleFeatures.contains).toList(growable: false);
    final primaryFeatures = _primaryFeatures
        .where(visibleFeatures.contains)
        .toList(growable: false);
    return ListView(
      key: const Key('device-page'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        if (bound != null)
          Container(
            key: const Key('device-overview-card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: SaydianColors.line),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: SaydianColors.canvas,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: bound.sdkSource == WearableSdkSource.urion
                          ? const Icon(
                              Icons.watch_outlined,
                              size: 44,
                              color: SaydianColors.techBlue,
                            )
                          : const RingDeviceIllustration(size: 60),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: bound.displayName,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                bound.displayName,
                                key: const Key('device-overview-name'),
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  color: SaydianColors.ink,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (connected != null)
                            _ConnectionBadge(
                              label: context.l10n.connectionState(
                                controller.deviceState,
                              ),
                            )
                          else
                            Text(
                              controller.wearableRecoveryMessage ??
                                  (controller.isWearableRecovering
                                      ? uiCopy(context, "正在重连")
                                      : uiCopy(
                                          context,
                                          bound.sdkSource ==
                                                  WearableSdkSource.urion
                                              ? "等待手表靠近"
                                              : "等待戒指靠近",
                                        )),
                              key: const Key('device-recovery-status'),
                              style: const TextStyle(
                                color: SaydianColors.techBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (connected != null) ...[
                  _BatteryBadge(battery: connected.effectiveBattery),
                  const SizedBox(height: 16),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.capabilities?.supportsHistorySync != false ||
                        (connected != null &&
                            controller.isRingInitializationPending)) ...[
                      SizedBox(
                        child: FilledButton(
                          key: const Key('device-sync-data'),
                          onPressed:
                              connected == null ||
                                  controller.isDeviceHistorySyncing ||
                                  controller.isDeviceSyncPreparing ||
                                  (controller.isRingInitializationPending &&
                                      !controller
                                          .canRetryDeviceSyncPreparation) ||
                                  controller
                                              .capabilities
                                              ?.supportsHistorySync ==
                                          false &&
                                      !controller.isRingInitializationPending
                              ? null
                              : () async {
                                  final succeeded = await controller
                                      .syncDeviceData();
                                  if (!context.mounted ||
                                      controller.isDeviceHistorySyncing ||
                                      controller.isDeviceSyncPreparing ||
                                      controller.syncStatus.isEmpty) {
                                    return;
                                  }
                                  final watch =
                                      connected.sdkSource ==
                                      WearableSdkSource.urion;
                                  final feedback = succeeded
                                      ? watch
                                            ? controller.syncStatus
                                            : context.l10n.syncComplete
                                      : userFacingMessage(
                                          controller.errorMessage,
                                          fallback: devicePromptLabel(
                                            context,
                                            context.l10n.syncFailedTryAgain,
                                          ),
                                        );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        watch
                                            ? uiCopy(context, feedback)
                                            : feedback,
                                      ),
                                    ),
                                  );
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            disabledForegroundColor: SaydianColors.muted,
                            disabledBackgroundColor:
                                controller.isDeviceHistorySyncing
                                ? SaydianColors.techBlueSoft
                                : SaydianColors.line,
                          ),
                          child: controller.isDeviceSyncPreparing
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(uiCopy(context, "正在准备同步")),
                                  ],
                                )
                              : controller.isDeviceHistorySyncing
                              ? DeviceWaitStatus(
                                  connected: connected != null,
                                  receivedRecords:
                                      controller.deviceSyncReceivedRecords,
                                  progress: controller.deviceSyncProgress,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sync_rounded),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        controller.isRingInitializationPending
                                            ? uiCopy(context, "恢复同步")
                                            : context.l10n.syncData,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // 初始化待确认只限制历史读取，不代表蓝牙已断开。
                    // 已连接时不提供重连按钮，避免误导用户主动断开正常链路；
                    // 真正断开后仍保留重连，已确认初始化的恢复继续由控制器处理。
                    if (connected == null)
                      OutlinedButton(
                        key: const Key('device-reconnect'),
                        onPressed:
                            controller.isDeviceSyncing ||
                                controller.isRingInitializationConnecting ||
                                controller.isDeviceReconnecting
                            ? null
                            : controller.reconnectDevice,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child:
                            controller.isDeviceReconnecting ||
                                controller.isRingInitializationConnecting ||
                                controller.isWearableRecovering
                            ? DeviceWaitStatus(
                                connected: false,
                                connectionMessage:
                                    controller.isDeviceReconnecting
                                    ? uiCopy(context, "正在重连")
                                    : uiCopy(context, "正在寻找戒指"),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bluetooth_searching_rounded),
                                  SizedBox(width: 8),
                                  Text(uiCopy(context, "重新连接")),
                                ],
                              ),
                      ),
                    if (connected == null)
                      TextButton.icon(
                        key: const Key('device-search-preserving-binding'),
                        onPressed:
                            controller.canSearchForDevice &&
                                !controller.isDeviceReconnecting
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DeviceSearchPage(controller: controller),
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.radar_rounded),
                        label: Text(uiCopy(context, "重新搜索戒指")),
                      ),
                    const SizedBox(height: 4),
                    // 标题需要单独的无障碍节点，不能和上方设备名称、电量合并。
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      identifier: 'device-connection-details',
                      child: ExpansionTile(
                        key: const Key('device-connection-details'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 4),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          context.l10n.connectionStatus,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 14,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              bound.identifierLabel,
                              style: const TextStyle(
                                color: SaydianColors.muted,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('device-unbind'),
                            onPressed: controller.isDeviceHistorySyncing
                                ? null
                                : () => _confirmUnbind(context),
                            icon: const Icon(Icons.link_off_rounded, size: 18),
                            label: Text(uiCopy(context, "解绑设备")),
                            style: TextButton.styleFrom(
                              foregroundColor: SaydianColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else ...[
          Card(
            key: const Key('device-empty-card'),
            clipBehavior: Clip.antiAlias,
            child: Container(
              key: const Key('device-empty-card-surface'),
              decoration: const BoxDecoration(color: Colors.white),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: const BoxDecoration(
                      color: SaydianColors.canvas,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const RingDeviceIllustration(size: 98),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.addSmartDevice,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    genericDevicePrompt(context.l10n.watchNearbyHint),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DeviceSearchPage(controller: controller),
                        ),
                      ),
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(context.l10n.startSearch),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            key: const Key('device-sync-diagnostics'),
            leading: const Icon(Icons.troubleshoot_rounded),
            title: const Text('同步诊断与恢复'),
            subtitle: const Text('数据未更新时，检查状态或提交诊断'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SyncDiagnosticsPage(controller: controller),
              ),
            ),
          ),
        ),
        if (connected != null &&
            controller.deviceCapabilityState ==
                DeviceCapabilityState.loading) ...[
          Card(
            key: const Key('device-capabilities-loading'),
            child: ListTile(
              leading: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              title: Text(
                devicePromptLabel(context, context.l10n.readingCapabilities),
              ),
              subtitle: Text(
                devicePromptLabel(context, context.l10n.capabilitiesHint),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (connected != null &&
            controller.deviceCapabilityState ==
                DeviceCapabilityState.unavailable) ...[
          Card(
            key: const Key('device-capabilities-unavailable'),
            child: ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(
                devicePromptLabel(context, context.l10n.capabilitiesFailed),
              ),
              subtitle: Text(
                devicePromptLabel(context, context.l10n.keepWatchNear),
              ),
              trailing: TextButton(
                key: const Key('device-capabilities-retry'),
                onPressed: controller.refreshDeviceCapabilities,
                child: Text(context.l10n.retry),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (connected != null &&
            controller.deviceCapabilityState ==
                DeviceCapabilityState.ready) ...[
          if (watchFaceFeatures.contains(DeviceFeature.watchFaces)) ...[
            _DeviceWatchFaceMarketStrip(controller: controller),
            const SizedBox(height: 16),
          ],
          if (watchFaceFeatures.isNotEmpty) ...[
            _TechSectionHeading(
              icon: Icons.palette_outlined,
              title: context.l10n.personalizeWatch,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (
                  var index = 0;
                  index < watchFaceFeatures.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _deviceFeatureCard(
                      context,
                      watchFaceFeatures[index],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (primaryFeatures.isNotEmpty) ...[
            _TechSectionHeading(
              icon: Icons.grid_view_rounded,
              title: context.l10n.deviceFeatures,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final columns = textScale > 1.3 || constraints.maxWidth < 320
                    ? 1
                    : 2;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final feature in primaryFeatures)
                      SizedBox(
                        width: width,
                        child: _deviceFeatureCard(context, feature),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          if (watchFaceFeatures.isEmpty && primaryFeatures.isEmpty) ...[
            InlineNotice(
              key: const Key('device-no-integrated-features'),
              message: devicePromptLabel(context, context.l10n.useWatch),
              icon: Icons.circle_outlined,
              color: SaydianColors.blue,
              compact: true,
            ),
            const SizedBox(height: 12),
          ],
        ],
        Card(
          child: Column(
            children: [
              if (connected != null) ...[
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'device-about'),
                      builder: (_) => DeviceInfoPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(context.l10n.aboutDevice),
                  subtitle: Text(context.l10n.deviceInfoHint),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
              ],
              ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: 'connection-help'),
                    builder: (context) => _InfoPage(
                      title: context.l10n.connectionHelp,
                      message:
                          '${devicePromptLabel(context, context.l10n.connectionInstructions)}\n\n'
                          '${defaultTargetPlatform == TargetPlatform.iOS ? devicePromptLabel(context, context.l10n.deviceSearchHelpRebindIos) : devicePromptLabel(context, context.l10n.deviceSearchHelpRebindAndroid)}',
                    ),
                  ),
                ),
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(context.l10n.connectionHelp),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InlineNotice(
          message: devicePromptLabel(context, context.l10n.syncNearbyHint),
          icon: Icons.info_outline_rounded,
          color: SaydianColors.blue,
          compact: true,
        ),
      ],
    );
  }

  static const _primaryFeatures = <DeviceFeature>[
    DeviceFeature.basicSettings,
    DeviceFeature.u19Pulse,
    DeviceFeature.findWatch,
    DeviceFeature.camera,
    DeviceFeature.gestureControl,
    DeviceFeature.callReminder,
    DeviceFeature.phoneCalls,
    DeviceFeature.contacts,
    DeviceFeature.notifications,
    DeviceFeature.alarms,
    DeviceFeature.weather,
    DeviceFeature.worldClock,
    DeviceFeature.healthReminders,
    DeviceFeature.healthMonitoring,
    DeviceFeature.healthAssessment,
    DeviceFeature.screenDisplay,
  ];

  Widget _deviceFeatureCard(BuildContext context, DeviceFeature feature) {
    final availability = controller.availabilityFor(feature);
    return Material(
      key: Key('device-feature-${feature.wireName}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: SaydianColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        hint: availability.isReady
            ? context.l10n.tapToOpen
            : availability.message,
        child: InkWell(
          onTap: () => _openDeviceFeature(context, feature),
          child: Container(
            constraints: const BoxConstraints(minHeight: 110),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _featureColor(feature).withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _featureIcon(feature),
                        color: _featureColor(feature),
                        size: 25,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      size: 17,
                      color: SaydianColors.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  feature == DeviceFeature.findWatch &&
                          controller.connectedDevice?.sdkSource ==
                              WearableSdkSource.urion
                      ? uiCopy(context, '查找手表')
                      : context.l10n.deviceFeatureName(feature),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!availability.isReady) ...[
                  const SizedBox(height: 4),
                  Text(
                    availability.message,
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDeviceFeature(BuildContext context, DeviceFeature feature) {
    if (feature == DeviceFeature.healthReminders) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'health-reminder-center'),
          builder: (_) => HealthReminderCenterPage(controller: controller),
        ),
      );
      return;
    }
    if (feature == DeviceFeature.healthMonitoring &&
        controller.connectedDevice?.sdkSource != WearableSdkSource.urion) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'device-health-monitoring'),
          builder: (_) => PermissionManagementPage(
            controller: controller,
            healthOnly: true,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'device-${feature.wireName}'),
        builder: (_) =>
            DeviceFeaturePage(controller: controller, feature: feature),
      ),
    );
  }

  IconData _featureIcon(DeviceFeature feature) => switch (feature) {
    DeviceFeature.basicSettings => Icons.settings_outlined,
    DeviceFeature.u19Pulse => Icons.favorite_border,
    DeviceFeature.watchFaces => Icons.watch_later_outlined,
    DeviceFeature.photoWatchFace => Icons.photo_outlined,
    DeviceFeature.findWatch => Icons.notifications_active_outlined,
    DeviceFeature.camera => Icons.camera_alt_outlined,
    DeviceFeature.gestureControl => Icons.gesture_rounded,
    DeviceFeature.callReminder => Icons.phone_in_talk_outlined,
    DeviceFeature.phoneCalls => Icons.call_outlined,
    DeviceFeature.contacts => Icons.contacts_outlined,
    DeviceFeature.notifications => Icons.notifications_none_rounded,
    DeviceFeature.alarms => Icons.alarm_rounded,
    DeviceFeature.weather => Icons.cloud_outlined,
    DeviceFeature.worldClock => Icons.public_rounded,
    DeviceFeature.healthReminders => Icons.event_available_outlined,
    DeviceFeature.healthMonitoring => Icons.monitor_heart_outlined,
    DeviceFeature.healthAssessment => Icons.assignment_turned_in_outlined,
    DeviceFeature.screenDisplay => Icons.brightness_6_outlined,
  };

  Color _featureColor(DeviceFeature feature) => switch (feature) {
    DeviceFeature.findWatch ||
    DeviceFeature.alarms ||
    DeviceFeature.healthMonitoring => SaydianColors.techIndigo,
    DeviceFeature.camera ||
    DeviceFeature.notifications ||
    DeviceFeature.screenDisplay => SaydianColors.blue,
    DeviceFeature.phoneCalls ||
    DeviceFeature.contacts ||
    DeviceFeature.healthReminders => SaydianColors.green,
    DeviceFeature.weather ||
    DeviceFeature.worldClock => const Color(0xFF0EA5E9),
    _ => SaydianColors.techCyan,
  };
}

class _TechSectionHeading extends StatelessWidget {
  const _TechSectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: SaydianColors.techBlueSoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: SaydianColors.techBlue, size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _BatteryBadge extends StatelessWidget {
  const _BatteryBadge({required this.battery, this.compact = false});

  final DeviceBatteryInfo? battery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = battery;
    final color = switch (value) {
      null => SaydianColors.muted,
      DeviceBatteryInfo(isLow: true) => SaydianColors.danger,
      DeviceBatteryInfo(isPercent: true, value: <= 35) => SaydianColors.orange,
      _ => SaydianColors.green,
    };
    final label = value == null
        ? '--'
        : value.isPercent
        ? value.displayLabel
        : uiCopy(
            context,
            "{p0}/{p1} 格",
            parameters: [value.value, value.scale],
          );
    final semantics = value == null
        ? uiCopy(context, "设备电量暂未读取")
        : uiCopy(
            context,
            "设备电量 {p0}，{p1}",
            parameters: [
              label,
              uiCopy(context, value.chargeStateAt(DateTime.now()).label),
            ],
          );
    final fraction = value != null && value.scale > 0
        ? (value.value / value.scale).clamp(0.0, 1.0)
        : null;
    final charging =
        value?.chargeStateAt(DateTime.now()) ==
        DeviceBatteryChargeState.charging;
    if (compact) {
      return Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Icon(
              value == null
                  ? Icons.battery_unknown_rounded
                  : charging
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_std_rounded,
              color: color,
              size: 22,
            ),
          ],
        ),
      );
    }
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        key: const Key('device-battery-level'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              uiCopy(context, "设备电量"),
              style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  key: const Key('device-battery-value'),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 23,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 1.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      if (fraction != null)
                        FractionallySizedBox(
                          key: const Key('device-battery-fill'),
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      if (value == null || charging)
                        Center(
                          child: Icon(
                            charging
                                ? Icons.bolt_rounded
                                : Icons.question_mark_rounded,
                            color: charging ? Colors.white : color,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 3,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceWatchFaceMarketStrip extends StatefulWidget {
  const _DeviceWatchFaceMarketStrip({required this.controller});

  final AppController controller;

  @override
  State<_DeviceWatchFaceMarketStrip> createState() =>
      _DeviceWatchFaceMarketStripState();
}

class _DeviceWatchFaceMarketStripState
    extends State<_DeviceWatchFaceMarketStrip> {
  final _service = DeviceWatchFaceMarketService();
  List<DeviceWatchFaceMarketItem> _items = const [];
  DeviceWatchFaceMarketProfile? _profile;
  bool _supported = false;
  String? _loadedDeviceId;
  bool _loading = false;
  final _loadGate = WatchFaceLoadRequestGate();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleDeviceChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleDeviceChanged);
    super.dispose();
  }

  void _handleDeviceChanged() {
    final currentId = widget.controller.connectedDevice?.id;
    if (currentId == _loadedDeviceId) return;
    _loadGate.invalidate();
    if (mounted) {
      setState(() {
        _loadedDeviceId = currentId;
        _profile = null;
        _supported = false;
        _items = const [];
        _loading = false;
      });
    }
    if (currentId != null) unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    if (widget.controller.connectedDevice?.sdkSource !=
        WearableSdkSource.veepoo) {
      return;
    }
    final generation = _loadGate.begin();
    _loading = true;
    final requestedDeviceId = widget.controller.connectedDevice?.id;
    _loadedDeviceId = requestedDeviceId;
    try {
      final profileData = await widget.controller.readWatchFaceProfile();
      if (profileData['onlineMarketSupported'] != true) return;
      final profile = DeviceWatchFaceMarketProfile.fromMap(profileData);
      if (!profile.matchesDevice(requestedDeviceId) ||
          widget.controller.connectedDevice?.id != requestedDeviceId) {
        return;
      }
      final items = widget.controller.usesNativeWatchFaceMarket
          ? (await widget.controller.readNativeWatchFaceCatalog())
                .map(DeviceWatchFaceMarketItem.fromNative)
                .where(
                  (item) =>
                      item.available &&
                      item.dialShape == profile.dialShape &&
                      item.binProtocol == profile.binProtocol,
                )
                .take(4)
                .toList(growable: false)
          : (await _service.loadPage(
              page: 1,
              profile: profile,
            )).items.take(4).toList();
      if (mounted &&
          _loadGate.accepts(
            token: generation,
            requestedDeviceId: requestedDeviceId,
            currentDeviceId: widget.controller.connectedDevice?.id,
          ) &&
          profile.matchesDevice(requestedDeviceId)) {
        setState(() {
          _supported = true;
          _profile = profile;
          _loadedDeviceId = requestedDeviceId;
          _items = items;
        });
      }
    } catch (_) {
      // The full market page has an explicit retry state. Keep this compact
      // preview quiet when the phone is temporarily offline.
    } finally {
      if (_loadGate.accepts(
        token: generation,
        requestedDeviceId: requestedDeviceId,
        currentDeviceId: widget.controller.connectedDevice?.id,
      )) {
        _loading = false;
      }
    }
  }

  void _openMarket() {
    final profile = _profile;
    if (profile == null ||
        !profile.matchesDevice(widget.controller.connectedDevice?.id)) {
      unawaited(_load());
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'device-watch-face-market'),
        builder: (_) => DeviceWatchFaceMarketPage(
          controller: widget.controller,
          profile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openMarket,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    uiCopy(context, "显示样式市场"),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  uiCopy(context, "查看更多"),
                  style: TextStyle(color: SaydianColors.muted),
                ),
                Icon(Icons.chevron_right_rounded, color: SaydianColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: _items.isEmpty
              ? Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openMarket,
                    child: Center(
                      child: Text(uiCopy(context, "进入显示样式市场选择更多样式")),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _openMarket,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SafeNetworkImage(
                          item.previewUrl.toString(),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFF171B2B),
                            child: SizedBox.square(
                              dimension: 88,
                              child: Icon(
                                Icons.watch_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DeviceSearchPage extends StatefulWidget {
  const DeviceSearchPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<DeviceSearchPage> createState() => _DeviceSearchPageState();
}

class _DeviceSearchPageState extends State<DeviceSearchPage>
    with WidgetsBindingObserver {
  String? _connectingDeviceId;
  bool _scanInFlight = false;
  bool _bondedLookupInFlight = false;
  bool _awaitingScanSettingsReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_findCachedOrScan());
    });
  }

  Future<void> _findCachedOrScan() async {
    if (!mounted || !widget.controller.canSearchForDevice) return;
    if (!widget.controller.supportsBondedDeviceSelection) {
      await _startScan();
      return;
    }
    if (_bondedLookupInFlight || _scanInFlight) return;
    setState(() => _bondedLookupInFlight = true);
    try {
      final session = widget.controller.session;
      widget.controller.clearError();
      await widget.controller.listBondedDevicesForSelection();
      // 缓存候选可以立即连接，但不能代替这次附近搜索。保留本轮缓存项并继续
      // 接收广播；换号、连接成功或离开页面后，旧查询不得重新启动扫描。
      if (mounted &&
          identical(session, widget.controller.session) &&
          widget.controller.canSearchForDevice &&
          ModalRoute.of(context)?.isCurrent == true) {
        await _startScan(preserveCandidates: true);
      }
    } finally {
      if (mounted) setState(() => _bondedLookupInFlight = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.stopDeviceScan());
    if (_connectingDeviceId != null) {
      unawaited(widget.controller.disconnectDevice());
    }
    super.dispose();
  }

  Future<void> _startScan({bool preserveCandidates = false}) async {
    if (!mounted ||
        !widget.controller.canSearchForDevice ||
        _connectingDeviceId != null ||
        _scanInFlight) {
      return;
    }
    _scanInFlight = true;
    try {
      widget.controller.clearError();
      await widget.controller.scanDevices(
        preserveCandidates: preserveCandidates,
      );
    } finally {
      _scanInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingScanSettingsReturn) {
      _awaitingScanSettingsReturn = false;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_startScan());
      }
    }
  }

  Future<void> _openScanSettings() async {
    final issue = widget.controller.deviceScanIssue;
    if (issue == null || _awaitingScanSettingsReturn) return;
    _awaitingScanSettingsReturn = true;
    try {
      final opened = issue == DeviceScanIssue.locationServiceDisabled
          ? await Geolocator.openLocationSettings()
          : await openAppSettings();
      if (!opened) _awaitingScanSettingsReturn = false;
    } catch (_) {
      _awaitingScanSettingsReturn = false;
    }
    if (mounted && !_awaitingScanSettingsReturn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_scanIssueHint(context, issue))));
    }
  }

  Future<void> _connect(DeviceInfo device) async {
    if (_connectingDeviceId != null) return;
    setState(() => _connectingDeviceId = device.id);
    await widget.controller.connectDevice(device);
    if (!mounted) return;
    if (widget.controller.connectedDevice?.id == device.id &&
        widget.controller.deviceState == DeviceConnectionState.ready) {
      _connectingDeviceId = null;
      Navigator.of(context).pop();
      return;
    }
    setState(() => _connectingDeviceId = null);
    if (widget.controller.supportsBondedDeviceSelection &&
        device.rssi == null &&
        widget.controller.deviceState == DeviceConnectionState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiCopy(context, "缓存连接未成功，正在重新搜索设备"))),
      );
      await _startScan();
    }
  }

  Future<void> _findBondedDevices() async {
    if (!widget.controller.canSearchForDevice ||
        _connectingDeviceId != null ||
        _scanInFlight ||
        _bondedLookupInFlight) {
      return;
    }
    setState(() => _bondedLookupInFlight = true);
    try {
      widget.controller.clearError();
      await widget.controller.listBondedDevicesForSelection();
    } finally {
      if (mounted) setState(() => _bondedLookupInFlight = false);
    }
  }

  Future<void> _openShop() async {
    if (!widget.controller.mallVisible) return;
    await widget.controller.stopDeviceScan();
    if (!mounted || !widget.controller.mallVisible) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'shop-home'),
        builder: (_) => ShopHomePage(
          controller: widget.controller,
          ordersPageBuilder: (_) =>
              OrdersPage(controller: widget.controller, initialStatus: null),
        ),
      ),
    );
  }

  Future<void> _showSearchHelp() => showDialog<void>(
    context: context,
    builder: (_) => DevicePromptScope(
      generic: true,
      child: Builder(builder: _searchHelpDialog),
    ),
  );

  Widget _searchHelpDialog(BuildContext context) => AlertDialog(
    key: const Key('device-search-help-dialog'),
    scrollable: true,
    title: Text(devicePromptLabel(context, context.l10n.deviceSearchHelpTitle)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (icon, text) in [
          (
            Icons.battery_charging_full_rounded,
            devicePromptLabel(context, context.l10n.deviceSearchHelpPower),
          ),
          (
            Icons.bluetooth_rounded,
            devicePromptLabel(context, context.l10n.deviceSearchHelpAccess),
          ),
          (
            Icons.phonelink_erase_rounded,
            devicePromptLabel(context, context.l10n.deviceSearchHelpOtherPhone),
          ),
          (
            Icons.link_rounded,
            defaultTargetPlatform == TargetPlatform.iOS
                ? devicePromptLabel(
                    context,
                    context.l10n.deviceSearchHelpRebindIos,
                  )
                : devicePromptLabel(
                    context,
                    context.l10n.deviceSearchHelpRebindAndroid,
                  ),
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: SaydianColors.blue, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    actions: [
      FilledButton(
        key: const Key('device-search-help-close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.confirm),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      DevicePromptScope(generic: true, child: Builder(builder: _searchBody));

  Widget _searchBody(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final devices = controller.scannedDevices;
        final scanning =
            controller.deviceState == DeviceConnectionState.scanning;
        final connecting = _connectingDeviceId != null;
        final busy =
            connecting ||
            _bondedLookupInFlight ||
            !controller.canSearchForDevice;
        return PopScope(
          canPop: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.addDevice),
              actions: [
                IconButton(
                  tooltip: context.l10n.searchAgain,
                  onPressed: scanning || busy ? null : _startScan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: devices.isEmpty
                  ? _DeviceSearchEmpty(
                      scanning: scanning,
                      errorMessage: controller.errorMessage,
                      issue: controller.deviceScanIssue,
                      onOpenSettings: _openScanSettings,
                      onRetry: scanning || busy ? null : _startScan,
                      supportsBondedDeviceSelection:
                          controller.supportsBondedDeviceSelection,
                      bondedLookupInFlight: _bondedLookupInFlight,
                      onFindBondedDevices: busy ? null : _findBondedDevices,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      children: [
                        Text(
                          context.l10n.devicesFound,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          scanning
                              ? context.l10n.searchingHint
                              : devicePromptLabel(
                                  context,
                                  context.l10n.selectWatch,
                                ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 15,
                          ),
                        ),
                        if (scanning) ...[
                          const SizedBox(height: 14),
                          const LinearProgressIndicator(minHeight: 3),
                        ],
                        if (controller.errorMessage?.trim().isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 14),
                          InlineNotice(
                            message: controller.errorMessage!,
                            icon: Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ],
                        const SizedBox(height: 18),
                        for (final device in devices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: connecting
                                    ? null
                                    : () => _connect(device),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    15,
                                    12,
                                    15,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: SaydianColors.ink,
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.circle_outlined,
                                          color: Colors.white,
                                          size: 29,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    device.displayName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              device.identifierLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: SaydianColors.muted,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _signalIcon(device.rssi),
                                                size: 18,
                                                color: SaydianColors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                device.rssi == null
                                                    ? context
                                                          .l10n
                                                          .systemPairedDevice
                                                    : '${device.rssi}',
                                                style: const TextStyle(
                                                  color: SaydianColors.muted,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          if (_connectingDeviceId == device.id)
                                            const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else
                                            Text(
                                              context.l10n.connect,
                                              style: TextStyle(
                                                color: SaydianColors.blue,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (controller.supportsBondedDeviceSelection) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('device-find-system-paired'),
                            onPressed: scanning || busy
                                ? null
                                : _findBondedDevices,
                            icon: _bondedLookupInFlight
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.bluetooth_searching_rounded),
                            label: Text(
                              devicePromptLabel(
                                context,
                                context.l10n.findSystemPairedRings,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            defaultTargetPlatform == TargetPlatform.iOS
                                ? uiCopy(
                                    context,
                                    "可查找本账号记住或 iPhone 当前已连接的戒指；选择后仍需验证数据连接。",
                                  )
                                : devicePromptLabel(
                                    context,
                                    context.l10n.findSystemPairedRingsHint,
                                  ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (connecting) ...[
                          const SizedBox(height: 8),
                          InlineNotice(
                            message:
                                controller.deviceState ==
                                        DeviceConnectionState.connecting ||
                                    controller.deviceState ==
                                        DeviceConnectionState.authenticating
                                ? uiCopy(context, "正在完成连接，请保持戒指靠近手机并等待 App 提示…")
                                : uiCopy(
                                    context,
                                    "正在{p0}，请保持戒指靠近手机…",
                                    parameters: [
                                      _deviceStateLabel(controller.deviceState),
                                    ],
                                  ),
                            icon: Icons.bluetooth_connected_rounded,
                            color: SaydianColors.blue,
                          ),
                        ],
                      ],
                    ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      key: const Key('device-search-help'),
                      onPressed: busy ? null : _showSearchHelp,
                      icon: const Icon(Icons.help_outline_rounded),
                      label: Text(
                        devicePromptLabel(
                          context,
                          context.l10n.deviceSearchHelpTitle,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (controller.mallVisible)
                      TextButton.icon(
                        key: const Key('device-shop-entry'),
                        onPressed: connecting ? null : _openShop,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          context.l10n.noWatchShopHint,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _signalIcon(int? rssi) {
    if (rssi == null || rssi < -85) return Icons.signal_cellular_alt_1_bar;
    if (rssi < -65) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt;
  }

  String _deviceStateLabel(DeviceConnectionState state) => switch (state) {
    DeviceConnectionState.connecting => uiCopy(context, "连接"),
    DeviceConnectionState.authenticating => uiCopy(context, "认证"),
    DeviceConnectionState.syncing => uiCopy(context, "同步数据"),
    _ => uiCopy(context, "连接设备"),
  };
}

class _DeviceSearchEmpty extends StatelessWidget {
  const _DeviceSearchEmpty({
    required this.scanning,
    required this.errorMessage,
    required this.issue,
    required this.onOpenSettings,
    required this.onRetry,
    required this.supportsBondedDeviceSelection,
    required this.bondedLookupInFlight,
    required this.onFindBondedDevices,
  });

  final bool scanning;
  final String? errorMessage;
  final DeviceScanIssue? issue;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRetry;
  final bool supportsBondedDeviceSelection;
  final bool bondedLookupInFlight;
  final VoidCallback? onFindBondedDevices;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 58, 28, 32),
      children: [
        Container(
          width: 150,
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 74),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDCEBFF), Color(0xFFF0F6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            scanning
                ? Icons.radar_rounded
                : issue == DeviceScanIssue.locationServiceDisabled
                ? Icons.location_off_outlined
                : issue != null
                ? Icons.settings_outlined
                : Icons.watch_off_outlined,
            color: SaydianColors.blue,
            size: 76,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          scanning
              ? devicePromptLabel(context, context.l10n.searchingNearby)
              : switch (issue) {
                  DeviceScanIssue.locationServiceDisabled =>
                    context.l10n.scanLocationTitle,
                  DeviceScanIssue.permissionsRequired =>
                    context.l10n.scanPermissionTitle,
                  null => context.l10n.noDevices,
                },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          scanning
              ? devicePromptLabel(context, context.l10n.activateWatch)
              : issue != null
              ? _scanIssueHint(context, issue!)
              : (errorMessage?.trim().isNotEmpty ?? false)
              ? errorMessage!
              : devicePromptLabel(context, context.l10n.checkWatchConnection),
          textAlign: TextAlign.center,
          style: const TextStyle(color: SaydianColors.muted, height: 1.5),
        ),
        if (scanning) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
        ] else ...[
          const SizedBox(height: 26),
          if (issue != null) ...[
            FilledButton.icon(
              key: const Key('device-scan-open-settings'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(context.l10n.goToSettings),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.searchAgain),
          ),
          if (issue == null && supportsBondedDeviceSelection) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('device-find-system-paired'),
              onPressed: onFindBondedDevices,
              icon: bondedLookupInFlight
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(
                devicePromptLabel(context, context.l10n.findSystemPairedRings),
              ),
            ),
          ],
          if (issue == null) ...[
            const SizedBox(height: 20),
            InlineNotice(
              message: devicePromptLabel(context, context.l10n.searchRecovery),
              icon: Icons.info_outline_rounded,
              color: SaydianColors.blue,
            ),
          ],
        ],
      ],
    );
  }
}

String _scanIssueHint(BuildContext context, DeviceScanIssue issue) =>
    switch (issue) {
      DeviceScanIssue.locationServiceDisabled => devicePromptLabel(
        context,
        context.l10n.scanLocationHint,
      ),
      DeviceScanIssue.permissionsRequired => devicePromptLabel(
        context,
        context.l10n.scanPermissionHint,
      ),
    };

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshConnectedDeviceDetails());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutDevice)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final device = widget.controller.connectedDevice;
          final battery = device?.effectiveBattery;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(context.l10n.deviceName),
                      trailing: Text(device?.displayName ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(context.l10n.deviceModel),
                      trailing: Text(device?.displayModel ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(context.l10n.connectionStatus),
                      trailing: Text(
                        device == null
                            ? uiCopy(context, "未连接")
                            : uiCopy(context, "已连接"),
                      ),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(context.l10n.firmwareVersion),
                      trailing: Text(device?.firmwareVersion ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      key: const Key('device-firmware-upgrade'),
                      leading: const Icon(Icons.system_update_alt_rounded),
                      title: Text(uiCopy(context, "固件升级")),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DeviceFirmwarePage(controller: widget.controller),
                        ),
                      ),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(uiCopy(context, "设备电量")),
                      subtitle: battery?.updatedAt == null
                          ? null
                          : Text(
                              uiCopy(
                                context,
                                "更新于 {p0}",
                                parameters: [
                                  DateFormat(
                                    'MM-dd HH:mm',
                                  ).format(battery!.updatedAt!.toLocal()),
                                ],
                              ),
                            ),
                      trailing: _BatteryBadge(battery: battery, compact: true),
                    ),
                    if (battery != null) ...[
                      const Divider(indent: 16),
                      ListTile(
                        title: Text(context.l10n.chargingStatus),
                        trailing: Text(
                          battery.chargeStateAt(DateTime.now()).label,
                        ),
                      ),
                    ],
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(
                        device?.macAddress != null
                            ? uiCopy(context, "MAC 地址")
                            : defaultTargetPlatform == TargetPlatform.iOS
                            ? uiCopy(context, "iOS 设备标识")
                            : uiCopy(context, "设备标识"),
                      ),
                      subtitle: Text(
                        device?.macAddress ?? device?.nativeId ?? '--',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Device firmware, not the App update flow. A transport capability alone does
/// not establish an authenticated, hardware-compatible firmware release.
class DeviceFirmwarePage extends StatefulWidget {
  const DeviceFirmwarePage({required this.controller, super.key});
  final AppController controller;

  @override
  State<DeviceFirmwarePage> createState() => _DeviceFirmwarePageState();
}

class _DeviceFirmwarePageState extends State<DeviceFirmwarePage> {
  bool _refreshing = false;
  String? _refreshError;
  String? _refreshErrorDeviceId;

  Future<void> _refresh() async {
    final deviceId = widget.controller.connectedDevice?.id;
    if (_refreshing || deviceId == null) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
      _refreshErrorDeviceId = null;
    });
    final success = await widget.controller.refreshConnectedDeviceDetails(
      quiet: true,
    );
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (!success && widget.controller.connectedDevice?.id == deviceId) {
        _refreshError = uiCopy(context, "设备信息刷新失败，重试");
        _refreshErrorDeviceId = deviceId;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(uiCopy(context, "固件升级"))),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final connected = widget.controller.connectedDevice;
        final device = connected ?? widget.controller.rememberedDevice;
        final version = device?.firmwareVersion?.trim();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      device?.displayName ?? uiCopy(context, "未连接设备"),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (version?.isNotEmpty == true)
                      Text(uiCopy(context, "当前固件：{p0}", parameters: [version]))
                    else if (connected != null)
                      Text(uiCopy(context, "未读到固件版本")),
                    if (connected == null)
                      Text(uiCopy(context, "连接戒指后可查看最新的固件信息。"))
                    else
                      Text(uiCopy(context, "暂不支持在线升级。")),
                  ],
                ),
              ),
            ),
            if (_refreshError != null && connected?.id == _refreshErrorDeviceId)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _refreshError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (connected != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('firmware-refresh-device'),
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _refreshing
                      ? uiCopy(context, "正在刷新")
                      : uiCopy(context, "刷新设备信息"),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SaydianColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bluetooth_connected_rounded,
            size: 14,
            color: SaydianColors.green,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: SaydianColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
