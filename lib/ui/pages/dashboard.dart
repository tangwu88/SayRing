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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      widget.controller.clearError();
      _scheduledError = null;
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
        HealthMetric.calories,
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
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DashboardHeader(controller: controller),
                  const SizedBox(height: 12),
                  if (controller.shouldShowHealthMetric(
                    HealthMetric.steps,
                  )) ...[
                    _DashboardActivity(controller: controller),
                    const SizedBox(height: 16),
                  ],
                  if (controller.shouldShowHealthMetric(
                    HealthMetric.sleep,
                  )) ...[
                    _SleepQuickCard(controller: controller),
                    const SizedBox(height: 16),
                  ],
                  _FeatureEntryGrid(
                    commerceEnabled: controller.mallVisible,
                    encyclopediaEnabled: controller.healthLibraryVisible,
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
                  const SizedBox(height: 16),
                  if (!controller.hideAiContent) ...[
                    _AiHealthAssistantCard(controller: controller),
                    const SizedBox(height: 12),
                  ],
                  _SectionTitle(
                    title: context.l10n.healthData,
                    subtitle: context.l10n.recentData,
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
                        settings: const RouteSettings(name: 'all-health-data'),
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
                          ? '首页暂无卡片，点击编辑添加'
                          : disconnected
                          ? context.l10n.connectWatchForData
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
                            constraints.maxWidth >= 350 &&
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
                                child: HealthMetricCard(
                                  key: ValueKey(
                                    'home-health-card-${metric.wireName}',
                                  ),
                                  controller: controller,
                                  metric: metric,
                                  record: latest[metric],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: InlineNotice(
                    key: const Key('dashboard-health-notice'),
                    message: controller.isWellnessOnly
                        ? '活动和睡眠为戒指估算，仅供日常作息参考。'
                        : context.l10n.healthDisclaimer,
                    icon: Icons.health_and_safety_outlined,
                    color: SaydianColors.green,
                    compact: true,
                    legal: true,
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
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: avatarUrl.isEmpty
              ? const SaydianBrandMark(size: 46, color: SaydianColors.ink)
              : _MemberAvatar(imageUrl: avatarUrl, size: 50),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.welcome(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.dailyGreeting,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
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
            icon: const Icon(Icons.notifications_none_rounded, size: 27),
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
                  const Text(
                    '身心准备度',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    available == inputs.length
                        ? '正在建立个人基线，暂不生成未经确认的评分'
                        : '数据不足 · 已具备 $available/${inputs.length} 项基线数据',
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 13,
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

class _AiHealthAssistantCard extends StatelessWidget {
  const _AiHealthAssistantCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final stacked = textScale >= 1.8;
    final doctor = SizedBox(
      height: stacked ? 196 : 140,
      child: ClipRect(
        child: stacked
            ? Image.asset(
                'assets/branding/ai-health-manager-doctor-optimized.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              )
            : Transform.scale(
                scale: 1.28,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(18, 0),
                  child: Image.asset(
                    'assets/branding/ai-health-manager-doctor-optimized.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
      ),
    );
    final content = Padding(
      padding: EdgeInsets.fromLTRB(stacked ? 16 : 4, stacked ? 6 : 7, 13, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.aiAssistant,
            style: const TextStyle(
              color: Color(0xFF244BA8),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.l10n.aiAssistantIntro,
            style: const TextStyle(
              color: SaydianColors.ink,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          FilledButton(
            key: const Key('dashboard-ai-ask'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'ai-health-chat'),
                builder: (_) => AiChatPage(controller: controller, app: 1),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: SaydianColors.techBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: const StadiumBorder(),
            ),
            child: Text(
              context.l10n.askNow,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('dashboard-ai-assistant'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F8FF), Color(0xFFE8F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18316EF5),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: const Color(0x66316EF5), width: 1.2),
        borderRadius: BorderRadius.circular(26),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [doctor, content],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 36, child: doctor),
                Expanded(flex: 64, child: content),
              ],
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
        ? '正在读取睡眠记录'
        : _failed
        ? '睡眠缓存刷新失败，点击查看或重试'
        : latest == null
        ? sleepSyncUnavailable(controller)
              ? '当前戒指的睡眠同步暂未开放'
              : '暂无睡眠记录，佩戴戒指睡眠后同步数据'
        : '最近一次 · ${DateFormat('M月d日').format(DateTime.parse(sleepRecordSdkDate(latest)))}';
    return Material(
      key: const Key('home-sleep-overview-entry'),
      color: const Color(0xFFF0EEF8),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'sleep-overview'),
            builder: (_) => SleepOverviewPage(controller: controller),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    color: SaydianColors.sleep,
                    size: 23,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '睡眠概览',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: SaydianColors.sleep),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _loading || _failed ? '--' : _sleepDurationLabel(latest),
                style: const TextStyle(
                  color: SaydianColors.midnight,
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                caption,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                ),
              ),
            ],
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
    appBar: AppBar(title: const Text('睡眠')),
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
  bool _calorieUnitPending = false;

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
    _calorieUnitPending = false;
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
            HealthMetric.calories,
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
        _calorieUnitPending =
            !_values.containsKey(HealthMetric.calories) &&
            batches.expand((batch) => batch).any(hasUnconfirmedCalorieUnit);
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
        calorieTarget: widget.controller.calorieGoal.toDouble(),
        calorieUnitPending: _calorieUnitPending,
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
          label: const Text('今日活动读取失败，点击重试'),
        ),
    ],
  );
}

class _TodayHealthOverview extends StatelessWidget {
  const _TodayHealthOverview({
    required this.latest,
    required this.stepTarget,
    required this.distanceTarget,
    required this.calorieTarget,
    required this.onSetGoal,
    required this.onOpenMetric,
    this.calorieUnitPending = false,
  });
  final Map<HealthMetric, num> latest;
  final double stepTarget, distanceTarget, calorieTarget;
  final VoidCallback onSetGoal;
  final ValueChanged<HealthMetric> onOpenMetric;
  final bool calorieUnitPending;

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
        const SizedBox(height: 12),
        _GoalProgressRow(
          metric: HealthMetric.distance,
          value: latest[HealthMetric.distance],
          target: distanceTarget,
          color: SaydianColors.activity,
          onTap: () => onOpenMetric(HealthMetric.distance),
        ),
        const SizedBox(height: 12),
        _GoalProgressRow(
          metric: HealthMetric.calories,
          value: latest[HealthMetric.calories],
          target: calorieTarget,
          color: SaydianColors.energy,
          unavailableReason: calorieUnitPending ? '单位待确认' : null,
          onTap: () => onOpenMetric(HealthMetric.calories),
        ),
      ],
    );
    final rings = Semantics(
      label: '今日活动目标进度，点击查看步数趋势',
      value: latest.isEmpty
          ? '暂无数据'
          : '步数 ${step ?? '--'}，距离 ${latest[HealthMetric.distance] ?? '--'} 公里，热量 ${calorieUnitPending ? '单位待确认' : '${latest[HealthMetric.calories] ?? '--'} 千卡'}',
      button: true,
      excludeSemantics: true,
      onTap: () => onOpenMetric(HealthMetric.steps),
      child: InkWell(
        key: const Key('home-activity-rings'),
        onTap: () => onOpenMetric(HealthMetric.steps),
        borderRadius: BorderRadius.circular(100),
        child: SizedBox.square(
          dimension: 164,
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
                (
                  2,
                  latest[HealthMetric.calories],
                  calorieTarget,
                  SaydianColors.energy,
                ),
              ])
                SizedBox.square(
                  dimension: 148 - index * 34.0,
                  child: CircularProgressIndicator(
                    key: ValueKey('activity-goal-ring-$index'),
                    value: value == null || !target.isFinite || target <= 0
                        ? 0
                        : (value.toDouble() / target).clamp(0.0, 1.0),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: color.withValues(alpha: .10),
                    semanticsLabel: '${["步数", "距离", "热量"][index]}目标',
                  ),
                ),
              const Icon(
                Icons.directions_walk_rounded,
                size: 29,
                color: SaydianColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
    return Card(
      key: const Key('dashboard-today-health'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.todayActivity,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSetGoal,
                  child: Text(context.l10n.goals),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 310 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.2;
                return stack
                    ? Column(
                        children: [rings, const SizedBox(height: 18), rows],
                      )
                    : Row(
                        children: [
                          rings,
                          const SizedBox(width: 18),
                          Expanded(child: rows),
                        ],
                      );
              },
            ),
            if (latest.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '暂无今日活动数据',
                textAlign: TextAlign.center,
                style: TextStyle(color: SaydianColors.muted, fontSize: 13),
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
    this.unavailableReason,
  });
  final HealthMetric metric;
  final num? value;
  final double target;
  final Color color;
  final VoidCallback onTap;
  final String? unavailableReason;
  String _format(num number) => metric == HealthMetric.distance
      ? number.toStringAsFixed(2)
      : number.round().toString();
  @override
  Widget build(BuildContext context) {
    final unit = switch (metric) {
      HealthMetric.distance => '公里',
      HealthMetric.calories => '千卡',
      _ => metric.defaultUnit,
    };
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
                          fontSize: 13,
                          color: SaydianColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 4,
                  children: [
                    Text(
                      value == null ? '--' : _format(value!),
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      unavailableReason ?? '/${_format(target)}$unit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SaydianColors.muted,
                      ),
                    ),
                  ],
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
    this.encyclopediaEnabled = true,
    required this.onCare,
    required this.onEncyclopedia,
    required this.onSport,
    required this.onMall,
  });
  final VoidCallback onCare, onEncyclopedia, onSport, onMall;
  final bool commerceEnabled, encyclopediaEnabled;

  @override
  Widget build(BuildContext context) {
    final entries = <Widget>[
      _FeatureEntry(
        label: context.l10n.remoteCare,
        icon: Icons.family_restroom_outlined,
        color: SaydianColors.techBlue,
        onTap: onCare,
      ),
      if (encyclopediaEnabled)
        _FeatureEntry(
          label: context.l10n.healthLibrary,
          icon: Icons.menu_book_outlined,
          color: SaydianColors.activity,
          onTap: onEncyclopedia,
        ),
      _FeatureEntry(
        label: context.l10n.workouts,
        icon: Icons.directions_run_rounded,
        color: SaydianColors.sleep,
        onTap: onSport,
      ),
      if (commerceEnabled)
        _FeatureEntry(
          label: context.l10n.shop,
          icon: Icons.shopping_bag_outlined,
          color: SaydianColors.energy,
          onTap: onMall,
        ),
    ];
    return Container(
      key: const Key('dashboard-functions'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(1) > 1.2
              ? 2
              : entries.length;
          return Wrap(
            runSpacing: 12,
            children: [
              for (final entry in entries)
                SizedBox(width: constraints.maxWidth / columns, child: entry),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureEntry extends StatelessWidget {
  const _FeatureEntry({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                        device?.name ?? '尚未连接戒指',
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
                      ? '连接后同步健康数据'
                      : '${device.displayModel} · ${controller.syncStatus}',
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 12,
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
            child: Text(device == null ? '连接' : '管理'),
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
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;
  final VoidCallback? onOpen;
  final List<HealthRecord>? records;
  final bool readOnly;

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
        ? '单位待确认'
        : switch (status) {
            _HomeMetricStatus.normal => context.l10n.statusNormal,
            _HomeMetricStatus.recorded => context.l10n.statusRecorded,
            _HomeMetricStatus.noData => context.l10n.noData,
            _HomeMetricStatus.attention => context.l10n.statusAttention,
            _HomeMetricStatus.outOfRange => context.l10n.statusOutOfRange,
            _HomeMetricStatus.low => context.l10n.statusLow,
            _HomeMetricStatus.high => context.l10n.statusHigh,
          };
    return ConstrainedBox(
      key: ValueKey('health-metric-${metric.name}'),
      constraints: const BoxConstraints(minHeight: 190),
      child: DecoratedBox(
        key: ValueKey('health-metric-surface-${metric.name}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 42),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: style.accent, size: 21),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            context.l10n.metricName(metric),
                            style: const TextStyle(
                              fontSize: 15,
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
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 5,
                    children: [
                      Text(
                        _healthDisplayValue(record, controller),
                        style: const TextStyle(
                          fontSize: 32,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.8,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          _healthDisplayUnit(metric, record, controller),
                          style: const TextStyle(
                            fontSize: 13,
                            color: SaydianColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: needsAttention
                          ? SaydianColors.danger
                          : SaydianColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  HealthMetricMiniChart(
                    controller: controller,
                    metric: metric,
                    color: style.accent,
                    showEmptyLabel: false,
                    height: 60,
                    fitToSamples: true,
                    records: readOnly ? records ?? const [] : records,
                  ),
                  if (record != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat(
                        'M月d日 HH:mm',
                      ).format(record!.measuredAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SaydianColors.muted,
                      ),
                    ),
                  ],
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
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.onEdit,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final compactHeading = Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.calendar_month_outlined,
          size: 19,
          color: SaydianColors.muted,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            subtitle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
          ),
        ),
      ],
    );
    final heading = enlargedText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 14,
                ),
              ),
            ],
          )
        : compactHeading;
    final allDataAction = TextButton.icon(
      onPressed: onAction,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded, size: 21),
      label: Text(
        actionLabel,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    final action = Wrap(
      alignment: WrapAlignment.end,
      children: [
        if (onEdit != null)
          TextButton(
            key: const Key('edit-home-health-cards'),
            onPressed: onEdit,
            child: const Text('编辑'),
          ),
        allDataAction,
      ],
    );
    if (enlargedText ||
        (onEdit != null && MediaQuery.sizeOf(context).width < 420)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          Align(alignment: Alignment.centerRight, child: action),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        action,
      ],
    );
  }
}
