part of '../pages.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _scheduledError;

  void _showPendingError(BuildContext context) {
    final message = widget.controller.errorMessage?.trim();
    if (message == null || message.isEmpty || message == _scheduledError) {
      return;
    }
    _scheduledError = message;
    final controller = widget.controller;
    final owner = controller.homeHealthCardOwner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduledError != message) return;
      _scheduledError = null;
      if (widget.controller != controller ||
          controller.homeHealthCardOwner != owner ||
          controller.errorMessage?.trim() != message) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              uiErrorCopy(
                context,
                message,
                fallback: uiCopy(context, "操作未完成，请重试"),
                genericDevice: controller.usesDevicePrompts,
              ),
            ),
          ),
        );
      controller.clearError();
    });
  }

  @override
  Widget build(BuildContext context) {
    _showPendingError(context);
    final controller = widget.controller;
    final selectedIndex = controller.selectedTab.clamp(0, 2).toInt();
    final pages = [
      DashboardPage(controller: controller),
      DevicePage(controller: controller),
      SettingsPage(controller: controller),
    ];
    return Scaffold(
      appBar: selectedIndex == 0
          ? null
          : AppBar(
              title: Text(
                selectedIndex == 1 ? context.l10n.device : context.l10n.profile,
              ),
              actions: const [],
            ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: SaydianColors.line)),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 22,
              offset: Offset(0, -7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: controller.selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.favorite_border_rounded),
                selectedIcon: const Icon(Icons.favorite_rounded),
                label: context.l10n.health,
              ),
              NavigationDestination(
                icon: const Icon(Icons.circle_outlined),
                selectedIcon: const Icon(Icons.circle_outlined),
                label: context.l10n.device,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: context.l10n.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final latest = controller.latestByMetric;
    final disconnected = controller.connectedDevice == null;
    final supportedMetrics = [
      if (controller.isWellnessOnly) ...[
        HealthMetric.steps,
        HealthMetric.distance,
      ],
      HealthMetric.bloodPressure,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodGlucose,
      HealthMetric.bodyTemperature,
      HealthMetric.ecg,
      HealthMetric.hrv,
      HealthMetric.stress,
      HealthMetric.bodyComposition,
      HealthMetric.bloodComposition,
      HealthMetric.sleep,
    ];
    final metrics = controller.homeHealthCardMetrics;
    final hasEligibleCards = supportedMetrics.any(
      controller.shouldShowHealthMetric,
    );
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await controller.refreshReadOnlyHealthFeatures();
          await controller.synchronizeCloud();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              // This is a small, bounded overview (the card Wrap already lays
              // out all metrics). A lazy variable-height SliverList estimates
              // the tall card group from the preceding short header entries;
              // re-entering them during a slow reverse drag corrects the scroll
              // offset repeatedly. One measured box has no estimated extent.
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DashboardHeader(controller: controller),
                    const SizedBox(height: 16),
                    if (controller.shouldShowHealthMetric(
                      HealthMetric.steps,
                    )) ...[
                      _DashboardActivity(controller: controller),
                      const SizedBox(height: 12),
                    ],
                    if (!controller.shouldShowHealthMetric(
                          HealthMetric.steps,
                        ) &&
                        controller.canBrowseSavedActivity) ...[
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          key: const Key('dashboard-saved-ring-activity'),
                          leading: const Icon(
                            Icons.directions_walk_rounded,
                            color: SaydianColors.blue,
                          ),
                          title: Text(context.l10n.savedActivity),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final ring = controller.connectedDevice;
                            if (ring == null) return;
                            final source = SavedRingActivitySource(
                              controller,
                              ring,
                            );
                            final latest = controller.healthRecords
                                .where(
                                  (r) =>
                                      r.deviceId == ring.id &&
                                      r.metric == HealthMetric.steps,
                                )
                                .firstOrNull;
                            final route = MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: 'saved-ring-activity',
                              ),
                              builder: (_) => HealthTrendPage(
                                controller: controller,
                                metric: HealthMetric.steps,
                                initialDate: latest == null
                                    ? null
                                    : HealthAnalysisService.displayTime(latest),
                                initialPeriod: HealthTrendPeriod.month,
                                dataSource: source,
                              ),
                            );
                            try {
                              await Navigator.of(context).push(route);
                              await route.completed;
                            } finally {
                              source.dispose();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (controller.canOpenSleepOverview) ...[
                      _SleepQuickCard(controller: controller),
                      const SizedBox(height: 20),
                    ],
                    _SectionTitle(
                      title: context.l10n.healthData,
                      actionLabel: context.l10n.allData,
                      onEdit:
                          controller.isWellnessOnly ||
                              controller.homeHealthCardsLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'home-health-card-editor',
                                ),
                                builder: (_) =>
                                    HomeHealthCardsPage(controller: controller),
                              ),
                            ),
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: 'all-health-data',
                          ),
                          builder: (_) =>
                              AllHealthDataPage(controller: controller),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (metrics.isEmpty)
                      InlineNotice(
                        key: const Key('dashboard-health-empty-notice'),
                        message: hasEligibleCards && !controller.isWellnessOnly
                            ? uiCopy(context, "首页暂无卡片，点击编辑添加")
                            : disconnected
                            ? devicePromptLabel(
                                context,
                                context.l10n.connectWatchForData,
                              )
                            : context.l10n.noHealthData,
                        icon: Icons.watch_outlined,
                        color: SaydianColors.blue,
                        compact: true,
                        centered: true,
                        onTap: !hasEligibleCards && disconnected
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: 'device-search',
                                  ),
                                  builder: (_) =>
                                      DeviceSearchPage(controller: controller),
                                ),
                              )
                            : null,
                      )
                    else
                      LayoutBuilder(
                        key: const Key('dashboard-health-card-list'),
                        builder: (context, constraints) {
                          final twoColumns =
                              metrics.length > 1 &&
                              constraints.maxWidth >= 300 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.2;
                          final width = twoColumns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final metric in metrics)
                                SizedBox(
                                  width: width,
                                  child: RepaintBoundary(
                                    child: HealthMetricCard(
                                      key: ValueKey(
                                        'home-health-card-${metric.wireName}',
                                      ),
                                      controller: controller,
                                      metric: metric,
                                      record: latest[metric],
                                      compact: true,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    _FeatureEntryGrid(
                      commerceEnabled: controller.mallVisible,
                      encyclopediaEnabled: controller.healthLibraryVisible,
                      onWeek:
                          controller.canOpenSleepOverview &&
                              controller.ringExperience
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    RingWeekPage(controller: controller),
                              ),
                            )
                          : null,
                      onAskAi: controller.hideAiContent
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'ai-health-chat',
                                ),
                                builder: (_) =>
                                    AiChatPage(controller: controller, app: 1),
                              ),
                            ),
                      onCare: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => controller.isGlobalEdition
                              ? CarePage(controller: controller)
                              : Scaffold(
                                  appBar: AppBar(
                                    title: Text(context.l10n.remoteCare),
                                  ),
                                  body: CarePage(controller: controller),
                                ),
                        ),
                      ),
                      onEncyclopedia: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: 'health-encyclopedia-categories',
                          ),
                          builder: (_) =>
                              ArticleCategoryPage(controller: controller),
                        ),
                      ),
                      onSport: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: 'sport-overview'),
                          builder: (_) =>
                              SportOverviewPage(controller: controller),
                        ),
                      ),
                      onMall: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: 'shop-home'),
                          builder: (_) => ShopHomePage(
                            controller: controller,
                            ordersPageBuilder: (_) => OrdersPage(
                              controller: controller,
                              initialStatus: null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: UsageInfoButton(
                    key: const Key('dashboard-health-notice'),
                    message: controller.isWellnessOnly
                        ? uiCopy(context, "活动和睡眠为戒指估算，仅供日常作息参考。")
                        : context.l10n.healthDisclaimer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final name = _memberDisplayName(context, controller);
    final avatarUrl = '${controller.memberProfile['head_portrait'] ?? ''}'
        .trim();
    return Row(
      children: [
        Container(
          key: const Key('dashboard-profile-avatar'),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: avatarUrl.isEmpty
              ? const SaydianBrandMark(size: 37, color: SaydianColors.ink)
              : _MemberAvatar(imageUrl: avatarUrl, size: 42),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.health,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                context.l10n.welcome(name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: SaydianColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Badge(
          isLabelVisible: controller.notificationUnreadCount > 0,
          label: Text(
            controller.notificationUnreadCount > 99
                ? '99+'
                : '${controller.notificationUnreadCount}',
          ),
          smallSize: 9,
          backgroundColor: SaydianColors.danger,
          child: IconButton(
            tooltip: controller.notificationUnreadCount > 0
                ? context.l10n.unreadMessages(
                    controller.notificationUnreadCount,
                  )
                : context.l10n.messages,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificationsPage(controller: controller),
              ),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: SaydianColors.techBlue,
              minimumSize: const Size.square(48),
            ),
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
          ),
        ),
      ],
    );
  }
}

// Retained for possible use on the detailed health page; hidden on home.
// ignore: unused_element
class _MindBodyReadinessCard extends StatelessWidget {
  const _MindBodyReadinessCard({required this.latest});

  final Map<HealthMetric, HealthRecord> latest;

  @override
  Widget build(BuildContext context) {
    const inputs = <HealthMetric>[
      HealthMetric.sleep,
      HealthMetric.stress,
      HealthMetric.bodyTemperature,
    ];
    final available = inputs.where(latest.containsKey).length;
    return Card(
      key: const Key('mind-body-readiness-card'),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF1FF), Color(0xFFE3F7FA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: SaydianColors.techBlue, width: 5),
              ),
              child: const Text(
                '--',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiCopy(context, "身心准备度"),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    available == inputs.length
                        ? uiCopy(context, "继续佩戴，积累个人记录")
                        : uiCopy(context, "记录还不够，请继续佩戴"),
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.insights_rounded, color: SaydianColors.brandRed),
          ],
        ),
      ),
    );
  }
}

