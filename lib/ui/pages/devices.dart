part of '../pages.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({required this.controller, super.key});

  final AppController controller;

  Future<void> _confirmUnbind(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解绑设备？'),
        content: const Text('解绑后将停止自动连接此戒指。本机已保存的健康记录不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('device-confirm-unbind'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认解绑'),
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: saydianPanelGradient,
              border: Border.all(color: const Color(0x66316EF5)),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x17316EF5),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: saydianHeroGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30316EF5),
                            blurRadius: 16,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.circle_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bound.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (connected != null) ...[
                                const SizedBox(width: 8),
                                _BatteryBadge(
                                  battery: connected.effectiveBattery,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            bound.identifierLabel,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
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
                                      ? '正在重连'
                                      : '等待戒指靠近'),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      child: FilledButton.icon(
                        key: const Key('device-sync-data'),
                        onPressed:
                            connected == null ||
                                controller.isDeviceSyncing ||
                                controller.capabilities?.supportsHistorySync ==
                                    false
                            ? null
                            : () async {
                                final succeeded = await controller
                                    .syncDeviceData();
                                if (!context.mounted) return;
                                final feedback =
                                    controller.syncStatus == '暂无新增数据'
                                    ? context.l10n.syncUpToDate
                                    : succeeded
                                    ? context.l10n.syncComplete
                                    : controller.errorMessage
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                    ? controller.errorMessage!
                                    : context.l10n.syncFailedTryAgain;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(feedback)),
                                );
                              },
                        icon: controller.isDeviceSyncing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          controller.isDeviceSyncing
                              ? controller.deviceSyncProgress <= 0.1
                                    ? context.l10n.readingData
                                    : '${context.l10n.syncing} ${(controller.deviceSyncProgress * 100).round()}%'
                              : controller.capabilities?.supportsHistorySync ==
                                    false
                              ? '此戒指历史同步暂未开放'
                              : context.l10n.syncData,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (connected == null)
                      OutlinedButton.icon(
                        key: const Key('device-reconnect'),
                        onPressed:
                            controller.isDeviceSyncing ||
                                controller.isDeviceReconnecting
                            ? null
                            : controller.reconnectDevice,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: controller.isDeviceReconnecting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bluetooth_searching_rounded),
                        label: Text(
                          controller.isDeviceReconnecting ? '正在重连' : '重新连接',
                        ),
                      ),
                    TextButton.icon(
                      key: const Key('device-unbind'),
                      onPressed: controller.isDeviceSyncing
                          ? null
                          : () => _confirmUnbind(context),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('解绑设备'),
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
              decoration: const BoxDecoration(gradient: saydianPanelGradient),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SaydianColors.techBlueSoft,
                          SaydianColors.techCyanSoft,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.circle_outlined,
                      color: SaydianColors.techBlue,
                      size: 62,
                    ),
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
                    context.l10n.watchNearbyHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 13,
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
              title: Text(context.l10n.readingCapabilities),
              subtitle: Text(context.l10n.capabilitiesHint),
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
              title: Text(context.l10n.capabilitiesFailed),
              subtitle: Text(context.l10n.keepWatchNear),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 104,
              ),
              itemCount: primaryFeatures.length,
              itemBuilder: (context, index) =>
                  _deviceFeatureCard(context, primaryFeatures[index]),
            ),
            const SizedBox(height: 12),
          ],
          if (watchFaceFeatures.isEmpty && primaryFeatures.isEmpty) ...[
            InlineNotice(
              key: const Key('device-no-integrated-features'),
              message: context.l10n.useWatch,
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
                      message: context.l10n.connectionInstructions,
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
          message: context.l10n.syncNearbyHint,
          icon: Icons.info_outline_rounded,
          color: SaydianColors.blue,
          compact: true,
        ),
      ],
    );
  }

  static const _primaryFeatures = <DeviceFeature>[
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
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDCE7F5)),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(gradient: saydianPanelGradient),
        child: InkWell(
          onTap: () => _openDeviceFeature(context, feature),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _featureColor(feature).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _featureIcon(feature),
                    color: _featureColor(feature),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.deviceFeatureName(feature),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        availability.isReady
                            ? context.l10n.tapToOpen
                            : availability.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDeviceFeature(BuildContext context, DeviceFeature feature) {
    if (feature == DeviceFeature.healthMonitoring) {
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
  const _BatteryBadge({required this.battery});

  final DeviceBatteryInfo? battery;

  @override
  Widget build(BuildContext context) {
    final value = battery;
    final percent = value?.percent;
    final color = switch (value) {
      null => SaydianColors.muted,
      DeviceBatteryInfo(isLow: true) => SaydianColors.danger,
      DeviceBatteryInfo(isPercent: true, value: <= 35) => SaydianColors.orange,
      _ => SaydianColors.green,
    };
    final label = value?.displayLabel ?? '--';
    final semantics = value == null
        ? '戒指电量暂未读取'
        : '戒指电量 $label，${value.chargeStateAt(DateTime.now()).label}';
    return Semantics(
      label: semantics,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            value == null
                ? Icons.battery_unknown_rounded
                : value.chargeStateAt(DateTime.now()) ==
                      DeviceBatteryChargeState.charging
                ? Icons.battery_charging_full_rounded
                : percent != null && percent <= 15
                ? Icons.battery_1_bar_rounded
                : (percent != null && percent <= 50) ||
                      (!value.isPercent && value.value <= 2)
                ? Icons.battery_4_bar_rounded
                : Icons.battery_full_rounded,
            color: color,
            size: 22,
          ),
        ],
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
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '显示样式市场',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text('查看更多', style: TextStyle(color: SaydianColors.muted)),
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
                    child: const Center(child: Text('进入显示样式市场选择更多样式')),
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
      if (mounted) unawaited(_startScan());
    });
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

  Future<void> _startScan() async {
    if (_connectingDeviceId != null || _scanInFlight) return;
    _scanInFlight = true;
    try {
      widget.controller.clearError();
      await widget.controller.scanDevices();
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
  }

  Future<void> _findBondedDevices() async {
    if (_connectingDeviceId != null || _scanInFlight || _bondedLookupInFlight) {
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
    if (!widget.controller.commerceEnabled) return;
    await widget.controller.stopDeviceScan();
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final devices = controller.scannedDevices;
        final scanning =
            controller.deviceState == DeviceConnectionState.scanning;
        final connecting = _connectingDeviceId != null;
        final busy = connecting || _bondedLookupInFlight;
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
                              : context.l10n.selectWatch,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 13,
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
                                                    device.name,
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
                            label: Text(context.l10n.findSystemPairedRings),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            defaultTargetPlatform == TargetPlatform.iOS
                                ? '只显示 Say Ring 曾成功连接的戒指；选择后重新验证，不会自动连接其他设备。'
                                : context.l10n.findSystemPairedRingsHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 12,
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
                                ? '正在完成连接，请保持戒指靠近手机并等待 App 提示…'
                                : '正在${_deviceStateLabel(controller.deviceState)}，请保持戒指靠近手机…',
                            icon: Icons.bluetooth_connected_rounded,
                            color: SaydianColors.blue,
                          ),
                        ],
                      ],
                    ),
            ),
            bottomNavigationBar: !controller.commerceEnabled
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: TextButton.icon(
                        key: const Key('device-shop-entry'),
                        onPressed: connecting ? null : _openShop,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          context.l10n.noWatchShopHint,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
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
    DeviceConnectionState.connecting => '连接',
    DeviceConnectionState.authenticating => '认证',
    DeviceConnectionState.syncing => '同步数据',
    _ => '连接设备',
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
              ? context.l10n.searchingNearby
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
              ? context.l10n.activateWatch
              : issue != null
              ? _scanIssueHint(context, issue!)
              : (errorMessage?.trim().isNotEmpty ?? false)
              ? errorMessage!
              : context.l10n.checkWatchConnection,
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
              label: Text(context.l10n.findSystemPairedRings),
            ),
          ],
          if (issue == null) ...[
            const SizedBox(height: 20),
            InlineNotice(
              message: context.l10n.searchRecovery,
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
      DeviceScanIssue.locationServiceDisabled => context.l10n.scanLocationHint,
      DeviceScanIssue.permissionsRequired => context.l10n.scanPermissionHint,
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
                      trailing: Text(device?.name ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(context.l10n.deviceModel),
                      trailing: Text(device?.displayModel ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: Text(context.l10n.connectionStatus),
                      trailing: Text(device == null ? '未连接' : '已连接'),
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
                      title: const Text('固件升级'),
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
                      title: Text(context.l10n.watchBattery),
                      subtitle: battery?.updatedAt == null
                          ? null
                          : Text(
                              '更新于 ${DateFormat('MM-dd HH:mm').format(battery!.updatedAt!.toLocal())}',
                            ),
                      trailing: _BatteryBadge(battery: battery),
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
                            ? 'MAC 地址'
                            : defaultTargetPlatform == TargetPlatform.iOS
                            ? 'iOS 设备标识'
                            : '设备标识',
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
        _refreshError = '设备信息刷新失败，重试';
        _refreshErrorDeviceId = deviceId;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('固件升级')),
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
                      device?.name ?? '未连接设备',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '当前固件：${version?.isNotEmpty == true ? version : '未知'}',
                    ),
                    if (connected == null) const Text('连接戒指后可刷新版本'),
                    const SizedBox(height: 16),
                    const Text('在线固件升级暂未开放'),
                    const SizedBox(height: 8),
                    const Text('尚未接入经过验证的原厂固件和升级服务，不会向戒指写入固件。'),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('firmware-refresh-device'),
              onPressed: _refreshing || connected == null ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_refreshing ? '正在刷新' : '刷新设备信息'),
            ),
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
        color: SaydianColors.green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF16823A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
