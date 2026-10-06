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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFFDCE7F5))),
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
    final metrics = supportedMetrics
        .where(controller.shouldShowHealthMetric)
        .toList(growable: false);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.synchronizeCloud,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DashboardHeader(controller: controller),
                  const SizedBox(height: 12),
                  if (!controller.hideAiContent) ...[
                    _AiHealthAssistantCard(controller: controller),
                    const SizedBox(height: 12),
                  ],
                  _FeatureEntryGrid(
                    commerceEnabled: controller.commerceEnabled,
                    encyclopediaEnabled: !controller.isWellnessOnly,
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
                  if (controller.shouldShowHealthMetric(HealthMetric.sleep))
                    _SleepQuickCard(controller: controller),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    title: context.l10n.healthData,
                    subtitle: context.l10n.recentData,
                    actionLabel: context.l10n.allData,
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
                      message: disconnected
                          ? context.l10n.connectWatchForData
                          : context.l10n.noHealthData,
                      icon: Icons.watch_outlined,
                      color: SaydianColors.blue,
                      compact: true,
                      centered: true,
                      onTap: disconnected
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
                    ListView.separated(
                      key: const Key('dashboard-health-card-list'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: metrics.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final metric = metrics[index];
                        return HealthMetricCard(
                          controller: controller,
                          metric: metric,
                          record: latest[metric],
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
              ? const SaydianBrandMark(size: 46)
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
                  fontWeight: FontWeight.w900,
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
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '身心准备度',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
              fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w900,
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
    return Material(
      key: const Key('home-sleep-overview-entry'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: saydianPanelGradient,
          border: Border.all(color: const Color(0x66316EF5)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'sleep-overview'),
              builder: (_) => SleepOverviewPage(controller: controller),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.bedtime_outlined,
                  color: SaydianColors.techIndigo,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '睡眠概览',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _loading
                            ? '正在读取睡眠记录'
                            : _failed
                            ? '睡眠缓存刷新失败，点击查看或重试'
                            : latest == null
                            ? sleepSyncUnavailable(controller)
                                  ? '当前戒指的睡眠同步暂未开放'
                                  : '暂无睡眠记录，佩戴戒指睡眠后同步数据'
                            : '最近一次 · ${DateFormat('M月d日').format(DateTime.parse(sleepRecordSdkDate(latest)))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _sleepDurationLabel(latest),
                  style: const TextStyle(
                    color: SaydianColors.techIndigo,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SaydianColors.techIndigo,
                ),
              ],
            ),
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

class _TodayHealthOverview extends StatelessWidget {
  const _TodayHealthOverview({
    required this.latest,
    required this.stepTarget,
    required this.distanceTarget,
    required this.calorieTarget,
    required this.onSetGoal,
    required this.onOpenMetric,
  });

  final Map<HealthMetric, num> latest;
  final double stepTarget;
  final double distanceTarget;
  final double calorieTarget;
  final VoidCallback onSetGoal;
  final ValueChanged<HealthMetric> onOpenMetric;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('dashboard-today-health'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEAF1FF), Color(0xFFE3F7FA)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.todayActivity,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.dailyActivityGoalHint,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onSetGoal,
                    icon: const Icon(Icons.track_changes_rounded, size: 18),
                    label: Text(context.l10n.goals),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
            child: Column(
              children: [
                _GoalProgressRow(
                  metric: HealthMetric.steps,
                  value: latest[HealthMetric.steps],
                  target: stepTarget,
                  color: SaydianColors.techBlue,
                  onTap: () => onOpenMetric(HealthMetric.steps),
                ),
                const SizedBox(height: 16),
                _GoalProgressRow(
                  metric: HealthMetric.distance,
                  value: latest[HealthMetric.distance],
                  target: distanceTarget,
                  color: SaydianColors.techCyan,
                  onTap: () => onOpenMetric(HealthMetric.distance),
                ),
                const SizedBox(height: 16),
                _GoalProgressRow(
                  metric: HealthMetric.calories,
                  value: latest[HealthMetric.calories],
                  target: calorieTarget,
                  color: SaydianColors.techIndigo,
                  onTap: () => onOpenMetric(HealthMetric.calories),
                ),
              ],
            ),
          ),
        ],
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

  String _format(num value) {
    if (metric == HealthMetric.distance) return value.toStringAsFixed(2);
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    final progress = current == null
        ? 0.0
        : (current.toDouble() / target).clamp(0.0, 1.0).toDouble();
    final unit = switch (metric) {
      HealthMetric.distance => '公里',
      HealthMetric.calories => '千卡',
      _ => metric.defaultUnit,
    };
    final currentText = current == null ? '--' : _format(current);
    final targetText = _format(target);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 34,
            child: Text(
              context.l10n.metricName(metric),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 106,
            child: Text(
              '$currentText/$targetText$unit',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                color: SaydianColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

  final VoidCallback onCare;
  final VoidCallback onEncyclopedia;
  final VoidCallback onSport;
  final VoidCallback onMall;
  final bool commerceEnabled;
  final bool encyclopediaEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard-functions'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFEDF5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD9E7FA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14316EF5),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: _FeatureEntry(
                label: context.l10n.remoteCare,
                icon: Icons.family_restroom_rounded,
                color: const Color(0xFF4F67E8),
                onTap: onCare,
              ),
            ),
            if (encyclopediaEnabled)
              Expanded(
                child: _FeatureEntry(
                  label: context.l10n.healthLibrary,
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF149FB3),
                  onTap: onEncyclopedia,
                ),
              ),
            Expanded(
              child: _FeatureEntry(
                label: context.l10n.workouts,
                icon: Icons.directions_run_rounded,
                color: const Color(0xFF7059E8),
                onTap: onSport,
              ),
            ),
            if (commerceEnabled)
              Expanded(
                child: _FeatureEntry(
                  label: context.l10n.shop,
                  icon: Icons.shopping_bag_rounded,
                  color: const Color(0xFF2887D8),
                  onTap: onMall,
                ),
              ),
          ],
        ),
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.92),
                    color.withValues(alpha: 0.68),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 13,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final statusLabel = switch (status) {
      _HomeMetricStatus.normal => context.l10n.statusNormal,
      _HomeMetricStatus.recorded => context.l10n.statusRecorded,
      _HomeMetricStatus.noData => context.l10n.noData,
      _HomeMetricStatus.attention => context.l10n.statusAttention,
      _HomeMetricStatus.outOfRange => context.l10n.statusOutOfRange,
      _HomeMetricStatus.low => context.l10n.statusLow,
      _HomeMetricStatus.high => context.l10n.statusHigh,
    };
    final supportsManualMeasurement =
        !readOnly && controller.canMeasureHealthMetric(metric);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardHeight = 184 + (textScale - 1) * 104;
    return SizedBox(
      key: ValueKey('health-metric-${metric.name}'),
      height: cardHeight,
      child: DecoratedBox(
        key: ValueKey('health-metric-surface-${metric.name}'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [style.start, style.end],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          boxShadow: [
            BoxShadow(
              color: style.accent.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 13),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap:
                onOpen ??
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HealthTrendPage(
                      controller: controller,
                      metric: metric,
                      onMeasure: supportsManualMeasurement
                          ? (trendContext) => _showHealthMeasurementDialog(
                              trendContext,
                              controller,
                              metric,
                            )
                          : null,
                    ),
                  ),
                ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned(
                    right: -36,
                    top: -54,
                    child: Container(
                      width: 164,
                      height: 164,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    bottom: -58,
                    child: Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: style.accent.withValues(alpha: 0.11),
                          width: 24,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: style.accent, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.metricName(metric),
                                maxLines: metric == HealthMetric.hrv ? 2 : 1,
                                softWrap: metric == HealthMetric.hrv,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 88),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    statusLabel,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: record == null
                                          ? SaydianColors.muted
                                          : needsAttention
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFF27852A),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: style.accent.withValues(alpha: 0.72),
                              size: 15,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              flex: 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _healthDisplayValue(record, controller),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  _healthDisplayUnit(
                                    metric,
                                    record,
                                    controller,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: SaydianColors.ink.withValues(
                                      alpha: 0.62,
                                    ),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: HealthMetricMiniChart(
                            controller: controller,
                            metric: metric,
                            color: style.accent,
                            showEmptyLabel: false,
                            records: readOnly ? records ?? const [] : records,
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
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final action = TextButton.icon(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 19,
              color: SaydianColors.muted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