String _sleepDurationLabel(HealthRecord? record) {
  final hours = record?.values['value'];
  if (hours == null || !hours.isFinite || hours <= 0) return '--';
  return sleepMinutesLabel(hours.toDouble() * 60);
}

class _SleepQuickCard extends StatefulWidget {
  const _SleepQuickCard({required this.controller});

  final AppController controller;

  @override
  State<_SleepQuickCard> createState() => _SleepQuickCardState();
}

class _SleepQuickCardState extends State<_SleepQuickCard> {
  HealthRecord? _latest;
  late (bool, String?, String?) _owner;
  Timer? _refresh;
  int _request = 0;
  bool _failed = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _owner = healthUiOwnerKey(widget.controller);
    widget.controller.addListener(_onChanged);
    unawaited(_load());
  }

  void _onChanged() {
    final owner = healthUiOwnerKey(widget.controller);
    if (owner != _owner) {
      _owner = owner;
      _request++;
      setState(() {
        _latest = null;
        _loading = true;
      });
    }
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    final owner = _owner;
    try {
      final latest = await widget.controller.loadLatestSleepDay();
      if (!mounted || request != _request || owner != _owner) return;
      setState(() {
        _latest = latest;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request || owner != _owner) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _request++;
    _refresh?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final latest = _latest;
    final caption = _loading
        ? uiCopy(context, "正在读取睡眠记录")
        : _failed
        ? uiCopy(context, "睡眠缓存刷新失败，点击查看或重试")
        : latest == null
        ? uiCopy(context, "暂无睡眠记录")
        : uiCopy(
            context,
            "最近一次 · {p0}",
            parameters: [
              DateFormat(
                uiCopy(context, "M月d日"),
              ).format(DateTime.parse(sleepRecordSdkDate(latest))),
            ],
          );
    final showDuration = !_loading && !_failed && latest != null;
    final duration = showDuration
        ? Text(
            _sleepDurationLabel(latest),
            style: const TextStyle(
              color: SaydianColors.midnight,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          )
        : null;
    return Material(
      key: const Key('home-sleep-overview-entry'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: SaydianColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'sleep-overview'),
            builder: (_) => SleepOverviewPage(controller: controller),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inlineDuration =
                  constraints.maxWidth >= 280 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.2;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: SaydianColors.techVioletSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bedtime_outlined,
                          color: SaydianColors.sleep,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uiCopy(context, "睡眠概览"),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              caption,
                              style: const TextStyle(
                                color: SaydianColors.muted,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (duration != null && inlineDuration)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: duration,
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: SaydianColors.muted,
                        size: 20,
                      ),
                    ],
                  ),
                  if (latest != null && duration != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 48,
                        top: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!inlineDuration) ...[
                            duration,
                            const SizedBox(height: 4),
                          ],
                          SleepStageMiniBar(record: latest),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class SleepOverviewPage extends StatelessWidget {
  const SleepOverviewPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('sleep-overview-page'),
    appBar: AppBar(title: Text(uiCopy(context, "睡眠"))),
    body: SleepDayDetails(
      controller: controller,
      onOpenTrend: (date) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'sleep-trend'),
          builder: (_) => HealthTrendPage(
            controller: controller,
            metric: HealthMetric.sleep,
            initialDate: date,
          ),
        ),
      ),
    ),
  );
}

