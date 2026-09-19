import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';
import '../services/app_controller.dart';
import 'app_theme.dart';
import 'health_trend_page.dart';
import 'pages.dart';
import 'widgets/safe_network_image.dart';

/// The ring-first presentation. Imported feature pages remain available as
/// light routes while the four daily destinations use a distinct dark shell.
class RingShell extends StatelessWidget {
  const RingShell({required this.controller, super.key});

  final AppController controller;

  static const _background = Color(0xFF090B10);
  static const _surface = Color(0xFF20242C);
  static const _accent = Color(0xFF79E87E);
  static const _muted = Color(0xFFABB5C2);

  ThemeData _theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        onPrimary: Color(0xFF09220D),
        surface: _surface,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: const Color(0xFF25282E),
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 27,
            color: states.contains(WidgetState.selected) ? _accent : _muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? _accent : _muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedTab;
    final navigationIndex = switch (selected) {
      3 => 1,
      4 => 2,
      2 || 1 => 3,
      _ => 0,
    };
    return Theme(
      data: _theme(),
      child: Scaffold(
        key: const Key('ring-shell'),
        body: switch (selected) {
          3 => _RingSleepPage(controller: controller),
          4 => _RingSportPage(controller: controller),
          2 => _RingMePage(controller: controller),
          1 => Theme(
            data: buildSaydianTheme(),
            child: Scaffold(
              appBar: AppBar(title: Text(context.l10n.device)),
              body: DevicePage(controller: controller),
            ),
          ),
          _ => _RingHomePage(controller: controller),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationIndex,
          onDestinationSelected: (index) =>
              controller.selectTab(const [0, 3, 4, 2][index]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: context.l10n.health,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bedtime_outlined),
              selectedIcon: const Icon(Icons.bedtime_rounded),
              label: context.l10n.sleep,
            ),
            NavigationDestination(
              icon: const Icon(Icons.directions_run_outlined),
              selectedIcon: const Icon(Icons.directions_run_rounded),
              label: context.l10n.workouts,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: context.l10n.profile,
            ),
          ],
        ),
      ),
    );
  }

  static void openLight(BuildContext context, Widget page, String name) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(name: name),
        builder: (_) => Theme(data: buildSaydianTheme(), child: page),
      ),
    );
  }
}