// Reads the complete saved local day, rather than the latest record/cache.
class _DashboardActivity extends StatefulWidget {
  const _DashboardActivity({required this.controller});
  final AppController controller;
  @override
  State<_DashboardActivity> createState() => _DashboardActivityState();
}

class _DashboardActivityState extends State<_DashboardActivity>
    with WidgetsBindingObserver {
  Map<HealthMetric, num> _values = const {};
  late (bool, String?, String?) _owner;
  Timer? _refresh;
  Timer? _midnight;
  int _generation = 0;
  int? _activeRead;
  Completer<void> _readFence = Completer<void>();
  bool _reloadQueued = false;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _owner = healthUiOwnerKey(widget.controller);
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _scheduleDay();
  }

  void _invalidateReads() {
    _generation++;
    _readFence.complete();
    _readFence = Completer<void>();
    _activeRead = null;
    _reloadQueued = false;
    _refresh?.cancel();
    _refresh = null;
  }

  @override
  void didUpdateWidget(covariant _DashboardActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChanged);
    widget.controller.addListener(_onChanged);
    _owner = healthUiOwnerKey(widget.controller);
    _invalidateReads();
    _values = const {};
    _loading = true;
    _failed = false;
    unawaited(_load());
  }

  void _scheduleDay() {
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (!mounted) return;
        _invalidateReads();
        setState(() {
          _values = const {};
          _loading = true;
        });
        unawaited(_load());
        _scheduleDay();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _invalidateReads();
      setState(() {
        _values = const {};
        _loading = true;
      });
      unawaited(_load());
      _scheduleDay();
    }
  }

  void _onChanged() {
    final owner = healthUiOwnerKey(widget.controller);
    if (owner != _owner) {
      _owner = owner;
      _invalidateReads();
      setState(() {
        _values = const {};
        _loading = true;
        _failed = false;
      });
    }
    // Leading-edge scheduling: continuous sync progress must not starve updates.
    _refresh ??= Timer(const Duration(milliseconds: 250), () {
      _refresh = null;
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_activeRead != null) {
      _reloadQueued = true;
      return;
    }
    final generation = ++_generation;
    _activeRead = generation;
    final owner = _owner;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    try {
      final batches = await Future.any<List<List<HealthRecord>>>([
        _readFence.future.then((_) => const <List<HealthRecord>>[]),
        Future.wait([
          for (final metric in const [
            HealthMetric.steps,
            HealthMetric.distance,
          ])
            widget.controller.loadHealthRecords(
              metric: metric,
              start: start,
              end: end,
            ),
        ]),
      ]).timeout(const Duration(seconds: 10));
      if (!mounted ||
          generation != _generation ||
          owner != healthUiOwnerKey(widget.controller)) {
        return;
      }
      setState(() {
        _values = _todayActivityValues(batches.expand((batch) => batch), now);
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted ||
          generation != _generation ||
          owner != healthUiOwnerKey(widget.controller)) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    } finally {
      if (mounted && _activeRead == generation) {
        // Release this read's cancellation listener before starting another.
        _readFence.complete();
        _readFence = Completer<void>();
        _activeRead = null;
        if (_reloadQueued) {
          _reloadQueued = false;
          unawaited(_load());
        }
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _readFence.complete();
    _refresh?.cancel();
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TodayHealthOverview(
        latest: _values,
        stepTarget: widget.controller.stepGoal.toDouble(),
        distanceTarget: widget.controller.distanceGoal,
        onSetGoal: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'activity-goals'),
            builder: (_) => GoalSettingsPage(controller: widget.controller),
          ),
        ),
        onOpenMetric: (metric) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: 'activity-${metric.wireName}'),
            builder: (_) =>
                HealthTrendPage(controller: widget.controller, metric: metric),
          ),
        ),
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (_failed)
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(uiCopy(context, "今日活动读取失败，点击重试")),
        ),
    ],
  );
}

class _TodayHealthOverview extends StatelessWidget {
  const _TodayHealthOverview({
    required this.latest,
    required this.stepTarget,
    required this.distanceTarget,
    required this.onSetGoal,
    required this.onOpenMetric,
  });
  final Map<HealthMetric, num> latest;
  final double stepTarget, distanceTarget;
  final VoidCallback onSetGoal;
  final ValueChanged<HealthMetric> onOpenMetric;

  @override
  Widget build(BuildContext context) {
    final step = latest[HealthMetric.steps];
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoalProgressRow(
          metric: HealthMetric.steps,
          value: step,
          target: stepTarget,
          color: SaydianColors.techBlue,
          onTap: () => onOpenMetric(HealthMetric.steps),
        ),
        const SizedBox(height: 8),
        _GoalProgressRow(
          metric: HealthMetric.distance,
          value: latest[HealthMetric.distance],
          target: distanceTarget,
          color: SaydianColors.activity,
          onTap: () => onOpenMetric(HealthMetric.distance),
        ),
      ],
    );
    final rings = Semantics(
      label: uiCopy(context, "今日活动目标进度，点击查看步数趋势"),
      value: latest.isEmpty
          ? uiCopy(context, "暂无数据")
          : uiCopy(
              context,
              "步数 {p0}，距离 {p1} 公里",
              parameters: [step ?? '--', latest[HealthMetric.distance] ?? '--'],
            ),
      button: true,
      excludeSemantics: true,
      onTap: () => onOpenMetric(HealthMetric.steps),
      child: InkWell(
        key: const Key('home-activity-rings'),
        onTap: () => onOpenMetric(HealthMetric.steps),
        borderRadius: BorderRadius.circular(100),
        child: SizedBox.square(
          dimension: 136,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (index, value, target, color) in [
                (0, step, stepTarget, SaydianColors.techBlue),
                (
                  1,
                  latest[HealthMetric.distance],
                  distanceTarget,
                  SaydianColors.activity,
                ),
              ])
                SizedBox.square(
                  dimension: 128 - index * 32.0,
                  child: CircularProgressIndicator(
                    key: ValueKey('activity-goal-ring-$index'),
                    value: value == null || !target.isFinite || target <= 0
                        ? 0
                        : (value.toDouble() / target).clamp(0.0, 1.0),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: color.withValues(alpha: .10),
                    semanticsLabel: uiCopy(
                      context,
                      '{p0}目标',
                      parameters: [
                        index == 0 ? context.l10n.steps : context.l10n.distance,
                      ],
                    ),
                  ),
                ),
              const Icon(
                Icons.directions_walk_rounded,
                size: 26,
                color: SaydianColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
    return Card(
      key: const Key('dashboard-today-health'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: SaydianColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.todayActivity,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: onSetGoal,
                  child: Text(context.l10n.goals),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 240 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.2;
                // 今日活动只呈现步数／距离；缩小图形与留白，不压缩文字或点击区。
                // 热量原始记录、同步和详情仍由原来的数据链路保留。
                final ringWidth = (constraints.maxWidth * .39)
                    .clamp(98.0, 124.0)
                    .toDouble();
                return stack
                    ? Column(
                        children: [rings, const SizedBox(height: 12), rows],
                      )
                    : Row(
                        children: [
                          SizedBox.square(
                            key: const Key('activity-progress-rings-panel'),
                            dimension: ringWidth,
                            child: FittedBox(child: rings),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: rows),
                        ],
                      );
              },
            ),
            if (latest.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                uiCopy(context, "暂无今日活动数据"),
                textAlign: TextAlign.center,
                style: TextStyle(color: SaydianColors.muted, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({
    required this.metric,
    required this.value,
    required this.target,
    required this.color,
    required this.onTap,
  });
  final HealthMetric metric;
  final num? value;
  final double target;
  final Color color;
  final VoidCallback onTap;
  String _format(num number) => metric == HealthMetric.distance
      ? number.toStringAsFixed(2)
      : number.round().toString();
  @override
  Widget build(BuildContext context) {
    final unit = switch (metric) {
      HealthMetric.distance =>
        context.l10n.localeName.startsWith('zh') ? uiCopy(context, "公里") : 'km',
      HealthMetric.calories => uiCopy(context, "千卡"),
      _ => uiCopy(context, metric.defaultUnit),
    };
    // 目标值只本地化显示，不改目标存储或计量值；英文单位留空格并保持紧凑。
    final chinese = context.l10n.localeName.startsWith('zh');
    final targetLabel = metric == HealthMetric.steps && !chinese
        ? context.l10n.stepCount(target.round())
        : '${_format(target)}${chinese ? '' : ' '}$unit';
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.l10n.metricName(metric),
                        style: const TextStyle(
                          fontSize: 15,
                          color: SaydianColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value == null ? '--' : _format(value!),
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/$targetLabel',
                          style: const TextStyle(
                            fontSize: 14,
                            color: SaydianColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureEntryGrid extends StatelessWidget {
  const _FeatureEntryGrid({
    required this.commerceEnabled,
    required this.encyclopediaEnabled,
    required this.onCare,
    required this.onEncyclopedia,
    required this.onSport,
    required this.onMall,
    this.onWeek,
    this.onAskAi,
  });

  final VoidCallback onCare, onEncyclopedia, onSport, onMall;
  final VoidCallback? onWeek, onAskAi;
  final bool commerceEnabled, encyclopediaEnabled;

  @override
  Widget build(BuildContext context) {
    final entries = [
      _FeatureEntry(
        label: context.l10n.workouts,
        icon: Icons.directions_run_rounded,
        onTap: onSport,
      ),
      _FeatureEntry(
        label: context.l10n.remoteCare,
        icon: Icons.family_restroom_outlined,
        onTap: onCare,
      ),
      if (onWeek != null)
        _FeatureEntry(
          key: const Key('dashboard-my-week'),
          label: ringText(context, '我的这一周', 'My week'),
          icon: Icons.calendar_view_week_outlined,
          onTap: onWeek!,
        ),
      if (encyclopediaEnabled)
        _FeatureEntry(
          label: context.l10n.healthLibrary,
          icon: Icons.menu_book_outlined,
          onTap: onEncyclopedia,
        ),
      if (onAskAi != null)
        KeyedSubtree(
          key: const Key('dashboard-ai-assistant'),
          child: _FeatureEntry(
            key: const Key('dashboard-ai-ask'),
            label: context.l10n.aiAssistant,
            icon: Icons.auto_awesome_outlined,
            onTap: onAskAi!,
          ),
        ),
      if (commerceEnabled)
        _FeatureEntry(
          label: context.l10n.shop,
          icon: Icons.shopping_bag_outlined,
          onTap: onMall,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ringText(context, '快捷入口', 'Shortcuts'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('dashboard-functions'),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: SaydianColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final twoColumns =
                  constraints.maxWidth >= 260 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.35;
              final width = twoColumns
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: 4,
                children: [
                  for (final entry in entries)
                    SizedBox(width: width, child: entry),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeatureEntry extends StatelessWidget {
  const _FeatureEntry({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 7),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SaydianColors.techBlueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: SaydianColors.techBlue, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Retained for device-focused layouts; intentionally hidden on the home.
// ignore: unused_element
class _DeviceHero extends StatelessWidget {
  const _DeviceHero({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final device = controller.connectedDevice;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF6FF), Color(0xFFF5F3E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: SaydianColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.watch_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device?.displayName ?? uiCopy(context, "尚未连接戒指"),
                        style: const TextStyle(
                          color: SaydianColors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  device == null
                      ? uiCopy(context, "连接后同步健康数据")
                      : controller.syncStatus.isEmpty
                      ? device.displayModel
                      : '${device.displayModel} · ${controller.syncStatus}',
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => controller.selectTab(1),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(
              device == null ? uiCopy(context, "连接") : uiCopy(context, "管理"),
            ),
          ),
        ],
      ),
    );
  }
}

class HealthMetricCard extends StatelessWidget {
  const HealthMetricCard({
    required this.controller,
    required this.metric,
    required this.record,
    this.onOpen,
    this.records,
    this.readOnly = false,
    this.compact = false,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;
  final VoidCallback? onOpen;
  final List<HealthRecord>? records;
  final bool readOnly;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!controller.isMetricAvailableInRelease(metric)) {
      return const SizedBox.shrink();
    }
    final icon = switch (metric) {
      HealthMetric.steps => Icons.directions_walk,
      HealthMetric.sleep => Icons.bedtime_outlined,
      HealthMetric.heartRate => Icons.favorite_outline,
      HealthMetric.bloodOxygen => Icons.water_drop_outlined,
      HealthMetric.bloodPressure => Icons.speed_outlined,
      HealthMetric.bloodGlucose => Icons.bloodtype_outlined,
      HealthMetric.bodyTemperature => Icons.thermostat_outlined,
      HealthMetric.ecg => Icons.monitor_heart_outlined,
      HealthMetric.hrv => Icons.show_chart_rounded,
      HealthMetric.stress => Icons.spa_outlined,
      HealthMetric.bodyComposition => Icons.accessibility_new_rounded,
      HealthMetric.bloodComposition => Icons.science_outlined,
      _ => Icons.monitor_heart_outlined,
    };
    final style = _metricCardStyle(metric);
    final status = readOnly || controller.isWellnessOnly
        ? (record == null
              ? _HomeMetricStatus.noData
              : _HomeMetricStatus.recorded)
        : _homeMetricStatus(controller, record);
    final needsAttention = !{
      _HomeMetricStatus.normal,
      _HomeMetricStatus.recorded,
      _HomeMetricStatus.noData,
    }.contains(status);
    final statusLabel = record != null && hasUnconfirmedCalorieUnit(record!)
        ? uiCopy(context, "单位待确认")
        : switch (status) {
            _HomeMetricStatus.normal => context.l10n.statusNormal,
            _HomeMetricStatus.recorded => context.l10n.statusRecorded,
            _HomeMetricStatus.noData => context.l10n.noData,
            _HomeMetricStatus.attention => context.l10n.statusAttention,
            _HomeMetricStatus.outOfRange => context.l10n.statusOutOfRange,
            _HomeMetricStatus.low => context.l10n.statusLow,
            _HomeMetricStatus.high => context.l10n.statusHigh,
          };
    // Use the same slots for today's, older and absent readings. Loading or
    // receiving a reading must not resize a row underneath a scrolling finger.
    // Only today's genuine samples are charted; reserved space is not data.
    final textScale = MediaQuery.textScalerOf(context);
    final plotHeight = compact ? 36.0 : 44.0;
    final chartHeight = plotHeight + 6 + (textScale.scale(13) * 1.5).ceil();
    final valueSize = compact ? 28.0 : 32.0;
    final radius = BorderRadius.circular(compact ? 20 : 24);
    final hasToday =
        record != null &&
        DateUtils.isSameDay(
          HealthAnalysisService.displayTime(record!),
          DateTime.now(),
        );
    return ConstrainedBox(
      key: ValueKey('health-metric-${metric.name}'),
      constraints: BoxConstraints(minHeight: compact ? 152 : 170),
      child: DecoratedBox(
        key: ValueKey('health-metric-surface-${metric.name}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: compact ? Border.all(color: SaydianColors.line) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap:
                onOpen ??
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HealthTrendPage(
                      controller: controller,
                      metric: metric,
                      initialDate: record?.measuredAt,
                      onMeasure: !readOnly
                          ? (trendContext) => _showHealthMeasurementDialog(
                              trendContext,
                              controller,
                              metric,
                            )
                          : null,
                    ),
                  ),
                ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: math.max(26, textScale.scale(15) * 1.3 * 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: style.accent, size: 21),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            context.l10n.metricName(metric),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: SaydianColors.muted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 10),
                  SizedBox(
                    height: textScale.scale(valueSize) * 1.15,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _healthDisplayValue(record, controller),
                            style: TextStyle(
                              fontSize: valueSize,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.8,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              _healthDisplayUnit(metric, record, controller),
                              style: const TextStyle(
                                fontSize: 15,
                                color: SaydianColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  SizedBox(
                    height: textScale.scale(14) * 1.3,
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: needsAttention
                            ? SaydianColors.danger
                            : SaydianColors.muted,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  SizedBox(
                    height: chartHeight,
                    child: hasToday
                        ? HealthMetricMiniChart(
                            controller: controller,
                            metric: metric,
                            color: style.accent,
                            showEmptyLabel: false,
                            height: plotHeight,
                            fitToSamples: true,
                            records: readOnly ? records ?? const [] : records,
                          )
                        : null,
                  ),
                  SizedBox(height: compact ? 3 : 6),
                  SizedBox(
                    height: textScale.scale(14) * 1.3,
                    child: Text(
                      record == null
                          ? ''
                          : DateFormat(
                              uiCopy(context, "M月d日 HH:mm"),
                            ).format(record!.measuredAt.toLocal()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: SaydianColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCardStyle {
  const _MetricCardStyle({
    required this.start,
    required this.end,
    required this.accent,
  });

  final Color start;
  final Color end;
  final Color accent;
}

_MetricCardStyle _metricCardStyle(HealthMetric metric) => switch (metric) {
  HealthMetric.heartRate || HealthMetric.ecg => const _MetricCardStyle(
    start: Color(0xFFE8EDFF),
    end: Color(0xFFE3F7FA),
    accent: Color(0xFF4F5FE7),
  ),
  HealthMetric.bloodOxygen => const _MetricCardStyle(
    start: Color(0xFFE2F6FF),
    end: Color(0xFFE8EDFF),
    accent: Color(0xFF2D82E9),
  ),
  HealthMetric.bloodPressure ||
  HealthMetric.bloodGlucose => const _MetricCardStyle(
    start: Color(0xFFE9EEFF),
    end: Color(0xFFF0EBFF),
    accent: Color(0xFF6258E8),
  ),
  HealthMetric.bodyTemperature => const _MetricCardStyle(
    start: Color(0xFFE4F6F8),
    end: Color(0xFFEDF3FF),
    accent: Color(0xFF208EA2),
  ),
  HealthMetric.hrv => const _MetricCardStyle(
    start: Color(0xFFEDEAFF),
    end: Color(0xFFE5F4FF),
    accent: Color(0xFF7059E8),
  ),
  HealthMetric.stress => const _MetricCardStyle(
    start: Color(0xFFE1F8F4),
    end: Color(0xFFEAF2FF),
    accent: Color(0xFF15977F),
  ),
  HealthMetric.sleep => const _MetricCardStyle(
    start: Color(0xFFE5EAFF),
    end: Color(0xFFEEEDFF),
    accent: Color(0xFF485FD3),
  ),
  HealthMetric.bodyComposition ||
  HealthMetric.bloodComposition => const _MetricCardStyle(
    start: Color(0xFFE9F8F7),
    end: Color(0xFFEAF0FF),
    accent: Color(0xFF2A8EA1),
  ),
  _ => const _MetricCardStyle(
    start: Color(0xFFEAF0FF),
    end: Color(0xFFE5F8F8),
    accent: SaydianColors.techBlue,
  ),
};

enum _HomeMetricStatus {
  normal,
  recorded,
  noData,
  attention,
  outOfRange,
  low,
  high,
}

_HomeMetricStatus _homeMetricStatus(
  AppController controller,
  HealthRecord? record,
) {
  if (record == null) return _HomeMetricStatus.noData;
  final quality = record.quality.toLowerCase();
  if (quality.contains('poor') ||
      quality.contains('warning') ||
      quality.contains('abnormal')) {
    return _HomeMetricStatus.attention;
  }
  final primary = record.values['value'];
  if (record.metric == HealthMetric.heartRate &&
      primary != null &&
      (primary < 60 || primary > 100)) {
    return _HomeMetricStatus.outOfRange;
  }
  if (record.metric == HealthMetric.bloodOxygen &&
      primary != null &&
      primary < 95) {
    return _HomeMetricStatus.low;
  }
  if (record.metric == HealthMetric.bloodPressure) {
    final systolic = record.values['systolic'];
    final diastolic = record.values['diastolic'];
    if (systolic != null && diastolic != null) {
      if (systolic >= 140 || diastolic >= 90) return _HomeMetricStatus.high;
      if (systolic < 90 || diastolic < 60) return _HomeMetricStatus.low;
    }
  }
  if (record.metric == HealthMetric.ecg) {
    return (record.values['deviceAbnormalFlags'] ?? 0) > 0
        ? _HomeMetricStatus.attention
        : _HomeMetricStatus.recorded;
  }
  if (record.metric == HealthMetric.hrv ||
      record.metric == HealthMetric.bodyTemperature) {
    return _HomeMetricStatus.recorded;
  }
  if (record.metric == HealthMetric.stress && primary != null) {
    if (primary >= 80) return _HomeMetricStatus.high;
    if (primary >= 60) return _HomeMetricStatus.attention;
    return _HomeMetricStatus.normal;
  }
  final settings = controller.healthWarningSettings;
  if (record.metric == HealthMetric.heartRate && settings.heartRateEnabled) {
    final value = record.values['value'];
    if (value != null && value > settings.heartRateUpper) {
      return _HomeMetricStatus.attention;
    }
  }
  if (record.metric == HealthMetric.bloodPressure &&
      settings.bloodPressureEnabled) {
    final systolic = record.values['systolic'];
    final diastolic = record.values['diastolic'];
    if ((systolic != null && systolic > settings.systolicUpper) ||
        (diastolic != null && diastolic > settings.diastolicUpper)) {
      return _HomeMetricStatus.attention;
    }
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      settings.temperatureEnabled) {
    final value = record.values['value'];
    if (value != null && value > settings.temperatureUpper) {
      return _HomeMetricStatus.attention;
    }
  }
  return _HomeMetricStatus.normal;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.onEdit,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: Theme.of(context).textTheme.titleLarge);
    final actions = Wrap(
      alignment: WrapAlignment.end,
      children: [
        if (onEdit != null)
          TextButton(
            key: const Key('edit-home-health-cards'),
            onPressed: onEdit,
            child: Text(uiCopy(context, "编辑")),
          ),
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              Align(alignment: AlignmentDirectional.centerEnd, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            actions,
          ],
        );
      },
    );
  }
}