class _RingHomePage extends StatelessWidget {
  const _RingHomePage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestByMetric;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.synchronizeCloud,
        child: ListView(
          key: const Key('ring-home'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SAY RING',
                    style: TextStyle(
                      fontSize: 27,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.messages,
                  onPressed: () => RingShell.openLight(
                    context,
                    NotificationsPage(controller: controller),
                    'ring-notifications',
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _OverviewCard(controller: controller),
            const SizedBox(height: 18),
            _MetricTile(
              controller: controller,
              metric: HealthMetric.heartRate,
              record: latest[HealthMetric.heartRate],
              icon: Icons.favorite_outline_rounded,
              tint: const Color(0xFFFF6C7A),
            ),
            const SizedBox(height: 12),
            _MetricTile(
              controller: controller,
              metric: HealthMetric.bloodOxygen,
              record: latest[HealthMetric.bloodOxygen],
              icon: Icons.water_drop_outlined,
              tint: const Color(0xFF7ECAF3),
            ),
            const SizedBox(height: 12),
            _MetricTile(
              controller: controller,
              metric: HealthMetric.sleep,
              record: latest[HealthMetric.sleep],
              icon: Icons.bedtime_outlined,
              tint: const Color(0xFFB3A4FF),
            ),
            const SizedBox(height: 20),
            _SectionHeading(title: context.l10n.allData),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.monitor_heart_outlined,
              title: context.l10n.healthRecords,
              onTap: () => RingShell.openLight(
                context,
                AllHealthDataPage(controller: controller),
                'ring-all-health',
              ),
            ),
            _ActionTile(
              icon: Icons.family_restroom_rounded,
              title: context.l10n.remoteCare,
              onTap: () => RingShell.openLight(
                context,
                Scaffold(
                  appBar: AppBar(title: Text(context.l10n.remoteCare)),
                  body: CarePage(controller: controller),
                ),
                'ring-care',
              ),
            ),
            _ActionTile(
              icon: Icons.more_horiz_rounded,
              title: context.l10n.healthData,
              onTap: () => RingShell.openLight(
                context,
                Scaffold(
                  appBar: AppBar(title: Text(context.l10n.healthData)),
                  body: DashboardPage(controller: controller),
                ),
                'ring-health-features',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.healthDisclaimer,
              textAlign: TextAlign.center,
              style: const TextStyle(color: RingShell._muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final device = controller.connectedDevice;
    final heart = controller.latestByMetric[HealthMetric.heartRate];
    return Container(
      key: const Key('ring-overview-card'),
      height:
          264 +
          (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0) - 1) * 150,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF304F78), Color(0xFF172B47), Color(0xFF101821)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -91,
            child: Container(
              width: 248,
              height: 248,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x555FA2CB), width: 22),
              ),
              child: Center(
                child: Container(
                  width: 138,
                  height: 138,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x446EAAD0),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.healthData,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                device?.name ?? context.l10n.notConnected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFCAD8E8), fontSize: 14),
              ),
              const Spacer(),
              Text(
                _metricValue(HealthMetric.heartRate, heart),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                context.l10n.heartRate,
                style: const TextStyle(color: Color(0xFFCAD8E8), fontSize: 14),
              ),
              const SizedBox(height: 7),
              TextButton.icon(
                onPressed: () => controller.selectTab(1),
                style: TextButton.styleFrom(foregroundColor: RingShell._accent),
                icon: const Icon(Icons.circle_outlined, size: 17),
                label: Text(context.l10n.device),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.controller,
    required this.metric,
    required this.record,
    required this.icon,
    required this.tint,
  });
  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Material(
    color: RingShell._surface,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      key: ValueKey('ring-metric-${metric.name}'),
      borderRadius: BorderRadius.circular(24),
      onTap: () => RingShell.openLight(
        context,
        HealthTrendPage(controller: controller, metric: metric),
        'ring-metric-${metric.name}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: tint.withValues(alpha: 0.18),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.metricName(metric),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record == null ? context.l10n.noData : _recordDate(record!),
                    style: const TextStyle(
                      color: RingShell._muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _metricValue(metric, record),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_right_rounded, color: RingShell._muted),
          ],
        ),
      ),
    ),
  );
}

class _RingSleepPage extends StatelessWidget {
  const _RingSleepPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final record = controller.latestByMetric[HealthMetric.sleep];
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('ring-sleep'),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
        children: [
          _PageHeading(
            title: context.l10n.sleep,
            subtitle: record == null
                ? context.l10n.noData
                : _recordDate(record),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF29325C), Color(0xFF1A1D36)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.sleep,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Icon(
                      Icons.bedtime_rounded,
                      size: 60,
                      color: Color(0xFFB3A4FF),
                    ),
                    const Spacer(),
                    Text(
                      _metricValue(HealthMetric.sleep, record),
                      style: const TextStyle(
                        fontSize: 45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  record == null ? context.l10n.noData : _recordDate(record),
                  style: const TextStyle(color: RingShell._muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.show_chart_rounded,
            title: context.l10n.metricAnalysis(context.l10n.sleep),
            onTap: () => RingShell.openLight(
              context,
              HealthTrendPage(
                controller: controller,
                metric: HealthMetric.sleep,
              ),
              'ring-sleep-trend',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.healthDisclaimer,
            style: const TextStyle(color: RingShell._muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RingSportPage extends StatelessWidget {
  const _RingSportPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestByMetric;
    final modes = controller.availableSportModes;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('ring-sport'),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
        children: [
          _PageHeading(
            title: context.l10n.workouts,
            subtitle:
                controller.connectedDevice?.name ?? context.l10n.notConnected,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: RingShell._surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                _ProgressMetric(
                  metric: HealthMetric.steps,
                  record: latest[HealthMetric.steps],
                  target: controller.stepGoal,
                ),
                const SizedBox(height: 16),
                _ProgressMetric(
                  metric: HealthMetric.distance,
                  record: latest[HealthMetric.distance],
                  target: controller.distanceGoal,
                ),
                const SizedBox(height: 16),
                _ProgressMetric(
                  metric: HealthMetric.calories,
                  record: latest[HealthMetric.calories],
                  target: controller.calorieGoal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeading(title: context.l10n.workoutsAndRecords),
          const SizedBox(height: 10),
          if (modes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.l10n.workoutStartOnWatch,
                style: const TextStyle(color: RingShell._muted),
              ),
            )
          else
            for (final mode in modes)
              _ActionTile(
                icon: switch (mode) {
                  SportMode.cycling => Icons.directions_bike_rounded,
                  SportMode.walking => Icons.directions_walk_rounded,
                  SportMode.hiking ||
                  SportMode.mountaineering => Icons.hiking_rounded,
                  _ => Icons.directions_run_rounded,
                },
                title: context.l10n.sportModeName(mode),
                onTap: () => RingShell.openLight(
                  context,
                  SportSessionPage(controller: controller, mode: mode),
                  'ring-sport-${mode.name}',
                ),
              ),
          _ActionTile(
            icon: Icons.history_rounded,
            title: context.l10n.workoutRecords,
            onTap: () => RingShell.openLight(
              context,
              SportRecordsPage(controller: controller),
              'ring-sport-records',
            ),
          ),
          _ActionTile(
            icon: Icons.flag_outlined,
            title: context.l10n.goals,
            onTap: () => RingShell.openLight(
              context,
              GoalSettingsPage(controller: controller),
              'ring-goals',
            ),
          ),
        ],
      ),
    );
  }
}

class _RingMePage extends StatelessWidget {
  const _RingMePage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final name =
        '${controller.memberProfile['nickname'] ?? controller.session?.displayName ?? context.l10n.profile}';
    final avatar = '${controller.memberProfile['head_portrait'] ?? ''}'.trim();
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('ring-me'),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
        children: [
          _PageHeading(title: context.l10n.profile, subtitle: 'SAY RING'),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: RingShell._surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: avatar.isEmpty
                      ? const CircleAvatar(
                          radius: 30,
                          child: Icon(Icons.person_rounded, size: 32),
                        )
                      : SafeNetworkImage(
                          avatar,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const CircleAvatar(
                            radius: 30,
                            child: Icon(Icons.person_rounded, size: 32),
                          ),
                        ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.profile,
                  onPressed: () => RingShell.openLight(
                    context,
                    ProfileEditPage(controller: controller),
                    'ring-profile-edit',
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeading(title: context.l10n.device),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.circle_outlined,
            title:
                controller.connectedDevice?.name ?? context.l10n.addSmartDevice,
            subtitle: controller.connectedDevice == null
                ? context.l10n.notConnected
                : context.l10n.online,
            onTap: () => controller.selectTab(1),
          ),
          const SizedBox(height: 14),
          _SectionHeading(title: context.l10n.profile),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.family_restroom_rounded,
            title: context.l10n.remoteCare,
            onTap: () => RingShell.openLight(
              context,
              Scaffold(
                appBar: AppBar(title: Text(context.l10n.remoteCare)),
                body: CarePage(controller: controller),
              ),
              'ring-care',
            ),
          ),
          _ActionTile(
            icon: Icons.settings_outlined,
            title: context.l10n.settings,
            onTap: () => RingShell.openLight(
              context,
              Scaffold(
                appBar: AppBar(title: Text(context.l10n.settings)),
                body: SettingsPage(controller: controller),
              ),
              'ring-settings',
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(color: RingShell._muted, fontSize: 14),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: RingShell._surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 25, color: RingShell._accent),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: RingShell._muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: RingShell._muted),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.metric,
    required this.record,
    required this.target,
  });
  final HealthMetric metric;
  final HealthRecord? record;
  final num target;

  @override
  Widget build(BuildContext context) {
    final value = record?.values['value'];
    final progress = value == null || target <= 0
        ? 0.0
        : (value / target).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.metricName(metric),
                style: const TextStyle(color: RingShell._muted),
              ),
            ),
            Text(
              '${_metricValue(metric, record)} / ${target.toStringAsFixed(metric == HealthMetric.distance ? 1 : 0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFF3C414B),
            color: RingShell._accent,
          ),
        ),
      ],
    );
  }
}

String _metricValue(HealthMetric metric, HealthRecord? record) {
  final value = record?.values['value'];
  if (value == null || !value.isFinite) return '--';
  if (metric == HealthMetric.sleep || metric == HealthMetric.distance) {
    return '${value.toStringAsFixed(1)} ${metric.defaultUnit}';
  }
  return '${value.round()} ${metric.defaultUnit}';
}

String _recordDate(HealthRecord record) {
  final at = record.measuredAt.toLocal();
  return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
}
