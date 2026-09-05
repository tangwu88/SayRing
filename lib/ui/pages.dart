import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/feature_models.dart';
import '../domain/ecg_waveform.dart';
import '../domain/health_interpretation.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/device_watch_face_market_service.dart';
import '../services/notification_models.dart';
import 'app_theme.dart';
import 'brand_assets.dart';
import 'device_sdk_badge.dart';
import 'health_trend_page.dart';
import 'prototype_pages.dart';
import 'shop_pages.dart';
import 'watch_face_market_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _obscure = true;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_accepted) {
      widget.controller.clearError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意用户协议与隐私政策')));
      return;
    }
    await widget.controller.login(
      _account.text,
      _password.text,
      privacyConsentGranted: true,
    );
  }

  Future<void> _wechatLogin() async {
    if (widget.controller.isWechatLoginInProgress) {
      widget.controller.cancelWechatLogin();
      return;
    }
    if (!_accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先同意用户协议与隐私政策')));
      return;
    }
    FocusScope.of(context).unfocus();
    await widget.controller.loginWithWechat(privacyConsentGranted: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final media = MediaQuery.of(context);
    final compactLayout =
        media.size.height < 700 || media.viewInsets.bottom > 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: saydianSoftGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(26, compactLayout ? 28 : 96, 26, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 375),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    SizedBox(height: compactLayout ? 32 : 64),
                    TextField(
                      controller: _account,
                      enabled: !controller.isBusy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        hintText: '手机号 / 账号',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_iphone_outlined,
                          color: SaydianColors.muted,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      enabled: !controller.isBusy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: '密码',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: SaydianColors.muted,
                          size: 22,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: 'password-recovery',
                                  ),
                                  builder: (_) => PasswordRecoveryPage(
                                    controller: controller,
                                  ),
                                ),
                              ),
                        child: const Text('忘记密码？'),
                      ),
                    ),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineNotice(
                        message: controller.errorMessage!,
                        icon: Icons.error_outline,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(height: compactLayout ? 10 : 20),
                    _AgreementRow(
                      accepted: _accepted,
                      onChanged: (value) =>
                          setState(() => _accepted = value ?? false),
                      onOpenAgreement: _openAgreement,
                    ),
                    SizedBox(height: compactLayout ? 10 : 16),
                    FilledButton(
                      onPressed: controller.isBusy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          controller.isBusy &&
                              !controller.isWechatLoginInProgress
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('登录'),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: controller.isBusy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'registration',
                                ),
                                builder: (_) =>
                                    RegistrationPage(controller: controller),
                              ),
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: SaydianColors.ink,
                        minimumSize: const Size.fromHeight(38),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('注册账户'),
                    ),
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.iOS) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: OutlinedButton(
                            key: const Key('wechat-login'),
                            onPressed:
                                controller.isBusy &&
                                    !controller.canCancelWechatLogin
                                ? null
                                : _wechatLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF07883E),
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              controller.isWechatLoginInProgress
                                  ? controller.canCancelWechatLogin
                                        ? '取消微信登录'
                                        : '正在登录'
                                  : '微信授权登录',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ] else if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: controller.enterPreview,
                        icon: const CircleAvatar(
                          radius: 14,
                          backgroundColor: SaydianColors.green,
                          child: Icon(
                            Icons.visibility_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        label: const Text('快速体验'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAgreement({required int id, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(
          controller: widget.controller,
          article: {'id': id, 'title': title},
          singleArticle: true,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SaydianBrandLockup(width: 190));
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.accepted,
    required this.onChanged,
    required this.onOpenAgreement,
  });

  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final void Function({required int id, required String title}) onOpenAgreement;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: SaydianColors.blue,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 14),
    );
    return Row(
      key: const Key('login-agreement'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: accepted, onChanged: onChanged),
        const SizedBox(width: 2),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('我已阅读并同意', style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: () => onOpenAgreement(id: 2, title: '用户协议'),
                style: linkStyle,
                child: const Text('用户协议'),
              ),
              const Text('和', style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: () => onOpenAgreement(id: 3, title: '隐私政策'),
                style: linkStyle,
                child: const Text('隐私政策'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _titles = ['', '设备', '我的'];
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
          : AppBar(title: Text(_titles[selectedIndex]), actions: const []),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1EAE6))),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: controller.selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: '健康',
            ),
            NavigationDestination(
              icon: Icon(Icons.watch_outlined),
              selectedIcon: Icon(Icons.watch_rounded),
              label: '设备',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestByMetric;
    final disconnected = controller.connectedDevice == null;
    const supportedMetrics = [
      HealthMetric.bloodPressure,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodGlucose,
      HealthMetric.bodyTemperature,
      HealthMetric.ecg,
      HealthMetric.hrv,
      HealthMetric.bodyComposition,
      HealthMetric.bloodComposition,
      HealthMetric.sleep,
    ];
    final metrics = supportedMetrics
        .where(controller.shouldShowHealthMetric)
        .toList(growable: false);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
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
                  _AiHealthAssistantCard(controller: controller),
                  const SizedBox(height: 12),
                  _FeatureEntryGrid(
                    onCare: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('远程关爱')),
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
                    onWarning: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'health-warnings'),
                        builder: (_) =>
                            HealthWarningPage(controller: controller),
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
                  _SectionTitle(
                    title: '健康数据',
                    subtitle: DateFormat('M月d日').format(DateTime.now()),
                    actionLabel: '全部数据',
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
                    _InlineNotice(
                      key: const Key('dashboard-health-empty-notice'),
                      message: disconnected ? '连接手表后可查看支持的健康数据' : '暂无可显示的健康数据',
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: metrics.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 142 + (textScale - 1) * 160,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final metric = metrics[index];
                        return _MetricCard(
                          controller: controller,
                          metric: metric,
                          record: latest[metric],
                        );
                      },
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    '运动与记录',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  _SportEntryPanel(controller: controller),
                ]),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _InlineNotice(
                    key: Key('dashboard-health-notice'),
                    message: '测量结果仅供健康管理参考，如有不适请咨询专业医务人员。',
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
    final name = controller.session?.displayName ?? '赛电用户';
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const SaydianBrandMark(size: 46),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你好，$name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '今天也要保持好状态',
                style: TextStyle(color: SaydianColors.muted, fontSize: 13),
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
          backgroundColor: Color(0xFFD70B25),
          child: IconButton(
            tooltip: controller.notificationUnreadCount > 0
                ? '消息，${controller.notificationUnreadCount} 条未读'
                : '消息',
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
                'assets/branding/ai-health-manager-doctor.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              )
            : Transform.scale(
                scale: 1.28,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(18, 0),
                  child: Image.asset(
                    'assets/branding/ai-health-manager-doctor.png',
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
          const Text(
            'AI健康管家',
            style: TextStyle(
              color: Color(0xFF9E1025),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            '我是您的健康管家，\n有任何健康问题都可以向我提问。',
            style: TextStyle(
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
              backgroundColor: const Color(0xFFD20B27),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              '马上提问',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('dashboard-ai-assistant'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F3),
        borderRadius: BorderRadius.circular(20),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: const Color(0x66D20B27), width: 1.2),
        borderRadius: BorderRadius.circular(20),
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

// Retained for the full activity-goal page; intentionally hidden on the home.
// ignore: unused_element
class _TodayHealthOverview extends StatelessWidget {
  const _TodayHealthOverview({
    required this.latest,
    required this.stepTarget,
    required this.distanceTarget,
    required this.calorieTarget,
    required this.onSetGoal,
  });

  final Map<HealthMetric, HealthRecord> latest;
  final double stepTarget;
  final double distanceTarget;
  final double calorieTarget;
  final VoidCallback onSetGoal;

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
                colors: [Color(0xFFE8F7ED), Color(0xFFF3F8E8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日健康',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '坚持完成每日活动目标',
                          style: TextStyle(
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
                    label: const Text('目标'),
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
                  record: latest[HealthMetric.steps],
                  target: stepTarget,
                  color: const Color(0xFF80BAF5),
                ),
                const SizedBox(height: 16),
                _GoalProgressRow(
                  metric: HealthMetric.distance,
                  record: latest[HealthMetric.distance],
                  target: distanceTarget,
                  color: const Color(0xFF6CDE53),
                ),
                const SizedBox(height: 16),
                _GoalProgressRow(
                  metric: HealthMetric.calories,
                  record: latest[HealthMetric.calories],
                  target: calorieTarget,
                  color: const Color(0xFFFF9949),
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
    required this.record,
    required this.target,
    required this.color,
  });

  final HealthMetric metric;
  final HealthRecord? record;
  final double target;
  final Color color;

  num? get _value {
    if (record == null || record!.values.isEmpty) return null;
    return record!.values['value'] ?? record!.values.values.first;
  }

  String _format(num value) {
    if (metric == HealthMetric.distance) return value.toStringAsFixed(2);
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final progress = value == null
        ? 0.0
        : (value.toDouble() / target).clamp(0.0, 1.0).toDouble();
    final unit = switch (metric) {
      HealthMetric.distance => '公里',
      HealthMetric.calories => '千卡',
      _ => metric.defaultUnit,
    };
    final currentText = value == null ? '--' : _format(value);
    final targetText = _format(target);

    return Row(
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
            metric.label,
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
    );
  }
}

class _FeatureEntryGrid extends StatelessWidget {
  const _FeatureEntryGrid({
    required this.onCare,
    required this.onEncyclopedia,
    required this.onWarning,
    required this.onMall,
  });

  final VoidCallback onCare;
  final VoidCallback onEncyclopedia;
  final VoidCallback onWarning;
  final VoidCallback onMall;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('dashboard-functions'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _FeatureEntry(
                label: '远程关爱',
                icon: Icons.family_restroom_rounded,
                color: const Color(0xFFE84358),
                onTap: onCare,
              ),
            ),
            Expanded(
              child: _FeatureEntry(
                label: '健康百科',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFD5A03D),
                onTap: onEncyclopedia,
              ),
            ),
            Expanded(
              child: _FeatureEntry(
                label: '健康预警',
                icon: Icons.health_and_safety_rounded,
                color: const Color(0xFFEF6E78),
                onTap: onWarning,
              ),
            ),
            Expanded(
              child: _FeatureEntry(
                label: '赛电商城',
                icon: Icons.shopping_bag_rounded,
                color: const Color(0xFFD99C2B),
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.92),
                    color.withValues(alpha: 0.68),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
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
                        device?.name ?? '尚未连接手表',
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
                      : '${device.model ?? '赛电设备'} · ${controller.syncStatus}',
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.controller,
    required this.metric,
    required this.record,
  });

  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;

  @override
  Widget build(BuildContext context) {
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
      HealthMetric.bodyComposition => Icons.accessibility_new_rounded,
      HealthMetric.bloodComposition => Icons.science_outlined,
      _ => Icons.monitor_heart_outlined,
    };
    const iconColor = Color(0xFFE52E45);
    const chartColor = Color(0xFF4F89F7);
    final status = _homeMetricStatus(controller, record);
    final needsAttention = !{'正常', '已记录', '暂无数据'}.contains(status);
    final supportsManualMeasurement =
        controller.canMeasureHealthMetric(metric) &&
        const {
          HealthMetric.bloodPressure,
          HealthMetric.heartRate,
          HealthMetric.bloodOxygen,
          HealthMetric.bloodGlucose,
          HealthMetric.bodyTemperature,
          HealthMetric.ecg,
          HealthMetric.hrv,
          HealthMetric.bodyComposition,
          HealthMetric.bloodComposition,
        }.contains(metric);
    return GestureDetector(
      key: ValueKey('health-metric-${metric.name}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HealthTrendPage(
            controller: controller,
            metric: metric,
            onMeasure: supportsManualMeasurement
                ? () =>
                      _showHealthMeasurementDialog(context, controller, metric)
                : null,
          ),
        ),
      ),
      child: Card(
        elevation: 2,
        shadowColor: const Color(0x1A6B4C42),
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      metric.label,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: record == null
                          ? const Color(0xFFF2EFED)
                          : needsAttention
                          ? const Color(0xFFFFE7E5)
                          : const Color(0xFFE7F7E6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: record == null
                            ? SaydianColors.muted
                            : needsAttention
                            ? const Color(0xFFC62828)
                            : const Color(0xFF27852A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _healthDisplayValue(record, controller),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _healthDisplayUnit(metric, record, controller),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(color: SaydianColors.muted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              HealthMetricMiniChart(
                controller: controller,
                metric: metric,
                color: chartColor,
                showEmptyLabel: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _homeMetricStatus(AppController controller, HealthRecord? record) {
  if (record == null) return '暂无数据';
  final quality = record.quality.toLowerCase();
  if (quality.contains('poor') ||
      quality.contains('warning') ||
      quality.contains('abnormal')) {
    return '请关注';
  }
  final primary = record.values['value'];
  if (record.metric == HealthMetric.heartRate &&
      primary != null &&
      (primary < 60 || primary > 100)) {
    return '超出参考范围';
  }
  if (record.metric == HealthMetric.bloodOxygen &&
      primary != null &&
      primary < 95) {
    return '偏低';
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      primary != null &&
      (primary < 36 || primary > 37.3)) {
    return primary > 37.3 ? '偏高' : '偏低';
  }
  if (record.metric == HealthMetric.bloodPressure) {
    final systolic = record.values['systolic'];
    final diastolic = record.values['diastolic'];
    if (systolic != null && diastolic != null) {
      if (systolic >= 140 || diastolic >= 90) return '偏高';
      if (systolic < 90 || diastolic < 60) return '偏低';
    }
  }
  if (record.metric == HealthMetric.ecg) {
    return (record.values['deviceAbnormalFlags'] ?? 0) > 0 ? '请关注' : '已记录';
  }
  if (record.metric == HealthMetric.hrv) return '已记录';
  final settings = controller.healthWarningSettings;
  if (record.metric == HealthMetric.heartRate && settings.heartRateEnabled) {
    final value = record.values['value'];
    if (value != null && value > settings.heartRateUpper) return '请关注';
  }
  if (record.metric == HealthMetric.bloodPressure &&
      settings.bloodPressureEnabled) {
    final systolic = record.values['systolic'];
    final diastolic = record.values['diastolic'];
    if ((systolic != null && systolic > settings.systolicUpper) ||
        (diastolic != null && diastolic > settings.diastolicUpper)) {
      return '请关注';
    }
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      settings.temperatureEnabled) {
    final value = record.values['value'];
    if (value != null && value > settings.temperatureUpper) return '请关注';
  }
  return '正常';
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
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final heading = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 19,
              color: SaydianColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              subtitle,
              style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
            ),
          ],
        ),
      ],
    );
    final action = TextButton.icon(
      onPressed: onAction,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded, size: 21),
      label: Text(
        actionLabel,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (enlargedText) {
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

class HealthPage extends StatelessWidget {
  const HealthPage({required this.controller, super.key});

  final AppController controller;

  static const coreMetrics = [
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
    HealthMetric.bloodPressure,
    HealthMetric.bloodGlucose,
    HealthMetric.bodyTemperature,
    HealthMetric.ecg,
    HealthMetric.hrv,
    HealthMetric.bodyComposition,
    HealthMetric.bloodComposition,
    HealthMetric.sleep,
  ];

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestByMetric;
    final visibleMetrics = coreMetrics
        .where(controller.shouldShowHealthMetric)
        .toList(growable: false);
    final calibrationMetrics = <HealthMetric>[
      if (controller.canMeasureHealthMetric(HealthMetric.bloodPressure))
        HealthMetric.bloodPressure,
      if (controller.canMeasureHealthMetric(HealthMetric.bloodGlucose))
        HealthMetric.bloodGlucose,
    ];
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          controller.synchronizeCloud(),
          controller.refreshSportRecords(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SaydianColors.ink,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '健康数据总览',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '点击指标查看详情与历史趋势',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.monitor_heart_outlined,
                    color: SaydianColors.green,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (visibleMetrics.isEmpty) ...[
            _InlineNotice(
              message: controller.connectedDevice == null
                  ? '连接手表后可查看支持的健康数据'
                  : '暂无可显示的健康数据',
              icon: Icons.watch_outlined,
              color: SaydianColors.blue,
              compact: true,
            ),
            const SizedBox(height: 10),
          ],
          for (final metric in visibleMetrics) ...[
            _HealthRow(
              controller: controller,
              metric: metric,
              record: latest[metric],
              supported: controller.capabilities?.supports(metric),
              connected: controller.connectedDevice != null,
            ),
            const SizedBox(height: 10),
          ],
          if (calibrationMetrics.isNotEmpty) ...[
            const SizedBox(height: 4),
            Card(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < calibrationMetrics.length;
                    index++
                  ) ...[
                    if (index > 0) const Divider(indent: 56),
                    ListTile(
                      onTap: () {
                        final metric = calibrationMetrics[index];
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings: RouteSettings(
                              name: metric == HealthMetric.bloodPressure
                                  ? 'bp-calibration'
                                  : 'glucose-calibration',
                            ),
                            builder: (_) => HealthCalibrationPage(
                              controller: controller,
                              metric: metric,
                            ),
                          ),
                        );
                      },
                      leading: const Icon(Icons.tune_rounded),
                      title: Text(
                        '${calibrationMetrics[index] == HealthMetric.bloodPressure ? '血压' : '血糖'}校准',
                      ),
                      subtitle: const Text('根据手表提示完成校准'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AllHealthDataPage extends StatelessWidget {
  const AllHealthDataPage({
    required this.controller,
    this.title = '全部健康数据',
    super.key,
  });

  final AppController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HealthPage(controller: controller),
      ),
    );
  }
}

Future<void> _showHealthMeasurementDialog(
  BuildContext context,
  AppController controller,
  HealthMetric metric,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _HealthMeasurementDialog(controller: controller, metric: metric),
);

class _HealthMeasurementDialog extends StatefulWidget {
  const _HealthMeasurementDialog({
    required this.controller,
    required this.metric,
  });

  final AppController controller;
  final HealthMetric metric;

  @override
  State<_HealthMeasurementDialog> createState() =>
      _HealthMeasurementDialogState();
}

class _HealthMeasurementDialogState extends State<_HealthMeasurementDialog> {
  late final DateTime _startedAt = DateTime.now();
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.startMeasurement(widget.metric));
  }

  Future<void> _finish() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    final record = widget.controller.latestByMetric[widget.metric];
    final completed = record != null && record.measuredAt.isAfter(_startedAt);
    if (completed) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // A few vendor firmwares do not acknowledge a stop command promptly.
    // Close the dialog first so the user never gets trapped on a spinner;
    // AppController still performs the bounded stop in the background.
    if (mounted) Navigator.of(context).pop();
    await widget.controller.stopMeasurement(widget.metric);
  }

  Future<void> _retry() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await widget.controller.stopMeasurement(widget.metric);
    if (!mounted) return;
    setState(() => _stopping = false);
    await widget.controller.startMeasurement(widget.metric);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final record = widget.controller.latestByMetric[widget.metric];
          final isNew = record != null && record.measuredAt.isAfter(_startedAt);
          final failure = widget.controller.measurementErrorMessage;
          final failed = !isNew && failure != null;
          final waitingMessage = !widget.controller.measurementWearConfirmed
              ? switch (widget.metric) {
                  HealthMetric.ecg => '未检测到电极接触，请正确佩戴手表并将手指持续贴在心电电极上',
                  HealthMetric.bodyComposition ||
                  HealthMetric.bloodComposition => '未检测到正确接触，请佩戴手表并按手表提示接触电极',
                  _ => '未检测到正确佩戴，请将手表贴合手腕后继续测量',
                }
              : switch (widget.metric) {
                  HealthMetric.bloodPressure => '正在测量血压，请保持手表贴合手腕、手臂静止并等待结果',
                  HealthMetric.ecg => '请正确佩戴手表，并将手指持续贴在心电电极上',
                  HealthMetric.hrv => '请将手表贴合手腕并保持静止，等待 HRV 测量结果',
                  HealthMetric.bodyComposition ||
                  HealthMetric.bloodComposition => '请按手表提示保持正确接触，测量完成前不要移动',
                  _ => '请保持正确佩戴并静止，等待手表返回结果',
                };
          return AlertDialog(
            title: Text('${widget.metric.label}测量'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNew
                      ? Icons.check_circle_rounded
                      : failed
                      ? Icons.error_outline_rounded
                      : Icons.monitor_heart_rounded,
                  color: isNew
                      ? SaydianColors.green
                      : failed
                      ? SaydianColors.danger
                      : SaydianColors.pink,
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  isNew
                      ? '${_healthDisplayValue(record, widget.controller)} ${_healthDisplayUnit(widget.metric, record, widget.controller)}'
                      : failed
                      ? failure
                      : waitingMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isNew ? 24 : 16,
                    fontWeight: isNew ? FontWeight.w900 : FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                if (isNew) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final interpretation = interpretHealthRecord(record);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SaydianColors.brandRedSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              interpretation.title,
                              style: const TextStyle(
                                color: SaydianColors.brandRedDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              interpretation.detail,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (!isNew &&
                    !failed &&
                    widget.metric == HealthMetric.ecg &&
                    widget.controller.measurementSamples.length > 1) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 160,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF08090B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: _LiveEcgPainter(
                        widget.controller.measurementSamples,
                        sampleFrequency:
                            widget.controller.measurementSampleFrequency,
                      ),
                    ),
                  ),
                ],
                if (!isNew && !failed) ...[
                  if (widget.metric == HealthMetric.bloodPressure) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SaydianColors.brandGoldSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '本次仅为静态监测，结果仅供参考，如需更加准确的数据，请通过手表气泵气囊式检测',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: widget.controller.measurementProgress > 0
                        ? widget.controller.measurementProgress / 100
                        : null,
                  ),
                  if (widget.controller.measurementProgress > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '测量进度 ${widget.controller.measurementProgress}%',
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              if (failed)
                FilledButton(
                  onPressed: _stopping ? null : _retry,
                  child: const Text('重新测量'),
                ),
              TextButton(
                onPressed: _stopping ? null : _finish,
                child: Text(_stopping ? '正在停止' : (failed ? '关闭' : '结束测量')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SportEntryPanel extends StatelessWidget {
  const _SportEntryPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('health-sport-entries'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x18D20B27)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Visibility(
            visible: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: SaydianColors.brandRedSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: SaydianColors.brandRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '开始今日运动',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '选择运动类型，连接手表后同步记录',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final enlarged =
                        MediaQuery.textScalerOf(context).scale(1) > 1.25;
                    final columns = enlarged ? 2 : 4;
                    final width = constraints.maxWidth / columns;
                    final modes = controller.availableSportModes;
                    if (modes.isEmpty) {
                      return const _InlineNotice(
                        message: '当前手表未开放由 APP 启动的运动模式，请直接在手表上开始运动。',
                        icon: Icons.watch_rounded,
                        color: SaydianColors.orange,
                      );
                    }
                    return Wrap(
                      children: [
                        for (final mode in modes)
                          SizedBox(
                            width: width,
                            child: _SportEntry(
                              mode: mode,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SportSessionPage(
                                    controller: controller,
                                    mode: mode,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Material(
            color: SaydianColors.brandRedSoft,
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SportRecordsPage(controller: controller),
                ),
              ),
              leading: const _SettingsIcon(
                icon: Icons.history_rounded,
                color: SaydianColors.brandRed,
              ),
              title: const Text(
                '运动记录',
                style: TextStyle(
                  color: SaydianColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                controller.connectedDevice == null
                    ? '连接手表后读取运动记录'
                    : '已读取 ${controller.sportRecords.length} 条记录',
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: SaydianColors.brandRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SportEntry extends StatelessWidget {
  const _SportEntry({required this.mode, required this.onTap});

  final SportMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      SportMode.running => Icons.directions_run_rounded,
      SportMode.walking => Icons.directions_walk_rounded,
      SportMode.cycling => Icons.directions_bike_rounded,
      SportMode.hiking => Icons.hiking_rounded,
      SportMode.mountaineering => Icons.landscape_rounded,
    };
    final color = switch (mode) {
      SportMode.running => SaydianColors.brandRed,
      SportMode.walking => SaydianColors.brandGoldDark,
      SportMode.cycling => const Color(0xFF9E2435),
      SportMode.hiking => const Color(0xFF8A6432),
      SportMode.mountaineering => const Color(0xFF64543A),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class SportSessionPage extends StatefulWidget {
  const SportSessionPage({
    required this.controller,
    required this.mode,
    super.key,
  });

  final AppController controller;
  final SportMode mode;

  @override
  State<SportSessionPage> createState() => _SportSessionPageState();
}

class _SportSessionPageState extends State<SportSessionPage> {
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  int _elapsedSeconds = 0;
  DateTime? _startedAt;
  final List<SportRoutePoint> _routePoints = [];
  double _routeDistanceKm = 0;
  String _locationStatus = '开始后可记录前台户外轨迹';
  bool _allowPop = false;
  bool _finalizingSport = false;
  int _trackingGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (_startedAt != null &&
        widget.controller.activeSport != widget.mode &&
        !_finalizingSport) {
      _finalizingSport = true;
      unawaited(_finalizeSport(requestDeviceStop: false));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _toggleSport() async {
    if (widget.controller.activeSport == widget.mode) {
      await _stopAndSaveSport();
      return;
    }
    if (widget.controller.activeSport != null) return;
    final started = await widget.controller.startSport(widget.mode);
    if (!started || !mounted) return;
    _timer?.cancel();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _routePoints.clear();
    _routeDistanceKm = 0;
    _locationStatus = '正在准备前台户外轨迹';
    final trackingGeneration = ++_trackingGeneration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.controller.activeSport == widget.mode &&
          !widget.controller.sportPaused) {
        setState(() => _elapsedSeconds += 1);
      }
    });
    setState(() {});
    unawaited(_startLocationTracking(trackingGeneration));
  }

  Future<void> _stopAndSaveSport() async {
    if (_finalizingSport) return;
    _finalizingSport = true;
    await _finalizeSport(requestDeviceStop: true);
  }

  Future<void> _finalizeSport({required bool requestDeviceStop}) async {
    final startedAt = _startedAt;
    final previousLocationStatus = _locationStatus;
    var recordSaved = false;
    if (mounted) {
      setState(() {
        _locationStatus = requestDeviceStop ? '正在结束运动并保存记录' : '手表已结束运动，正在保存记录';
      });
    }
    try {
      if (requestDeviceStop) {
        await widget.controller.stopSport();
        if (widget.controller.activeSport == widget.mode) {
          _locationStatus = previousLocationStatus;
          return;
        }
      }

      _timer?.cancel();
      _timer = null;
      _trackingGeneration++;
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      final watchData = Map<String, num>.from(widget.controller.liveSportData);
      final watchDuration = (watchData['durationSeconds'] ?? 0).toInt();
      final watchDistanceMeters = (watchData['distanceMeters'] ?? 0).toDouble();
      final durationSeconds = watchDuration > 0
          ? watchDuration
          : _elapsedSeconds;
      if (startedAt != null && durationSeconds > 0) {
        await widget.controller.saveLocalSportRecord(
          SportRecord(
            id: 'local:${startedAt.toUtc().toIso8601String()}',
            mode: widget.mode,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            distanceKm: watchDistanceMeters > 0
                ? watchDistanceMeters / 1000
                : _routeDistanceKm,
            calories: (watchData['calories'] ?? 0).toDouble(),
            steps: (watchData['steps'] ?? 0).toInt(),
            heartRate: (watchData['heartRate'] ?? 0).toInt(),
            routePoints: List.unmodifiable(_routePoints),
          ),
        );
        recordSaved = true;
        _elapsedSeconds = durationSeconds;
      }
      _startedAt = null;
      _locationStatus = recordSaved
          ? requestDeviceStop
                ? '本次运动已结束，记录已保存'
                : '手表已结束本次运动，记录已保存'
          : '本次运动已结束';
    } finally {
      _finalizingSport = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _togglePause() async {
    await widget.controller.setSportPaused(!widget.controller.sportPaused);
  }

  Future<void> _confirmExit() async {
    if (widget.controller.activeSport != widget.mode) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束当前运动？'),
        content: const Text('离开前将先停止手表运动，并保存已记录的运动时长和轨迹。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续运动'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('结束并离开'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _stopAndSaveSport();
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  bool _isCurrentTrackingGeneration(int generation) =>
      mounted && generation == _trackingGeneration && _startedAt != null;

  Future<void> _startLocationTracking(int generation) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (_isCurrentTrackingGeneration(generation)) {
        setState(() => _locationStatus = '定位服务未开启，仍会记录手表运动数据');
      }
      return;
    }
    if (!_isCurrentTrackingGeneration(generation)) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!_isCurrentTrackingGeneration(generation)) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus = '未允许位置权限，仍会记录手表运动数据');
      return;
    }
    setState(() => _locationStatus = '正在记录前台户外轨迹');
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) {
            if (position.accuracy > 80 ||
                !_isCurrentTrackingGeneration(generation)) {
              return;
            }
            final point = SportRoutePoint(
              latitude: position.latitude,
              longitude: position.longitude,
              recordedAt: position.timestamp,
              accuracy: position.accuracy,
            );
            if (_routePoints.isNotEmpty) {
              final previous = _routePoints.last;
              final meters = Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                point.latitude,
                point.longitude,
              );
              if (meters < 500) _routeDistanceKm += meters / 1000;
            }
            setState(() => _routePoints.add(point));
          },
          onError: (_) {
            if (_isCurrentTrackingGeneration(generation)) {
              setState(() => _locationStatus = '轨迹读取中断，手表运动仍在继续');
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.activeSport == widget.mode;
    final anotherSportActive = widget.controller.activeSport != null && !active;
    final paused = active && widget.controller.sportPaused;
    final liveData = widget.controller.liveSportData;
    final watchDistanceKm = (liveData['distanceMeters'] ?? 0).toDouble() / 1000;
    final duration = Duration(seconds: _elapsedSeconds);
    final time = [
      duration.inHours,
      duration.inMinutes.remainder(60),
      duration.inSeconds.remainder(60),
    ].map((value) => value.toString().padLeft(2, '0')).join(':');
    return PopScope(
      canPop: _allowPop || !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && active) unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.mode.label)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D3B6F), Color(0xFF385D9C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Icon(
                    active ? Icons.directions_run_rounded : Icons.route_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    active
                        ? (paused
                              ? '${widget.mode.label}已暂停'
                              : '${widget.mode.label}进行中')
                        : '准备开始${widget.mode.label}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (active && liveData.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SportLiveMetric(
                    label: '手表距离',
                    value: '${watchDistanceKm.toStringAsFixed(2)} km',
                  ),
                  _SportLiveMetric(
                    label: '手表步数',
                    value: '${(liveData['steps'] ?? 0).toInt()} 步',
                  ),
                  _SportLiveMetric(
                    label: '实时心率',
                    value: '${(liveData['heartRate'] ?? 0).toInt()} bpm',
                  ),
                  _SportLiveMetric(
                    label: '手表热量',
                    value:
                        '${(liveData['calories'] ?? 0).toDouble().toStringAsFixed(1)} kcal',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _InlineNotice(
              message: widget.controller.connectedDevice == null
                  ? '请先在设备页连接手表，运动模式将由手表记录。'
                  : '已连接 ${widget.controller.connectedDevice!.name}。$_locationStatus',
              icon: Icons.watch_rounded,
              color: SaydianColors.blue,
            ),
            if (_routePoints.isNotEmpty) ...[
              const SizedBox(height: 14),
              SportRoutePreview(
                points: _routePoints,
                distanceKm: _routeDistanceKm,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Row(
            children: [
              if (active &&
                  widget.controller.capabilities?.supportsSportPause ==
                      true) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sport-session-pause'),
                    onPressed: _togglePause,
                    icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    label: Text(paused ? '继续运动' : '暂停运动'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('sport-session-toggle'),
                    onPressed:
                        widget.controller.connectedDevice == null ||
                            anotherSportActive ||
                            _finalizingSport
                        ? null
                        : _toggleSport,
                    style: FilledButton.styleFrom(
                      backgroundColor: active ? Colors.red : SaydianColors.ink,
                    ),
                    icon: Icon(
                      _finalizingSport
                          ? Icons.hourglass_top_rounded
                          : active
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _finalizingSport
                          ? '正在保存'
                          : anotherSportActive
                          ? '请先结束${widget.controller.activeSport!.label}'
                          : active
                          ? '结束运动'
                          : '开始${widget.mode.label}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportLiveMetric extends StatelessWidget {
  const _SportLiveMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 50) / 2,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7FC),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: SaydianColors.muted)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class SportRecordsPage extends StatefulWidget {
  const SportRecordsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<SportRecordsPage> createState() => _SportRecordsPageState();
}

class _SportRecordsPageState extends State<SportRecordsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshSportRecords());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('运动记录')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final records = widget.controller.sportRecords;
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.controller.connectedDevice == null
                      ? '请先连接手表后读取运动记录'
                      : '手表中暂无运动记录',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SaydianColors.muted),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refreshSportRecords,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _SportRecordTile(
                controller: widget.controller,
                record: records[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SportRecordTile extends StatelessWidget {
  const _SportRecordTile({required this.controller, required this.record});

  final AppController controller;
  final SportRecord record;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: record.durationSeconds);
    final durationText = duration.inHours > 0
        ? '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟'
        : duration.inMinutes > 0
        ? '${duration.inMinutes}分钟${duration.inSeconds.remainder(60) > 0 ? '${duration.inSeconds.remainder(60)}秒' : ''}'
        : '${duration.inSeconds}秒';
    final usesMiles = controller.distanceUnit == '英里';
    final distance = usesMiles
        ? record.distanceKm * 0.621371
        : record.distanceKm;
    final distanceUnit = usesMiles ? '英里' : '公里';
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SportRecordDetailPage(controller: controller, record: record),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F1FF),
          foregroundColor: Color(0xFF1D3B6F),
          child: Icon(Icons.route_rounded),
        ),
        title: Text(
          record.mode.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${distance.toStringAsFixed(2)} $distanceUnit · '
          '${record.calories.toStringAsFixed(1)} 千卡 · $durationText',
        ),
        trailing: Text(
          record.startedAt == null
              ? '--'
              : DateFormat('MM/dd').format(record.startedAt!.toLocal()),
          style: const TextStyle(color: SaydianColors.muted),
        ),
      ),
    );
  }
}

class SportRecordDetailPage extends StatelessWidget {
  const SportRecordDetailPage({
    required this.controller,
    required this.record,
    super.key,
  });

  final AppController controller;
  final SportRecord record;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: record.durationSeconds);
    final distance = controller.distanceUnit == '英里'
        ? record.distanceKm * 0.621371
        : record.distanceKm;
    final unit = controller.distanceUnit == '英里' ? '英里' : '公里';
    return Scaffold(
      appBar: AppBar(title: Text('${record.mode.label}详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (record.routePoints.length >= 2)
            SportRoutePreview(
              points: record.routePoints,
              distanceKm: record.distanceKm,
            )
          else
            const _InlineNotice(
              message: '该记录没有手机前台轨迹，仍保留手表运动数据。',
              icon: Icons.route_outlined,
              color: SaydianColors.orange,
            ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('运动时长'),
                  trailing: Text(
                    '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                  ),
                ),
                const Divider(indent: 16),
                ListTile(
                  title: const Text('距离'),
                  trailing: Text('${distance.toStringAsFixed(2)} $unit'),
                ),
                if (record.calories > 0) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: const Text('热量'),
                    trailing: Text('${record.calories.toStringAsFixed(1)} 千卡'),
                  ),
                ],
                if (record.steps > 0) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: const Text('步数'),
                    trailing: Text('${record.steps} 步'),
                  ),
                ],
                if (record.heartRate > 0) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: const Text('手表心率'),
                    trailing: Text('${record.heartRate} bpm'),
                  ),
                ],
                if (record.startedAt != null) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: const Text('开始时间'),
                    trailing: Text(
                      DateFormat(
                        'yyyy-MM-dd HH:mm',
                      ).format(record.startedAt!.toLocal()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SportRoutePreview extends StatelessWidget {
  const SportRoutePreview({
    required this.points,
    required this.distanceKm,
    super.key,
  });

  final List<SportRoutePoint> points;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: CustomPaint(
              painter: _RoutePainter(points),
              child: const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Text(
              '${points.length} 个定位点 · ${distanceKm.toStringAsFixed(2)} 公里\n地图暂不可用，已保留本次运动轨迹',
              style: const TextStyle(
                color: SaydianColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.points);

  final List<SportRoutePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF0F4F3),
    );
    if (points.length < 2) return;
    final minLat = points.map((point) => point.latitude).reduce(math.min);
    final maxLat = points.map((point) => point.latitude).reduce(math.max);
    final minLng = points.map((point) => point.longitude).reduce(math.min);
    final maxLng = points.map((point) => point.longitude).reduce(math.max);
    final latSpan = math.max(maxLat - minLat, 0.00001);
    final lngSpan = math.max(maxLng - minLng, 0.00001);
    const padding = 24.0;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x =
          padding +
          (point.longitude - minLng) / lngSpan * (size.width - padding * 2);
      final y =
          size.height -
          padding -
          (point.latitude - minLat) / latSpan * (size.height - padding * 2);
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = SaydianColors.blue
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}

String _healthDisplayValue(HealthRecord? record, AppController controller) {
  if (record == null) return '--';
  final value =
      record.values['value'] ??
      (record.values.isEmpty ? null : record.values.values.first);
  if (value == null) return record.displayValue;
  if (record.metric == HealthMetric.distance &&
      controller.distanceUnit == '英里') {
    return (value * 0.621371).toStringAsFixed(2);
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      controller.temperatureUnit == '华氏度（℉）') {
    return (value * 9 / 5 + 32).toStringAsFixed(1);
  }
  return record.displayValue;
}

String _healthDisplayUnit(
  HealthMetric metric,
  HealthRecord? record,
  AppController controller,
) {
  if (metric == HealthMetric.distance && controller.distanceUnit == '英里') {
    return 'mi';
  }
  if (metric == HealthMetric.bodyTemperature &&
      controller.temperatureUnit == '华氏度（℉）') {
    return '℉';
  }
  return record?.unit ?? metric.defaultUnit;
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.controller,
    required this.metric,
    required this.record,
    required this.supported,
    required this.connected,
  });

  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;
  final bool? supported;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final status = record != null
        ? '最近 ${DateFormat('MM-dd HH:mm').format(record!.measuredAt.toLocal())}'
        : !connected
        ? '连接手表后使用'
        : supported == false
        ? '请在手表上操作'
        : '暂无测量记录';
    final icon = switch (metric) {
      HealthMetric.heartRate => Icons.favorite_rounded,
      HealthMetric.bloodOxygen => Icons.water_drop_rounded,
      HealthMetric.bloodPressure => Icons.speed_rounded,
      HealthMetric.bloodGlucose => Icons.water_drop_outlined,
      HealthMetric.bodyTemperature => Icons.thermostat_rounded,
      HealthMetric.ecg => Icons.monitor_heart_outlined,
      HealthMetric.hrv => Icons.show_chart_rounded,
      HealthMetric.bodyComposition => Icons.accessibility_new_rounded,
      HealthMetric.bloodComposition => Icons.bloodtype_outlined,
      HealthMetric.steps => Icons.directions_walk_rounded,
      HealthMetric.distance => Icons.location_on_rounded,
      HealthMetric.calories => Icons.local_fire_department_rounded,
      HealthMetric.sleep => Icons.bedtime_rounded,
    };
    final color = switch (metric) {
      HealthMetric.heartRate => SaydianColors.pink,
      HealthMetric.bloodOxygen => SaydianColors.blue,
      HealthMetric.bloodPressure => SaydianColors.orange,
      HealthMetric.bloodGlucose => SaydianColors.green,
      HealthMetric.bodyTemperature => SaydianColors.cyan,
      HealthMetric.ecg => const Color(0xFF6E8DF5),
      HealthMetric.hrv => const Color(0xFF8C7CF0),
      HealthMetric.bodyComposition => SaydianColors.cyan,
      HealthMetric.bloodComposition => SaydianColors.pink,
      HealthMetric.sleep => const Color(0xFF8C7CF0),
      _ => SaydianColors.green,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                HealthHistoryPage(controller: controller, metric: metric),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      maxLines: 2,
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _healthDisplayValue(record, controller),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _healthDisplayUnit(metric, record, controller),
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthHistoryPage extends StatelessWidget {
  const HealthHistoryPage({
    required this.controller,
    required this.metric,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;

  @override
  Widget build(BuildContext context) {
    final canMeasure =
        controller.canMeasureHealthMetric(metric) &&
        const {
          HealthMetric.heartRate,
          HealthMetric.bloodOxygen,
          HealthMetric.bloodPressure,
          HealthMetric.bloodGlucose,
          HealthMetric.bodyTemperature,
          HealthMetric.ecg,
          HealthMetric.hrv,
          HealthMetric.bodyComposition,
          HealthMetric.bloodComposition,
        }.contains(metric);
    return HealthTrendPage(
      controller: controller,
      metric: metric,
      onMeasure: canMeasure
          ? () => _showHealthMeasurementDialog(context, controller, metric)
          : null,
    );
  }
}

class _LiveEcgPainter extends CustomPainter {
  const _LiveEcgPainter(this.samples, {required this.sampleFrequency});

  final List<num> samples;
  final int sampleFrequency;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08090B),
    );
    // Match the watch's black-grid live view while retaining medical-paper
    // timing (25 mm/s) and voltage (10 mm/mV). This path intentionally uses
    // the calibrated ADC samples directly: history denoising would deform a
    // short, still-growing live window.
    // Match HBandSDK's EcgHeartRealthView: 16 major vertical squares, each
    // split into five minor squares. The previous 32-row grid magnified the
    // same calibrated mV samples by 2.5x and clipped W9S traces to the rails.
    final smallGrid = liveEcgMinorGridSize(size.height);
    final thinGrid = Paint()
      ..color = const Color(0x334B1B22)
      ..strokeWidth = .7;
    final boldGrid = Paint()
      ..color = const Color(0x665F202A)
      ..strokeWidth = 1;
    for (var index = 0, x = 0.0; x <= size.width; index++, x += smallGrid) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 5 == 0 ? boldGrid : thinGrid,
      );
    }
    for (var index = 0, y = 0.0; y <= size.height; index++, y += smallGrid) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 5 == 0 ? boldGrid : thinGrid,
      );
    }
    final frequency = sampleFrequency.clamp(50, 1000);
    final xStep = smallGrid * 25 / frequency;
    final capacity = math.max(2, (size.width / xStep).ceil() + 1);
    final visible = samples.length > capacity
        ? samples.sublist(samples.length - capacity)
        : samples;
    if (visible.length < 2) return;
    final displaySamples = prepareLiveEcgTrace(
      visible,
      sampleFrequency: frequency,
    );
    final baseline = size.height * .58;
    final path = Path();
    final firstX = size.width - (displaySamples.length - 1) * xStep;
    var drawing = false;
    for (var index = 0; index < displaySamples.length; index++) {
      final sample = displaySamples[index];
      if (sample == null) {
        drawing = false;
        continue;
      }
      final x = firstX + index * xStep;
      final y = baseline - sample * 10 * smallGrid;
      if (drawing) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        drawing = true;
      }
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF334D)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveEcgPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.sampleFrequency != sampleFrequency;
}

class AiPage extends StatelessWidget {
  const AiPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshAiArticles,
      child: ListView(
        key: const Key('ai-page'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE7EFFF), Color(0xFFF8FAFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF516392),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 健康管家',
                            style: TextStyle(
                              color: Color(0xFF27479C),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '我是您的健康管家，有任何问题都可以跟我提问哦~',
                            style: TextStyle(
                              color: Color(0xFF516392),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _openChat(context, app: 1),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('马上提问'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              onTap: () => _openChat(context, app: 2),
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi，我是你的运动管家',
                            style: TextStyle(
                              color: Color(0xFF27479C),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            '我可以帮助你提升健身和运动水平！',
                            style: TextStyle(
                              color: Color(0xFF6881C1),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFDDE9FF),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: Color(0xFF27479C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                '健康百科',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                controller.aiStatus,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.aiArticles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无健康百科内容')),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < controller.aiArticles.take(5).length;
                    index++
                  ) ...[
                    _ArticleTile(
                      article: controller.aiArticles[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailPage(
                            controller: controller,
                            article: controller.aiArticles[index],
                          ),
                        ),
                      ),
                    ),
                    if (index < controller.aiArticles.take(5).length - 1)
                      const Divider(indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, {required int app}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatPage(controller: controller, app: app),
      ),
    );
  }
}

class ArticleCategoryPage extends StatefulWidget {
  const ArticleCategoryPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ArticleCategoryPage> createState() => _ArticleCategoryPageState();
}

class _ArticleCategoryPageState extends State<ArticleCategoryPage> {
  List<Map<String, Object?>> _categories = const [];
  List<Map<String, Object?>> _articles = const [];
  int? _selectedCategoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final categories = await widget.controller.loadArticleCategories();
    final articles = await widget.controller.loadArticlesByCategory(
      categoryId: _selectedCategoryId,
    );
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _articles = articles;
      _loading = false;
    });
  }

  Future<void> _selectCategory(int? categoryId) async {
    if (_selectedCategoryId == categoryId && !_loading) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _loading = true;
    });
    final articles = await widget.controller.loadArticlesByCategory(
      categoryId: categoryId,
    );
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.controller.articleCategoryLoadError;
    return Scaffold(
      appBar: AppBar(title: const Text('健康百科')),
      body: Column(
        key: const Key('article-category-page'),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0x11000000))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '健康分类',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        key: const Key('article-category-all'),
                        label: const Text('全部'),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) => _selectCategory(null),
                      ),
                      for (final category in _categories) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            '${category['title'] ?? category['name'] ?? '健康知识'}',
                          ),
                          selected:
                              _selectedCategoryId ==
                              int.tryParse('${category['id'] ?? ''}'),
                          onSelected: (_) => _selectCategory(
                            int.tryParse('${category['id'] ?? ''}'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : error != null ||
                      widget.controller.articleListLoadError != null
                ? _ArticleLoadFailure(onRetry: _load)
                : _articles.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('该分类暂无百科内容')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _articles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final article = _articles[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: _ArticleTile(
                            article: article,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ArticleDetailPage(
                                  controller: widget.controller,
                                  article: article,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({
    required this.controller,
    this.title = '健康百科',
    this.categoryId,
    super.key,
  });

  final AppController controller;
  final String title;
  final int? categoryId;

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  List<Map<String, Object?>> _articles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final articles = await widget.controller.loadArticlesByCategory(
      categoryId: widget.categoryId,
    );
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.controller.articleListLoadError;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ArticleLoadFailure(onRetry: _load)
          : _articles.isEmpty
          ? const Center(child: Text('该分类暂无百科内容'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _articles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final article = _articles[index];
                  return Card(
                    child: _ArticleTile(
                      article: article,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailPage(
                            controller: widget.controller,
                            article: article,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ArticleLoadFailure extends StatelessWidget {
  const _ArticleLoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            const Text('健康百科加载失败'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('article-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final Map<String, Object?> article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = '${article['title'] ?? '健康百科'}';
    final created = article['created_at'];
    String date = '';
    if (created is num) {
      date = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.fromMillisecondsSinceEpoch(created.toInt() * 1000));
    } else if (created != null) {
      date = '$created';
    }
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE8F7ED),
        foregroundColor: Color(0xFF258A4A),
        child: Icon(Icons.menu_book_rounded),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: date.isEmpty ? null : Text(date),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    required this.controller,
    required this.article,
    this.singleArticle = false,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?> article;
  final bool singleArticle;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late Map<String, Object?> _article;
  int? _articleId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _articleId = int.tryParse('${widget.article['id'] ?? ''}');
    if (_articleId != null) unawaited(_load());
  }

  Future<void> _load() async {
    final id = _articleId;
    if (id == null) return;
    if (mounted) setState(() => _loading = true);
    final article = widget.singleArticle
        ? await widget.controller.loadSingleArticle(id)
        : await widget.controller.loadArticle(id);
    if (!mounted) return;
    setState(() {
      if (article.isNotEmpty) _article = article;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_article['title'] ?? '健康百科'}';
    final raw = '${_article['content'] ?? _article['description'] ?? ''}';
    final error = widget.controller.articleDetailLoadError;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ArticleLoadFailure(onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                if (raw.trim().isEmpty)
                  const Text(
                    '文章详情暂未返回正文内容。',
                    style: TextStyle(fontSize: 15, height: 1.75),
                  )
                else
                  ..._articleContentWidgets(raw),
              ],
            ),
    );
  }
}

List<Widget> _articleContentWidgets(String raw) {
  final imagePattern = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>''',
    caseSensitive: false,
  );
  final widgets = <Widget>[];
  var cursor = 0;
  var imageIndex = 0;
  for (final match in imagePattern.allMatches(raw)) {
    final text = _plainTextFromHtml(raw.substring(cursor, match.start));
    if (text.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.75)),
        ),
      );
    }
    final source = _normalizeArticleImageUrl(match.group(1) ?? '');
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            source,
            key: ValueKey('article-content-image-${imageIndex++}'),
            fit: BoxFit.fitWidth,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => Container(
              height: 120,
              alignment: Alignment.center,
              color: const Color(0xFFF4F0ED),
              child: const Text('图片暂时无法加载'),
            ),
          ),
        ),
      ),
    );
    cursor = match.end;
  }
  final tail = _plainTextFromHtml(raw.substring(cursor));
  if (tail.isNotEmpty) {
    widgets.add(Text(tail, style: const TextStyle(fontSize: 15, height: 1.75)));
  }
  return widgets;
}

String _normalizeArticleImageUrl(String source) {
  final trimmed = source.trim();
  if (trimmed.startsWith('/')) return 'https://app.saidian.cc$trimmed';
  return trimmed
      .replaceFirst('http://sd.cc/', 'https://app.saidian.cc/')
      .replaceFirst('https://sd.cc/', 'https://app.saidian.cc/');
}

String _plainTextFromHtml(String raw) => raw
    .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
    .replaceAll(
      RegExp(r'</\s*(p|li|h[1-6]|div)\s*>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
    .trim();

class AiChatPage extends StatefulWidget {
  const AiChatPage({required this.controller, required this.app, super.key});

  final AppController controller;
  final int app;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _messages = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadMessages());
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _messages.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    await widget.controller.refreshAiMessages(app: widget.app);
    _scrollToLatest(jump: true);
  }

  Future<void> _send() async {
    final message = _input.text;
    if (message.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _scrollToLatest();
    final sent = await widget.controller.sendAiMessage(
      app: widget.app,
      message: message,
    );
    if (sent) {
      _input.clear();
      _scrollToLatest();
    }
  }

  void _scrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messages.hasClients) return;
      final target = _messages.position.maxScrollExtent;
      if (jump) {
        _messages.jumpTo(target);
      } else {
        _messages.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.app == 2 ? '运动管家' : 'AI 健康管家')),
      backgroundColor: const Color(0xFFF7F4F1),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: widget.controller.aiMessages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: FeatureStateCard(
                          message: '您好，我是 AI 健康管家',
                          detail: '可以向我咨询日常健康管理问题，回答仅供参考，不能替代医生诊断。',
                          icon: Icons.health_and_safety_outlined,
                          color: SaydianColors.brandRed,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _messages,
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.controller.aiMessages.length,
                      itemBuilder: (context, index) {
                        final message = widget.controller.aiMessages[index];
                        final mine =
                            message['my'] == 1 ||
                            message['my'] == '1' ||
                            message['my'] == true ||
                            message['role'] == 'user';
                        final failed = message['send_failed'] == true;
                        final text =
                            '${message['message'] ?? message['content'] ?? ''}';
                        final bubble = Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .7,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? SaydianColors.brandRed : Colors.white,
                            border: mine
                                ? null
                                : Border.all(color: const Color(0x11000000)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 5),
                              bottomRight: Radius.circular(mine ? 5 : 18),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white
                                      : SaydianColors.ink,
                                  height: 1.5,
                                ),
                              ),
                              if (failed) ...[
                                const SizedBox(height: 5),
                                const Text(
                                  '发送失败，请检查网络后重试',
                                  style: TextStyle(
                                    color: Color(0xFFFFD7D7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: mine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine) ...[
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: SaydianColors.brandRedSoft,
                                  foregroundColor: SaydianColors.brandRed,
                                  child: Icon(
                                    Icons.health_and_safety_outlined,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 9),
                              ],
                              Flexible(child: bubble),
                              if (mine) ...[
                                const SizedBox(width: 9),
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: SaydianColors.ink,
                                  foregroundColor: Colors.white,
                                  child: Icon(Icons.person_rounded, size: 20),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0x11000000))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('ai-message-input'),
                        controller: _input,
                        focusNode: _inputFocus,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(hintText: '请输入消息…'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton.filled(
                      onPressed: widget.controller.isBusy ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DevicePage extends StatelessWidget {
  const DevicePage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.connectedDevice;
    final visibleFeatures = controller.visibleDeviceFeatures;
    final watchFaceFeatures = const [
      DeviceFeature.watchFaces,
      DeviceFeature.photoWatchFace,
    ].where(visibleFeatures.contains).toList(growable: false);
    final primaryFeatures = _primaryFeatures
        .where(visibleFeatures.contains)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (connected != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8E8EA)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF171B2B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: Colors.white,
                        size: 34,
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
                                  connected.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              DeviceSdkBadge(
                                source: connected.sdkSource,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              _BatteryBadge(
                                battery: connected.effectiveBattery,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            connected.identifierLabel,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _ConnectionBadge(
                            label: _deviceStateLabel(controller.deviceState),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isDeviceSyncing
                            ? null
                            : controller.syncDeviceData,
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
                                    ? '正在读取数据'
                                    : '同步中 ${(controller.deviceSyncProgress * 100).round()}%'
                              : '同步数据',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.disconnectDevice,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('断开连接'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDCEBFF), Color(0xFFEEF5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.watch_outlined,
                      color: SaydianColors.blue,
                      size: 62,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '添加智能设备',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请开启手机蓝牙并将手表靠近手机',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SaydianColors.muted, fontSize: 13),
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
                      label: const Text('开始查找'),
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
          const Card(
            key: Key('device-capabilities-loading'),
            child: ListTile(
              leading: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              title: Text('正在识别手表功能…'),
              subtitle: Text('识别完成后只显示当前手表可用的功能'),
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
              title: const Text('暂时无法读取此手表的功能'),
              subtitle: const Text('请保持手表靠近手机后重试'),
              trailing: TextButton(
                key: const Key('device-capabilities-retry'),
                onPressed: controller.refreshDeviceCapabilities,
                child: const Text('重试'),
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
            const Text(
              '表盘与个性化',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
            const Text(
              '设备功能',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
            const _InlineNotice(
              key: Key('device-no-integrated-features'),
              message: '此手表的其他设置请在手表上操作',
              icon: Icons.watch_outlined,
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
                  title: const Text('关于设备'),
                  subtitle: const Text('查看设备信息'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
              ],
              ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: 'connection-help'),
                    builder: (_) => const _InfoPage(
                      title: '连接说明',
                      message:
                          '1. 打开手机蓝牙并允许查找附近设备。\n'
                          '2. 将手表充电激活，并放在手机旁边。\n'
                          '3. 点击“开始查找”，选择自己的手表。\n'
                          '4. 如果手表弹出确认，请及时确认。',
                    ),
                  ),
                ),
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('连接说明'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _InlineNotice(
          message: '连接或同步时，请让手表保持电量充足并靠近手机。',
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE9E9EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
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
                      feature == DeviceFeature.contacts ? '联系人' : feature.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      availability.isReady ? '点击进入' : availability.message,
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
    DeviceFeature.healthMonitoring => SaydianColors.brandRed,
    DeviceFeature.camera ||
    DeviceFeature.notifications ||
    DeviceFeature.screenDisplay => SaydianColors.blue,
    DeviceFeature.phoneCalls ||
    DeviceFeature.contacts ||
    DeviceFeature.healthReminders => SaydianColors.green,
    DeviceFeature.weather ||
    DeviceFeature.worldClock => const Color(0xFF0EA5E9),
    _ => SaydianColors.brandGoldDark,
  };

  String _deviceStateLabel(DeviceConnectionState state) => switch (state) {
    DeviceConnectionState.disconnected => '未连接',
    DeviceConnectionState.scanning => '正在搜索',
    DeviceConnectionState.connecting => '连接中',
    DeviceConnectionState.authenticating => '等待确认',
    DeviceConnectionState.syncing => '正在同步',
    DeviceConnectionState.ready => '已连接',
    DeviceConnectionState.measuring => '测量中',
    DeviceConnectionState.error => '需要处理',
  };
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
        ? '手表电量暂未读取'
        : '手表电量 $label，${value.chargeState.label}';
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
                : value.isCharging
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
                    '表盘市场',
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
                    child: const Center(child: Text('进入表盘市场选择更多样式')),
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
                        child: Image.network(
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

class _DeviceSearchPageState extends State<DeviceSearchPage> {
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startScan());
    });
  }

  @override
  void dispose() {
    unawaited(widget.controller.stopDeviceScan());
    if (_connectingDeviceId != null) {
      unawaited(widget.controller.disconnectDevice());
    }
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_connectingDeviceId != null) return;
    widget.controller.clearError();
    await widget.controller.scanDevices();
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

  Future<void> _openShop() async {
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
        return PopScope(
          canPop: true,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('添加设备'),
              actions: [
                IconButton(
                  tooltip: '重新搜索',
                  onPressed: scanning || connecting ? null : _startScan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: devices.isEmpty
                  ? _DeviceSearchEmpty(
                      scanning: scanning,
                      errorMessage: controller.errorMessage,
                      onRetry: scanning || connecting ? null : _startScan,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      children: [
                        const Text(
                          '已发现设备',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          scanning ? '正在持续搜索，请将手表靠近手机' : '请选择需要连接的手表',
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
                          _InlineNotice(
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
                                          Icons.watch_rounded,
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
                                                const SizedBox(width: 8),
                                                DeviceSdkBadge(
                                                  source: device.sdkSource,
                                                  compact: true,
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
                                                '${device.rssi ?? '--'}',
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
                                            const Text(
                                              '连接',
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
                        if (connecting) ...[
                          const SizedBox(height: 8),
                          _InlineNotice(
                            message:
                                controller.deviceState ==
                                        DeviceConnectionState.connecting ||
                                    controller.deviceState ==
                                        DeviceConnectionState.authenticating
                                ? '正在连接；如手表弹出确认，请在 12 秒内确认，并保持手表靠近手机…'
                                : '正在${_deviceStateLabel(controller.deviceState)}，请保持手表靠近手机…',
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
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: TextButton.icon(
                  key: const Key('device-shop-entry'),
                  onPressed: connecting ? null : _openShop,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text(
                    '没有设备？去赛电商城看看',
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
    required this.onRetry,
  });

  final bool scanning;
  final String? errorMessage;
  final VoidCallback? onRetry;

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
            scanning ? Icons.radar_rounded : Icons.watch_off_outlined,
            color: SaydianColors.blue,
            size: 76,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          scanning ? '正在搜索附近手表' : '未发现设备',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          scanning
              ? '请取出设备、充电激活，并将手表靠近手机'
              : (errorMessage?.trim().isNotEmpty ?? false)
              ? errorMessage!
              : '请确认手表有电且未连接其他手机，然后重新搜索',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SaydianColors.muted, height: 1.5),
        ),
        if (scanning) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
        ] else ...[
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新搜索'),
          ),
          const SizedBox(height: 20),
          const _InlineNotice(
            message: '可尝试重新打开手机蓝牙、让手表靠近手机，或先在其他手机上断开该手表。',
            icon: Icons.info_outline_rounded,
            color: SaydianColors.blue,
          ),
        ],
      ],
    );
  }
}

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
      appBar: AppBar(title: const Text('关于设备')),
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
                      title: const Text('设备名称'),
                      trailing: Text(device?.name ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: const Text('设备型号'),
                      trailing: Text(device?.model ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: const Text('设备服务'),
                      trailing: DeviceSdkBadge(
                        source: device?.sdkSource ?? WearableSdkSource.unknown,
                      ),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: const Text('固件版本'),
                      trailing: Text(device?.firmwareVersion ?? '--'),
                    ),
                    const Divider(indent: 16),
                    ListTile(
                      title: const Text('手表电量'),
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
                        title: const Text('充电状态'),
                        trailing: Text(battery.chargeState.label),
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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshNotifications());
  }

  Future<void> _openItem(Map<String, Object?> item) async {
    final eventId = '${item['event_id'] ?? ''}'.trim();
    if (eventId.isNotEmpty) {
      await widget.controller.markNotificationEventRead(eventId);
    }
    if (!mounted) return;
    final eventType = '${item['_eventType'] ?? ''}';
    if (eventType == NotificationEventType.careInvitation.name) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CareInvitationsPage(
            controller: widget.controller,
            targetInvitationId: '${item['entity_id'] ?? ''}'.trim(),
          ),
        ),
      );
      return;
    }
    final id = int.tryParse('${item['id'] ?? ''}');
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailPage(
          controller: widget.controller,
          id: id,
          initial: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final healthWarnings = widget.controller.healthWarningAlerts
              .asMap()
              .entries
              .map((entry) {
                final eventId = widget.controller.healthWarningEventId(
                  entry.value,
                );
                final matchingEvents = widget.controller.notificationInboxEvents
                    .where((item) => item.eventId == eventId)
                    .toList(growable: false);
                final event = matchingEvents.isEmpty
                    ? null
                    : matchingEvents.first;
                return <String, Object?>{
                  'id': -(entry.key + 1),
                  '_localHealthWarning': true,
                  '_localNotification': true,
                  '_eventType': NotificationEventType.healthWarning.name,
                  'event_id': eventId,
                  'is_read': event?.isRead ?? true,
                  'title': entry.value.title,
                  'content': entry.value.message,
                  'created_at': DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(entry.value.triggeredAt.toLocal()),
                  'kind': 'health_warning',
                };
              })
              .toList(growable: false);
          final healthEventIds = healthWarnings
              .map((item) => '${item['event_id'] ?? ''}')
              .toSet();
          final localEvents = widget.controller.notificationInboxEvents
              .where((event) => !healthEventIds.contains(event.eventId))
              .map(
                (event) => <String, Object?>{
                  'id': -((event.eventId.hashCode & 0x3fffffff) + 1000),
                  '_localNotification': true,
                  '_eventType': event.type.name,
                  'event_id': event.eventId,
                  'entity_id': event.entityId,
                  'is_read': event.isRead,
                  'title': switch (event.type) {
                    NotificationEventType.careInvitation => '关爱邀请',
                    NotificationEventType.healthWarning => '健康预警',
                    NotificationEventType.system => '系统消息',
                  },
                  'content': switch (event.type) {
                    NotificationEventType.careInvitation =>
                      '您有新的关爱请求，请点击查看最新状态。',
                    NotificationEventType.healthWarning => '有新的健康预警，请打开预警记录查看。',
                    NotificationEventType.system => '您有一条新消息。',
                  },
                  'created_at': DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(event.createdAt.toLocal()),
                  'kind': event.type == NotificationEventType.healthWarning
                      ? 'health_warning'
                      : event.type.wireName,
                },
              )
              .toList(growable: false);
          final localEventIds = <String>{
            ...healthEventIds,
            ...localEvents.map((item) => '${item['event_id'] ?? ''}'),
          };
          final remoteNotifications = widget.controller.notifications
              .where(
                (item) => !localEventIds.contains(
                  '${item['event_id'] ?? item['eventId'] ?? ''}',
                ),
              )
              .toList(growable: false);
          final values = <Map<String, Object?>>[
            ...healthWarnings,
            ...localEvents,
            ...remoteNotifications,
          ];
          final permissionCard =
              widget.controller.notificationServiceConfigured &&
                  !widget.controller.notificationPermissionEnabled
              ? Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: const Text('系统通知未开启'),
                    subtitle: const Text('应用内红点和消息仍可使用，开启后可及时收到关爱邀请与健康预警。'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'request') {
                          unawaited(
                            widget.controller.requestNotificationPermission(),
                          );
                        } else {
                          unawaited(
                            widget.controller.openNotificationSettings(),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'request', child: Text('允许通知')),
                        PopupMenuItem(value: 'settings', child: Text('系统设置')),
                      ],
                    ),
                  ),
                )
              : null;
          return Column(
            children: [
              ?permissionCard,
              Expanded(
                child: values.isEmpty
                    ? Center(
                        child: Text(
                          widget.controller.notificationStatus,
                          style: const TextStyle(color: SaydianColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.controller.refreshNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: values.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = values[index];
                            final isHealthWarning =
                                item['kind'] == 'health_warning';
                            final unread = item['is_read'] == false;
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => unawaited(_openItem(item)),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isHealthWarning
                                      ? SaydianColors.brandRedSoft
                                      : SaydianColors.techBlueSoft,
                                  foregroundColor: isHealthWarning
                                      ? SaydianColors.brandRed
                                      : SaydianColors.techBlue,
                                  child: Icon(
                                    isHealthWarning
                                        ? Icons.health_and_safety_rounded
                                        : Icons.notifications_none_rounded,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['title'] ?? item['name'] ?? '系统消息'}',
                                        style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (unread)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: CircleAvatar(
                                          radius: 4,
                                          backgroundColor:
                                              SaydianColors.brandRed,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                        _notificationPreview(item),
                                        '${item['created_at'] ?? item['createdAt'] ?? ''}',
                                      ]
                                      .where((value) => value.trim().isNotEmpty)
                                      .join('\n'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NotificationDetailPage extends StatefulWidget {
  const NotificationDetailPage({
    required this.controller,
    required this.id,
    required this.initial,
    super.key,
  });

  final AppController controller;
  final int id;
  final Map<String, Object?> initial;

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  late Map<String, Object?> _value = widget.initial;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.initial['_localNotification'] == true) return;
    final value = await widget.controller.loadNotification(widget.id);
    if (mounted && value.isNotEmpty) setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_value['title'] ?? _value['name'] ?? '消息详情'}';
    final raw = '${_value['content'] ?? _value['description'] ?? ''}';
    final content = _resolveNotificationContent(_value, raw);
    final isHealthWarning = _value['kind'] == 'health_warning';
    final createdAt = '${_value['created_at'] ?? _value['createdAt'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('消息详情')),
      backgroundColor: const Color(0xFFF7F4F1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHealthWarning
                    ? const [Color(0xFF9E1025), Color(0xFFD20B27)]
                    : const [Color(0xFF11182D), Color(0xFF344B7D)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white.withValues(alpha: .16),
                  foregroundColor: Colors.white,
                  child: Icon(
                    isHealthWarning
                        ? Icons.health_and_safety_rounded
                        : Icons.mark_email_read_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          createdAt,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                content.isEmpty ? '暂无消息正文' : content,
                style: const TextStyle(fontSize: 16, height: 1.75),
              ),
            ),
          ),
          if (isHealthWarning) ...[
            const SizedBox(height: 12),
            const _InlineNotice(
              message: '健康预警用于及时提醒，不作为医疗诊断；如有明显不适，请及时就医。',
              icon: Icons.info_outline_rounded,
              color: SaydianColors.orange,
            ),
          ],
        ],
      ),
    );
  }
}

String _notificationPreview(Map<String, Object?> value) {
  final raw = '${value['content'] ?? value['description'] ?? ''}';
  return _resolveNotificationContent(value, raw);
}

String _resolveNotificationContent(Map<String, Object?> value, String raw) {
  final orderNumber = _notificationOrderNumber(value);
  final fallback = orderNumber ?? '订单号暂未返回';
  return _plainTextFromHtml(raw).replaceAll('#order_sn#', fallback);
}

String? _notificationOrderNumber(Object? value, [int depth = 0]) {
  if (depth > 5 || value == null) return null;
  if (value is Map) {
    for (final key in const ['order_sn', 'orderSn', 'order_no', 'orderNo']) {
      final text = '${value[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != '#order_sn#') return text;
    }
    for (final nested in value.values) {
      final result = _notificationOrderNumber(nested, depth + 1);
      if (result != null) return result;
    }
  } else if (value is Iterable) {
    for (final nested in value) {
      final result = _notificationOrderNumber(nested, depth + 1);
      if (result != null) return result;
    }
  } else if (value is String) {
    final text = value.trim();
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        return _notificationOrderNumber(jsonDecode(text), depth + 1);
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

class CarePage extends StatefulWidget {
  const CarePage({required this.controller, super.key});

  final AppController controller;

  @override
  State<CarePage> createState() => _CarePageState();
}

class _CarePageState extends State<CarePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.refreshCare());
      unawaited(widget.controller.refreshCareInvitations());
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final memberCount = controller.careMembers.length;
      return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            controller.refreshCare(),
            controller.refreshCareInvitations(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA51125), Color(0xFFD72D42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2EA51125),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '守护家人健康',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          memberCount == 0
                              ? '添加关爱成员后查看授权数据'
                              : '正在关爱 $memberCount 位家人',
                          style: const TextStyle(
                            color: Color(0xFFFFDCE1),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed:
                        controller.session == null || controller.isPreviewMode
                        ? null
                        : () => _showAddCareDialog(context, controller),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SaydianColors.brandRed,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: _CareActionEntry(
                      icon: Icons.manage_accounts_outlined,
                      title: '共享管理',
                      subtitle: '授权与隐私',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: 'sharing-management',
                          ),
                          builder: (_) =>
                              SharingManagementPage(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 76, child: VerticalDivider(width: 1)),
                  Expanded(
                    child: _CareActionEntry(
                      icon: Icons.mark_email_unread_outlined,
                      title: '关爱邀请',
                      subtitle: controller.pendingCareInvitations.isEmpty
                          ? controller.careInvitationStatus
                          : '${controller.pendingCareInvitations.length} 条待处理',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: 'care-invitations',
                          ),
                          builder: (_) =>
                              CareInvitationsPage(controller: controller),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '关爱成员',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (controller.careMembers.isEmpty)
              _CareMembersStateCard(
                status: controller.careStatus,
                errorMessage: controller.careErrorMessage,
                isPreviewMode: controller.isPreviewMode,
                canAdd: controller.session != null && !controller.isPreviewMode,
                onRetry: () async {
                  await Future.wait([
                    controller.refreshCare(),
                    controller.refreshCareInvitations(),
                  ]);
                },
                onAdd: () => _showAddCareDialog(context, controller),
              )
            else
              for (final member in controller.careMembers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      onTap: () {
                        final id = int.tryParse('${member['id'] ?? ''}');
                        if (id == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CareMemberPage(
                              controller: controller,
                              member: member,
                              careId: id,
                            ),
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      leading: _MemberAvatar(
                        imageUrl: '${member['head_portrait'] ?? ''}'.trim(),
                        size: 46,
                      ),
                      title: Text(
                        '${member['nickname'] ?? member['mobile'] ?? '关爱成员'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${member['mobile'] ?? '手机号未提供'}\n点击查看实时健康数据',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            const _InlineNotice(
              message: '默认不共享任何数据；成员可按指标授权并随时撤销。',
              icon: Icons.privacy_tip_outlined,
              color: SaydianColors.green,
            ),
          ],
        ),
      );
    },
  );
}

class _CareMembersStateCard extends StatelessWidget {
  const _CareMembersStateCard({
    required this.status,
    required this.errorMessage,
    required this.isPreviewMode,
    required this.canAdd,
    required this.onRetry,
    required this.onAdd,
  });

  final String status;
  final String? errorMessage;
  final bool isPreviewMode;
  final bool canAdd;
  final Future<void> Function() onRetry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final loading = status == '加载中' || status == '等待加载';
    final failed = status == '加载失败' || status == '服务暂不可用';
    final stateKey = loading
        ? const Key('care-members-loading')
        : failed
        ? const Key('care-members-error')
        : const Key('care-members-empty');
    final title = loading
        ? '正在读取关爱成员'
        : failed
        ? status
        : isPreviewMode
        ? '当前暂无关爱成员'
        : '暂无关爱成员';
    final description = failed
        ? (errorMessage?.trim().isNotEmpty == true
              ? errorMessage!.trim()
              : '关爱数据暂时无法读取，请稍后重试。')
        : '通过手机号邀请家人，对方接受并授权后才会共享健康数据。';

    return Card(
      key: stateKey,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: failed
                    ? const Color(0xFFFFF3E8)
                    : SaydianColors.brandRedSoft,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Icon(
                      failed ? Icons.cloud_off_outlined : Icons.group_outlined,
                      size: 38,
                      color: failed
                          ? const Color(0xFFC75A00)
                          : SaydianColors.brandRed,
                    ),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SaydianColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (!loading) ...[
              const SizedBox(height: 16),
              if (failed)
                OutlinedButton.icon(
                  onPressed: () => unawaited(onRetry()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新加载'),
                )
              else
                FilledButton.icon(
                  onPressed: canAdd ? onAdd : null,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('添加关爱'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CareActionEntry extends StatelessWidget {
  const _CareActionEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SaydianColors.brandRedSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: SaydianColors.brandRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
        ],
      ),
    ),
  );
}

class CareMemberPage extends StatefulWidget {
  const CareMemberPage({
    required this.controller,
    required this.member,
    required this.careId,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?> member;
  final int careId;

  @override
  State<CareMemberPage> createState() => _CareMemberPageState();
}

class _CareMemberPageState extends State<CareMemberPage> {
  Map<String, Object?> _data = const {};
  bool _loading = true;
  DateTime _day = DateTime.now();
  Timer? _refreshTimer;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isToday(_day) && mounted && !_loading) {
        unawaited(_load(silent: true));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final nestedMember = widget.member['member'];
    final memberId =
        int.tryParse('${widget.member['to_member_id'] ?? ''}') ??
        (nestedMember is Map
            ? int.tryParse('${nestedMember['id'] ?? ''}')
            : null);
    final value = await widget.controller.loadCareMemberPreview(
      widget.careId,
      day: _day,
      memberId: memberId,
    );
    if (mounted) {
      setState(() {
        _data = value;
        _loading = false;
        _updatedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.member['nickname'] ?? widget.member['mobile'] ?? '关爱成员'}';
    final loadError = '${_data['loadError'] ?? ''}'.trim();
    final todayItems = _mapList(_data['jrjk']);
    final dailyItems = _mapList(_data['daily']);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: '前一天',
                            onPressed: _loading ? null : () => _shiftDay(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _loading ? null : _pickDay,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(DateFormat('yyyy年M月d日').format(_day)),
                            ),
                          ),
                          IconButton(
                            tooltip: '后一天',
                            onPressed: _loading || _isToday(_day)
                                ? null
                                : () => _shiftDay(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_updatedAt != null && _isToday(_day))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.sync_rounded,
                            size: 16,
                            color: SaydianColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '实时更新 · ${DateFormat('HH:mm:ss').format(_updatedAt!)}',
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (loadError.isNotEmpty)
                    _InlineNotice(
                      message: loadError,
                      icon: Icons.cloud_off_outlined,
                      color: SaydianColors.orange,
                    )
                  else if (_data.isEmpty)
                    const _InlineNotice(
                      message: '对方尚未授权健康数据，或当前日期没有数据。',
                      icon: Icons.privacy_tip_outlined,
                      color: SaydianColors.orange,
                    )
                  else ...[
                    if (todayItems.isNotEmpty) ...[
                      _CareSectionTitle(
                        title: _isToday(_day) ? '今日活动' : '当日活动',
                        subtitle: '成员授权共享的活动概况',
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final item in todayItems)
                                SizedBox(
                                  width: itemWidth,
                                  child: _CareHealthCard(item: item),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (todayItems.isNotEmpty && dailyItems.isNotEmpty)
                      const SizedBox(height: 20),
                    if (dailyItems.isNotEmpty) ...[
                      const _CareSectionTitle(
                        title: '健康详情',
                        subtitle: '活动、睡眠与身体指标摘要',
                      ),
                      const SizedBox(height: 10),
                      for (final item in dailyItems) ...[
                        _CareDailyCard(
                          item: item,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CareMetricDetailPage(item: item, day: _day),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (todayItems.isEmpty && dailyItems.isEmpty)
                      const _InlineNotice(
                        message: '当前日期没有可展示的授权数据。',
                        icon: Icons.event_busy_outlined,
                        color: SaydianColors.orange,
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  void _shiftDay(int offset) {
    final candidate = _day.add(Duration(days: offset));
    if (candidate.isAfter(DateTime.now())) return;
    setState(() {
      _day = candidate;
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择关爱数据日期',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = picked;
      _loading = true;
    });
    await _load();
  }
}

class _CareSectionTitle extends StatelessWidget {
  const _CareSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
      ),
    ],
  );
}

class _CareHealthCard extends StatelessWidget {
  const _CareHealthCard({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final title = '${item['title'] ?? '健康指标'}';
    final value = '${item['num'] ?? item['value'] ?? '--'}';
    final unit = '${item['unit'] ?? ''}'.trim();
    final percent = _careNumber(item['percent']).clamp(0, 100).toDouble();
    final color = _careColor(item['color']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 4,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: const TextStyle(color: SaydianColors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: percent > 0 ? percent / 100 : 0,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareDailyCard extends StatelessWidget {
  const _CareDailyCard({required this.item, required this.onTap});

  final Map<String, Object?> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = '${item['title'] ?? '健康详情'}';
    final tips = '${item['tips'] ?? item['tip'] ?? ''}'.trim();
    final summary = _careSummary(item);
    final unavailable = item['state'] == 'unavailable';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SaydianColors.brandRedSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      unavailable
                          ? Icons.cloud_off_outlined
                          : Icons.monitor_heart_outlined,
                      color: unavailable
                          ? SaydianColors.orange
                          : SaydianColors.brandRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: SaydianColors.muted,
                  ),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in summary.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: SaydianColors.techBlueSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${entry.key}  ${entry.value}'),
                      ),
                  ],
                ),
              ],
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  tips,
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CareMetricDetailPage extends StatelessWidget {
  const CareMetricDetailPage({
    required this.item,
    required this.day,
    super.key,
  });

  final Map<String, Object?> item;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final title = '${item['title'] ?? '健康数据'}';
    final state = '${item['state'] ?? ''}';
    final tips = '${item['tips'] ?? ''}'.trim();
    final metricUnit = '${item['unit'] ?? ''}'.trim();
    final rawRecords = item['records'];
    final allRecords = rawRecords is List
        ? rawRecords
              .whereType<Map>()
              .map((row) => row.map((key, value) => MapEntry('$key', value)))
              .toList(growable: false)
        : const <Map<String, Object?>>[];
    final records = title == '心电'
        ? allRecords
        : allRecords
              .where(
                (record) => _careMetricDisplayFields(
                  title,
                  record,
                  fallbackUnit: metricUnit,
                ).isNotEmpty,
              )
              .toList(growable: false);
    final summary = _careMetricDaySummary(title, records);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat('yyyy年M月d日').format(day),
            style: const TextStyle(
              color: SaydianColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (records.isNotEmpty) ...[
            _CareMetricDaySummaryCard(summary: summary),
            const SizedBox(height: 12),
          ],
          if (records.isEmpty)
            _InlineNotice(
              message: tips.isNotEmpty ? tips : '这一天没有可展示的明细记录。',
              icon: state == 'unavailable'
                  ? Icons.cloud_off_outlined
                  : Icons.event_busy_outlined,
              color: SaydianColors.orange,
            )
          else
            for (var index = 0; index < records.length; index++) ...[
              if (title == '心电')
                _CareEcgRecordCard(record: records[index], index: index)
              else
                _CareMetricRecordCard(
                  metricTitle: title,
                  metricUnit: metricUnit,
                  record: records[index],
                  index: index,
                ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CareMetricDaySummaryCard extends StatelessWidget {
  const _CareMetricDaySummaryCard({required this.summary});

  final Map<String, String> summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('当日摘要', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          const Text(
            '仅汇总当前所选日期的有效记录',
            style: TextStyle(color: SaydianColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in summary.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: SaydianColors.techBlueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${entry.key}  ${entry.value}'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CareMetricRecordCard extends StatelessWidget {
  const _CareMetricRecordCard({
    required this.metricTitle,
    required this.metricUnit,
    required this.record,
    required this.index,
  });

  final String metricTitle;
  final String metricUnit;
  final Map<String, Object?> record;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fields = _careMetricDisplayFields(
      metricTitle,
      record,
      fallbackUnit: metricUnit,
    );
    final time = _careRecordTimeLabel(record);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time.isEmpty ? '第 ${index + 1} 条记录' : time,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (fields.isEmpty)
              Text(
                '该记录未包含可用的$metricTitle数据',
                style: const TextStyle(color: SaydianColors.muted),
              )
            else
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 94,
                        child: Text(
                          field.label,
                          style: const TextStyle(color: SaydianColors.muted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          field.unit.isEmpty
                              ? field.value
                              : '${field.value} ${field.unit}',
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CareEcgRecordCard extends StatelessWidget {
  const _CareEcgRecordCard({required this.record, required this.index});

  final Map<String, Object?> record;
  final int index;

  num? _number(String key) {
    final value = record[key];
    return value is num ? value : num.tryParse('${value ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    final samples = record['samples'] is List
        ? (record['samples'] as List).whereType<num>().toList(growable: false)
        : const <num>[];
    final frequency = (_number('sampleFrequency')?.toInt() ?? 250).clamp(
      50,
      1000,
    );
    final calibrated = (_number('rawVersion')?.toInt() ?? 1) >= 2;
    final usableWaveform =
        calibrated &&
        samples.length > 1 &&
        hasUsableEcgSignal(samples, sampleFrequency: frequency);
    final values = <(String, num?, String)>[
      ('心率', _number('meanHeartRate'), 'bpm'),
      ('QT', _number('averageTimeInterval'), 'ms'),
      ('HRV', _number('averageHRV'), 'ms'),
    ];
    final time = _careRecordTimeLabel(record);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    time.isEmpty ? '第 ${index + 1} 条记录' : time,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Text(
                  '远程成员数据',
                  style: TextStyle(
                    color: SaydianColors.techBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final value in values)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          value.$1,
                          style: const TextStyle(color: SaydianColors.muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value.$2 == null
                              ? '--'
                              : _careFormatNumber(value.$2!),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          value.$3,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (usableWaveform)
              Container(
                key: const Key('care-ecg-waveform'),
                height: 150,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF08090B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  painter: _LiveEcgPainter(samples, sampleFrequency: frequency),
                ),
              )
            else
              const _InlineNotice(
                message: '暂无可用心电波形',
                icon: Icons.monitor_heart_outlined,
                color: SaydianColors.orange,
              ),
          ],
        ),
      ),
    );
  }
}

typedef _CareMetricDisplayField = ({String label, String value, String unit});

List<_CareMetricDisplayField> _careMetricDisplayFields(
  String title,
  Map<String, Object?> record, {
  String fallbackUnit = '',
}) {
  _CareMetricDisplayField? scalar(
    String label,
    List<String> keys,
    String unit,
  ) {
    final value = _careMetricNumber(record, keys);
    if (value == null) return null;
    return (
      label: label,
      value: _careFormatNumber(value),
      unit: unit.isEmpty ? fallbackUnit : unit,
    );
  }

  switch (title) {
    case '心率':
      return [
        ?scalar('心率', const [
          'pulseReat',
          'heartReat',
          'heartRate',
          'heart',
        ], '次/分'),
      ];
    case '血糖':
      return [
        ?scalar('血糖', const [
          'bloodGlucose',
          'bloodSugar',
          'glucose',
        ], 'mmol/L'),
      ];
    case '血氧':
      return [
        ?scalar('血氧', const ['bloodOxygen', 'oxygen', 'oxygens', 'spo2'], '%'),
      ];
    case '体温':
      return [
        ?scalar('体温', const ['bodyTemperature', 'temperature', 'temp'], '℃'),
      ];
    case 'HRV':
      return [
        ?scalar('HRV', const ['HRVData', 'hrv', 'averageHRV', 'aveHrv'], 'ms'),
      ];
    case '血压':
      final high = scalar('收缩压', const [
        'bloodPressureHigh',
        'highPressure',
        'systolic',
        'high',
      ], 'mmHg');
      final low = scalar('舒张压', const [
        'bloodPressureLow',
        'lowPressure',
        'diastolic',
        'low',
      ], 'mmHg');
      final pair = _careMetricPressurePair(record);
      final pulse = scalar('脉搏', const [
        'pulseReat',
        'heartReat',
        'heartRate',
        'pulse',
      ], '次/分');
      return [
        high ??
            (pair == null
                ? null
                : (
                    label: '收缩压',
                    value: _careFormatNumber(pair.$1),
                    unit: 'mmHg',
                  )),
        low ??
            (pair == null
                ? null
                : (
                    label: '舒张压',
                    value: _careFormatNumber(pair.$2),
                    unit: 'mmHg',
                  )),
        ?pulse,
      ].whereType<_CareMetricDisplayField>().toList(growable: false);
    case '睡眠':
      return _careCompositeMetricFields(record, const [
        (label: '总睡眠', keys: ['sleepMinutes', 'allSleepTime'], unit: '分钟'),
        (label: '深睡', keys: ['deepSleep', 'deepSleepTime'], unit: '分钟'),
        (label: '浅睡', keys: ['lightSleep', 'lightSleepTime'], unit: '分钟'),
        (label: '清醒', keys: ['awake', 'awakeTime'], unit: '分钟'),
      ]);
    case '身体成分':
      return _careCompositeMetricFields(record, const [
        (label: 'BMI', keys: ['BMI', 'bmi'], unit: ''),
        (label: '体脂率', keys: ['bodyFatRate', 'bodyFatPercentage'], unit: '%'),
        (label: '脂肪量', keys: ['fatRate', 'fatMass'], unit: 'kg'),
        (label: '去脂体重', keys: ['fatFreeRate', 'fatFreeMass'], unit: 'kg'),
        (label: '肌肉率', keys: ['muscleRate'], unit: '%'),
        (label: '肌肉量', keys: ['muscleMass'], unit: 'kg'),
        (label: '皮下脂肪率', keys: ['subcutaneousFat'], unit: '%'),
        (label: '体水分率', keys: ['bodyMoisture', 'bodyWaterRate'], unit: '%'),
        (label: '水分量', keys: ['waterContent', 'waterMass'], unit: 'kg'),
        (
          label: '骨骼肌率',
          keys: ['skeletalMuscle', 'skeletalMuscleRate'],
          unit: '%',
        ),
        (label: '骨量', keys: ['boneMass'], unit: 'kg'),
        (label: '蛋白质率', keys: ['proteinProportion', 'proteinRate'], unit: '%'),
        (label: '蛋白质量', keys: ['proteinMass'], unit: 'kg'),
        (
          label: '基础代谢',
          keys: ['basalMetabolicRate', 'basalMetabolism'],
          unit: 'kcal/日',
        ),
      ]);
    case '血液成分':
      return _careCompositeMetricFields(record, const [
        (label: '尿酸', keys: ['uricAcidVal', 'uricAcid'], unit: 'μmol/L'),
        (
          label: '总胆固醇',
          keys: ['cholesterol', 'totalCholesterol'],
          unit: 'mmol/L',
        ),
        (
          label: '甘油三酯',
          keys: ['triacylglycerol', 'triglycerides'],
          unit: 'mmol/L',
        ),
        (
          label: '高密度脂蛋白',
          keys: ['highDensity', 'highDensityLipoprotein'],
          unit: 'mmol/L',
        ),
        (
          label: '低密度脂蛋白',
          keys: ['lowDensity', 'lowDensityLipoprotein'],
          unit: 'mmol/L',
        ),
      ]);
    default:
      final value = _careMetricNumber(record, const []);
      if (value == null) return const [];
      return [
        (label: title, value: _careFormatNumber(value), unit: fallbackUnit),
      ];
  }
}

typedef _CareCompositeMetricSpec = ({
  String label,
  List<String> keys,
  String unit,
});

List<_CareMetricDisplayField> _careCompositeMetricFields(
  Map<String, Object?> record,
  List<_CareCompositeMetricSpec> specs,
) => specs
    .map((spec) {
      final value = _careMetricNumber(record, spec.keys, allowGeneric: false);
      return value == null
          ? null
          : (
              label: spec.label,
              value: _careFormatNumber(value),
              unit: spec.unit,
            );
    })
    .whereType<_CareMetricDisplayField>()
    .toList(growable: false);

num? _careMetricNumber(
  Map<String, Object?> record,
  List<String> keys, {
  bool allowGeneric = true,
}) {
  for (final source in _careMetricSources(record)) {
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = _carePositiveDisplayNumber(
        source[key],
        preferredKeys: keys,
        allowAnyNested: true,
      );
      if (value != null) return value;
    }
  }
  if (!allowGeneric) return null;
  for (final source in _careMetricSources(record)) {
    if (!source.containsKey('value')) continue;
    final raw = source['value'];
    if (raw is num || raw is String) {
      final value = _carePositiveDisplayNumber(raw);
      if (value != null) return value;
    } else {
      final value = _carePositiveDisplayNumber(
        raw,
        preferredKeys: keys,
        allowAnyNested: false,
      );
      if (value != null) return value;
    }
  }
  return null;
}

Iterable<Map<String, Object?>> _careMetricSources(
  Map<String, Object?> record, [
  int depth = 0,
]) sync* {
  yield record;
  if (depth >= 2) return;
  const wrapperKeys = [
    'data',
    'result',
    'item',
    'detail',
    'bloodPressure',
    'bodycomposition',
    'bodyComposition',
    'bloodcomposition',
    'bloodComposition',
    'sleepData',
  ];
  for (final key in wrapperKeys) {
    final value = record[key];
    if (value is Map) {
      final nested = value.map((key, value) => MapEntry('$key', value));
      yield* _careMetricSources(nested, depth + 1);
    }
  }
}

num? _carePositiveDisplayNumber(
  Object? value, {
  List<String> preferredKeys = const [],
  bool allowAnyNested = true,
}) {
  if (value is num) {
    return value.isFinite && value > 0 ? value : null;
  }
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }
  if (value is List) {
    for (final item in value) {
      final parsed = _carePositiveDisplayNumber(
        item,
        preferredKeys: preferredKeys,
        allowAnyNested: allowAnyNested,
      );
      if (parsed != null) return parsed;
    }
    return null;
  }
  if (value is Map) {
    for (final key in preferredKeys) {
      if (!value.containsKey(key)) continue;
      final parsed = _carePositiveDisplayNumber(
        value[key],
        preferredKeys: preferredKeys,
        allowAnyNested: allowAnyNested,
      );
      if (parsed != null) return parsed;
    }
    for (final key in const ['value', 'num']) {
      if (!value.containsKey(key)) continue;
      final parsed = _carePositiveDisplayNumber(
        value[key],
        preferredKeys: preferredKeys,
        allowAnyNested: allowAnyNested,
      );
      if (parsed != null) return parsed;
    }
    if (allowAnyNested) {
      for (final nested in value.values) {
        final parsed = _carePositiveDisplayNumber(
          nested,
          preferredKeys: preferredKeys,
          allowAnyNested: true,
        );
        if (parsed != null) return parsed;
      }
    }
  }
  return null;
}

(num, num)? _careMetricPressurePair(Map<String, Object?> record) {
  final high = _careMetricNumber(record, const [
    'bloodPressureHigh',
    'highPressure',
    'systolic',
    'high',
  ], allowGeneric: false);
  final low = _careMetricNumber(record, const [
    'bloodPressureLow',
    'lowPressure',
    'diastolic',
    'low',
  ], allowGeneric: false);
  if (high != null && low != null) return (high, low);
  final raw = record['bloodPressure'];
  if (raw is List && raw.length >= 2) {
    final first = _carePositiveDisplayNumber(raw[0]);
    final second = _carePositiveDisplayNumber(raw[1]);
    if (first != null && second != null) return (first, second);
  }
  if (raw is String) {
    final match = RegExp(
      r'^\s*(\d{2,3}(?:\.\d+)?)\s*[/,\-]\s*(\d{2,3}(?:\.\d+)?)\s*$',
    ).firstMatch(raw);
    if (match != null) {
      final first = num.tryParse(match.group(1)!);
      final second = num.tryParse(match.group(2)!);
      if (first != null && second != null && first > 0 && second > 0) {
        return (first, second);
      }
    }
  }
  return null;
}

Map<String, String> _careMetricDaySummary(
  String title,
  List<Map<String, Object?>> records,
) {
  final result = <String, String>{'记录数': '${records.length} 条'};
  if (title == '心电' || title == '身体成分' || title == '血液成分') {
    return result;
  }
  if (title == '血压') {
    final values = records
        .map(_careMetricPressurePair)
        .whereType<(num, num)>()
        .toList(growable: false);
    if (values.isEmpty) return result;
    String pair(num high, num low) =>
        '${_careFormatNumber(high)}/${_careFormatNumber(low)} mmHg';
    result['最近'] = pair(values.last.$1, values.last.$2);
    result['平均'] = pair(
      values.map((value) => value.$1).reduce((a, b) => a + b) / values.length,
      values.map((value) => value.$2).reduce((a, b) => a + b) / values.length,
    );
    result['最高'] = pair(
      values.map((value) => value.$1).reduce(math.max),
      values.map((value) => value.$2).reduce(math.max),
    );
    result['最低'] = pair(
      values.map((value) => value.$1).reduce(math.min),
      values.map((value) => value.$2).reduce(math.min),
    );
    return result;
  }
  final keys = switch (title) {
    '心率' => const ['pulseReat', 'heartReat', 'heartRate', 'heart'],
    '血糖' => const ['bloodGlucose', 'bloodSugar', 'glucose'],
    '血氧' => const ['bloodOxygen', 'oxygen', 'oxygens', 'spo2'],
    '体温' => const ['bodyTemperature', 'temperature', 'temp'],
    'HRV' => const ['HRVData', 'hrv', 'averageHRV', 'aveHrv'],
    '睡眠' => const ['sleepMinutes', 'allSleepTime'],
    _ => const <String>[],
  };
  final values = records
      .map((record) => _careMetricNumber(record, keys))
      .whereType<num>()
      .toList(growable: false);
  if (values.isEmpty) return result;
  final unit = switch (title) {
    '心率' => '次/分',
    '血糖' => 'mmol/L',
    '血氧' => '%',
    '体温' => '℃',
    'HRV' => 'ms',
    '睡眠' => '分钟',
    _ => '',
  };
  String format(num value) => unit.isEmpty
      ? _careFormatNumber(value)
      : '${_careFormatNumber(value)} $unit';
  result['最近'] = format(values.last);
  result['平均'] = format(values.reduce((a, b) => a + b) / values.length);
  result['最高'] = format(values.reduce(math.max));
  result['最低'] = format(values.reduce(math.min));
  return result;
}

String _careRecordTimeLabel(Map<String, Object?> record) {
  Object? raw;
  for (final key in const [
    'time',
    'hourse',
    'h',
    'date',
    'timestamp',
    'measuredAt',
    'created_at',
  ]) {
    final candidate = record[key];
    if (candidate == null || '$candidate'.trim().isEmpty) continue;
    raw = candidate;
    break;
  }
  if (raw == null) return '';
  if (raw is num) return _careNumericTimeLabel(raw);

  final text = '$raw'.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return '';
  final clock = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(text);
  if (clock != null) {
    final hour = int.parse(clock.group(1)!);
    final minute = int.parse(clock.group(2)!);
    final second = int.tryParse(clock.group(3) ?? '') ?? 0;
    if (hour < 24 && minute < 60 && second < 60) {
      return _careClockLabel(hour, minute, second);
    }
    return '';
  }
  final numeric = num.tryParse(text);
  if (numeric != null) return _careNumericTimeLabel(numeric);
  final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  return parsed == null
      ? ''
      : _careClockLabel(parsed.hour, parsed.minute, parsed.second);
}

String _careNumericTimeLabel(num value) {
  if (!value.isFinite || value < 0) return '';
  final numeric = value.toInt();
  if (value == numeric && numeric >= 0 && numeric < 24) {
    return _careClockLabel(numeric, 0, 0);
  }
  DateTime? parsed;
  if (numeric > 1000000000000) {
    parsed = DateTime.fromMillisecondsSinceEpoch(numeric);
  } else if (numeric > 1000000000) {
    parsed = DateTime.fromMillisecondsSinceEpoch(numeric * 1000);
  }
  return parsed == null
      ? ''
      : _careClockLabel(parsed.hour, parsed.minute, parsed.second);
}

String _careClockLabel(int hour, int minute, int second) {
  final base =
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
  return second == 0 ? base : '$base:${second.toString().padLeft(2, '0')}';
}

String _careFieldValue(Object? value) {
  if (value is num) return _careFormatNumber(value);
  if (value is List) return value.map(_careFieldValue).join('、');
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${_careFieldValue(entry.value)}')
        .join('，');
  }
  final parsed = num.tryParse('${value ?? ''}'.trim());
  if (parsed != null) return _careFormatNumber(parsed);
  return '$value';
}

String _careFormatNumber(num value) {
  if (value is int) return '$value';
  final numeric = value.toDouble();
  if (!numeric.isFinite) return '$value';
  return numeric
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

num _careNumber(Object? value) =>
    value is num ? value : num.tryParse('$value') ?? 0;

Color _careColor(Object? value) {
  final text = '${value ?? ''}'.trim().replaceFirst('#', '');
  final parsed = int.tryParse(text, radix: 16);
  if (parsed == null) return SaydianColors.techBlue;
  return Color(text.length <= 6 ? 0xFF000000 | parsed : parsed);
}

Map<String, String> _careSummary(Map<String, Object?> item) {
  const labels = <String, String>{
    'latest': '最近',
    'num': '当前',
    'value': '当前',
    'max': '最高',
    'min': '最低',
    'avg': '平均',
    'bmi': 'BMI',
    'meanHeartRate': '平均心率',
    'averageTimeInterval': '平均间期',
    'deepSleep': '深睡',
    'lightSleep': '浅睡',
  };
  final result = <String, String>{};
  final unit = '${item['unit'] ?? ''}'.trim();
  for (final entry in labels.entries) {
    final value = item[entry.key];
    if (value != null && '$value'.trim().isNotEmpty) {
      final formatted = _careFieldValue(value);
      result[entry.value] = unit.isEmpty ? formatted : '$formatted $unit';
    }
  }
  final body = item['bodycomposition'];
  if (body is Map && body['BMI'] != null) {
    result['BMI'] = _careFieldValue(body['BMI']);
  }
  final ecg = item['ecgData'];
  if (ecg is Map) {
    if (ecg['meanHeartRate'] != null) {
      result['平均心率'] = _careFieldValue(ecg['meanHeartRate']);
    }
    if (ecg['averageTimeInterval'] != null) {
      result['平均间期'] = _careFieldValue(ecg['averageTimeInterval']);
    }
  }
  return result;
}

class _AddCareDialog extends StatefulWidget {
  const _AddCareDialog({required this.ownMobile});

  final String ownMobile;

  @override
  State<_AddCareDialog> createState() => _AddCareDialogState();
}

class _AddCareDialogState extends State<_AddCareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_mobileController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加关爱'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _mobileController,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: '对方手机号',
          hintText: '请输入手机号',
        ),
        validator: (value) {
          final mobile = value?.trim() ?? '';
          if (!RegExp(r'^\d{6,20}$').hasMatch(mobile)) {
            return '请输入正确的手机号';
          }
          if (widget.ownMobile.isNotEmpty && mobile == widget.ownMobile) {
            return '不能添加当前登录账号';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('发送')),
    ],
  );
}

Future<void> _showAddCareDialog(
  BuildContext context,
  AppController controller,
) async {
  final mobile = await showDialog<String>(
    context: context,
    builder: (_) => _AddCareDialog(
      ownMobile: '${controller.memberProfile['mobile'] ?? ''}'.trim(),
    ),
  );
  if (mobile == null || !context.mounted) return;

  final success = await controller.addCare(mobile);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success ? '关爱请求已发送' : controller.errorMessage ?? '发送失败'),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.memberProfile;
    final name =
        '${profile['nickname'] ?? controller.session?.displayName ?? (controller.isPreviewMode ? '体验用户' : '赛电用户')}';
    final memberId =
        '${profile['promo_code'] ?? controller.session?.memberId ?? '--'}';
    final avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
    return ListView(
      key: const Key('my-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (controller.isPreviewMode) ...[
          Material(
            key: const Key('preview-login-prompt'),
            color: SaydianColors.brandRedSoft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => unawaited(controller.logout()),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      color: SaydianColors.brandRed,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前为体验模式',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '登录后可保存健康数据、设备和订单信息',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '立即登录',
                      style: TextStyle(
                        color: SaydianColors.brandRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: SaydianColors.brandRed,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: () =>
              _openPage(context, ProfileEditPage(controller: controller)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8F3), Color(0xFFFFECEE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0x22A51125)),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x149E1025),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _MemberAvatar(imageUrl: avatarUrl, showEditBadge: true),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: SaydianColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        controller.session == null
                            ? '登录后开启云端健康服务'
                            : '会员 ID：$memberId',
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: SaydianColors.brandRed,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileStat(
                key: const Key('profile-stat-device'),
                icon: Icons.watch_outlined,
                label: '设备',
                value: controller.connectedDevice == null ? '未连接' : '在线',
                color: controller.connectedDevice == null
                    ? SaydianColors.muted
                    : SaydianColors.green,
                onTap: () => controller.selectTab(1),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProfileStat(
                key: const Key('profile-stat-health-records'),
                icon: Icons.monitor_heart_outlined,
                label: '健康记录',
                value: '${controller.healthRecords.length} 条',
                color: SaydianColors.brandRed,
                onTap: () => _openPage(
                  context,
                  AllHealthDataPage(controller: controller, title: '健康记录'),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProfileStat(
                key: const Key('profile-stat-care-members'),
                icon: Icons.family_restroom_rounded,
                label: '关爱成员',
                value: '${controller.careMembers.length} 人',
                color: SaydianColors.techBlue,
                onTap: () => _openPage(
                  context,
                  Scaffold(
                    appBar: AppBar(title: const Text('远程关爱')),
                    body: CarePage(controller: controller),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0x17344B7D)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      '我的订单',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openOrders(context, null),
                      child: const Text('全部'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _OrderEntry(
                        label: '待支付',
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: () => _openOrders(context, 0),
                      ),
                    ),
                    Expanded(
                      child: _OrderEntry(
                        label: '待发货',
                        icon: Icons.inventory_2_outlined,
                        onTap: () => _openOrders(context, 1),
                      ),
                    ),
                    Expanded(
                      child: _OrderEntry(
                        label: '待收货',
                        icon: Icons.local_shipping_outlined,
                        onTap: () => _openOrders(context, 2),
                      ),
                    ),
                    Expanded(
                      child: _OrderEntry(
                        label: '售后',
                        icon: Icons.support_agent_rounded,
                        onTap: () => _openPage(
                          context,
                          AfterSalesPage(controller: controller),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE8E8EC)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              if (controller.connectedDevice == null) ...[
                _MyQuickEntry(
                  key: const Key('my-add-device'),
                  title: '添加设备',
                  subtitle: '搜索并连接附近的赛电手表',
                  icon: Icons.watch_outlined,
                  color: SaydianColors.brandRed,
                  onTap: () => _openPage(
                    context,
                    DeviceSearchPage(controller: controller),
                  ),
                ),
                const Divider(height: 1, indent: 72),
              ],
              _MyQuickEntry(
                key: const Key('my-ai-question'),
                title: 'AI提问',
                subtitle: '向 AI 健康管家咨询健康问题',
                icon: Icons.chat_bubble_outline_rounded,
                color: SaydianColors.brandGoldDark,
                onTap: () => _openPage(
                  context,
                  AiChatPage(controller: controller, app: 1),
                ),
              ),
              const Divider(height: 1, indent: 72),
              _MyQuickEntry(
                title: '单位设置',
                subtitle: '设置距离、温度等数据单位',
                icon: Icons.straighten_rounded,
                color: SaydianColors.blue,
                onTap: () => _openPage(
                  context,
                  UnitSettingsPage(controller: controller),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0x17344B7D)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 14),
                    child: Text(
                      '我的服务',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                _MyServicesGrid(controller: controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openOrders(BuildContext context, int? status) {
    _openPage(
      context,
      OrdersPage(controller: controller, initialStatus: status),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.imageUrl,
    this.imageBytes,
    this.size = 66,
    this.showEditBadge = false,
    this.loading = false,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final double size;
  final bool showEditBadge;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [SaydianColors.brandRed, Color(0xFFE13045)],
        ),
      ),
      child: Icon(Icons.person_rounded, color: Colors.white, size: size * 0.52),
    );
    final bytes = imageBytes;
    final image = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover)
        : imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x33A51125), blurRadius: 12),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: image),
          ),
          if (showEditBadge)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x22A51125)),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: size * 0.18,
                  color: SaydianColors.brandRed,
                ),
              ),
            ),
          if (loading)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label，$value',
    hint: '点击查看$label',
    child: Container(
      constraints: const BoxConstraints(minHeight: 86),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAE5E2)),
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111827),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 23),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: Color(0xFFB1A9A5),
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

class _MyServicesGrid extends StatelessWidget {
  const _MyServicesGrid({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, IconData icon, Widget page})>[
      (
        label: '账号设置',
        icon: Icons.manage_accounts_outlined,
        page: AccountSettingsPage(controller: controller),
      ),
      (
        label: '权限管理',
        icon: Icons.admin_panel_settings_outlined,
        page: PermissionManagementPage(controller: controller),
      ),
      (
        label: '帮助反馈',
        icon: Icons.help_outline_rounded,
        page: FeedbackPage(controller: controller),
      ),
      (
        label: '联系客服',
        icon: Icons.headset_mic_outlined,
        page: const CustomerServicePage(),
      ),
      (
        label: '关于我们',
        icon: Icons.info_outline_rounded,
        page: AboutSaydianPage(controller: controller),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = textScale > 1.25 || constraints.maxWidth < 340 ? 3 : 5;
        final width = constraints.maxWidth / columns;
        return Wrap(
          alignment: WrapAlignment.start,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: _MyServiceEntry(
                  label: entry.label,
                  icon: entry.icon,
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => entry.page)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyQuickEntry extends StatelessWidget {
  const _MyQuickEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 12,
      leading: _SettingsIcon(icon: icon, color: color),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _OrderEntry extends StatelessWidget {
  const _OrderEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: SaydianColors.ink, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Retained for secondary settings layouts.
// ignore: unused_element
class _MySettingCard extends StatelessWidget {
  const _MySettingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _SettingsIcon(icon: icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyServiceEntry extends StatelessWidget {
  const _MyServiceEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF0EC), Color(0xFFFFF8DE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x22D20B27)),
              ),
              child: Icon(icon, color: SaydianColors.brandRedDark, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class AfterSalesPage extends StatefulWidget {
  const AfterSalesPage({
    required this.controller,
    this.order,
    this.orderNumber,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?>? order;
  final String? orderNumber;

  @override
  State<AfterSalesPage> createState() => _AfterSalesPageState();
}

class _AfterSalesPageState extends State<AfterSalesPage> {
  @override
  void initState() {
    super.initState();
    if (widget.order == null) unawaited(widget.controller.loadOrders(null));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('售后服务')),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final source = widget.order == null
            ? widget.controller.orders
            : [widget.order!];
        final eligible = source.where((order) {
          final status = int.tryParse('${order['order_status'] ?? ''}');
          return status != null && status > 0;
        }).toList();
        if (eligible.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => widget.controller.loadOrders(null),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(
                  Icons.support_agent_outlined,
                  size: 68,
                  color: SaydianColors.outline,
                ),
                SizedBox(height: 16),
                Text(
                  '暂无可申请售后的订单',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  '已付款订单可按商品提交退款或退货退款申请。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SaydianColors.muted),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _InlineNotice(
              message: '请选择需要售后的商品，并填写原因和申请金额。提交后可在订单列表查看处理状态。',
              icon: Icons.info_outline_rounded,
              color: SaydianColors.techBlue,
            ),
            const SizedBox(height: 12),
            for (final order in eligible) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '订单号 ${order['order_sn'] ?? widget.orderNumber ?? order['id'] ?? ''}',
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(height: 24),
                      for (final product in _orderProducts(order))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OrderProductImage(product: product),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${product['product_name'] ?? '商品'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${product['sku_name'] ?? ''}',
                                      style: const TextStyle(
                                        color: SaydianColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _openApply(context, order, product),
                                        child: Text(
                                          '${product['is_customer'] ?? 0}' ==
                                                  '1'
                                              ? '查看售后状态'
                                              : '申请售后',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    ),
  );

  List<Map<String, Object?>> _orderProducts(Map<String, Object?> order) {
    final raw = order['product'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  void _openApply(
    BuildContext context,
    Map<String, Object?> order,
    Map<String, Object?> product,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AfterSalesApplyPage(
          controller: widget.controller,
          order: order,
          product: product,
        ),
      ),
    );
  }
}

class _AfterSalesApplyPage extends StatefulWidget {
  const _AfterSalesApplyPage({
    required this.controller,
    required this.order,
    required this.product,
  });

  final AppController controller;
  final Map<String, Object?> order;
  final Map<String, Object?> product;

  @override
  State<_AfterSalesApplyPage> createState() => _AfterSalesApplyPageState();
}

class _AfterSalesApplyPageState extends State<_AfterSalesApplyPage> {
  final _reason = TextEditingController();
  late final TextEditingController _amount;
  int _refundType = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text:
          '${widget.product['product_money'] ?? widget.product['price'] ?? ''}',
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alreadyApplied = '${widget.product['is_customer'] ?? 0}' == '1';
    return Scaffold(
      appBar: AppBar(title: const Text('申请售后')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: _OrderProductImage(product: widget.product),
              title: Text('${widget.product['product_name'] ?? '商品'}'),
              subtitle: Text(
                '订单号 ${widget.order['order_sn'] ?? widget.order['id'] ?? ''}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (alreadyApplied)
            const _InlineNotice(
              message: '该商品已经提交售后申请，请等待商城工作人员处理。',
              icon: Icons.schedule_rounded,
              color: SaydianColors.orange,
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _refundType,
              decoration: const InputDecoration(labelText: '售后类型'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('仅退款')),
                DropdownMenuItem(value: 2, child: Text('退货退款')),
              ],
              onChanged: (value) => setState(() => _refundType = value ?? 1),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '申请金额'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '售后原因',
                hintText: '请说明遇到的问题',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '提交中…' : '提交申请'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final productId = int.tryParse('${widget.product['id'] ?? ''}');
    final amount = num.tryParse(_amount.text.trim());
    if (productId == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请检查商品和申请金额')));
      return;
    }
    setState(() => _submitting = true);
    final success = await widget.controller.applyOrderRefund(
      orderProductId: productId,
      refundType: _refundType,
      amount: amount,
      reason: _reason.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '售后申请已提交' : widget.controller.errorMessage ?? '提交失败',
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    required this.controller,
    required this.initialStatus,
    super.key,
  });

  final AppController controller;
  final int? initialStatus;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late int? _status;
  static const _filters = <(int?, String)>[
    (null, '全部'),
    (0, '待支付'),
    (1, '待发货'),
    (2, '待收货'),
    (3, '已完成'),
    (-1, '售后'),
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    unawaited(widget.controller.loadOrders(_status == -1 ? null : _status));
  }

  void _selectStatus(int? value) {
    if (_status == value) return;
    setState(() => _status = value);
    unawaited(widget.controller.loadOrders(value == -1 ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的订单')),
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  for (final filter in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.$2),
                        selected: _status == filter.$1,
                        showCheckmark: false,
                        onSelected: (_) => _selectStatus(filter.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final orders = _status == -1
                    ? widget.controller.orders.where((order) {
                        final status = int.tryParse(
                          '${order['order_status'] ?? ''}',
                        );
                        final products = order['product'];
                        final hasAfterSalesProduct =
                            products is List &&
                            products.whereType<Map>().any(
                              (product) =>
                                  '${product['is_customer'] ?? 0}' == '1',
                            );
                        return (status != null && status < 0) ||
                            '${order['is_customer'] ?? 0}' == '1' ||
                            hasAfterSalesProduct;
                      }).toList()
                    : widget.controller.orders;
                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => widget.controller.loadOrders(
                      _status == -1 ? null : _status,
                    ),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 110),
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 68,
                          color: SaydianColors.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.controller.orderStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => widget.controller.loadOrders(
                    _status == -1 ? null : _status,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _OrderCard(
                      controller: widget.controller,
                      order: orders[index],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.controller, required this.order});

  final AppController controller;
  final Map<String, Object?> order;

  @override
  Widget build(BuildContext context) {
    final products = order['product'] is List
        ? order['product'] as List
        : const [];
    final status = switch (int.tryParse('${order['order_status'] ?? ''}')) {
      0 => '待付款',
      1 => '待发货',
      2 => '待收货',
      3 => '已完成',
      4 => '已完成',
      -1 => '申请退款',
      -2 => '退款中',
      -3 => '已退款',
      _ => '订单处理中',
    };
    final statusColor = status.contains('退款') || status.contains('售后')
        ? SaydianColors.danger
        : status == '已完成'
        ? SaydianColors.success
        : SaydianColors.brandRed;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final id = int.tryParse('${order['id'] ?? ''}');
          if (id == null) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailPage(controller: controller, id: id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '订单号 ${order['order_sn'] ?? order['id'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              for (final product in products.whereType<Map>()) ...[
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrderProductImage(product: product),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product['product_name'] ?? product['title'] ?? '商品'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${product['sku_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Text(
                                '¥${product['price'] ?? product['product_money'] ?? '--'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '×${product['num'] ?? 1}',
                                style: const TextStyle(
                                  color: SaydianColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '共 ${products.length} 件',
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    const Text('实付款'),
                    Text(
                      '¥${order['pay_money'] ?? '--'}',
                      style: const TextStyle(
                        color: SaydianColors.brandRed,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderProductImage extends StatelessWidget {
  const _OrderProductImage({required this.product});

  final Map product;

  @override
  Widget build(BuildContext context) {
    final raw =
        product['product_picture'] ??
        product['cover'] ??
        product['image'] ??
        product['product_image'];
    final url = _normalizeArticleImageUrl('${raw ?? ''}');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 78,
        child: url.isEmpty
            ? const ColoredBox(
                color: SaydianColors.techBlueSoft,
                child: Icon(Icons.shopping_bag_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: SaydianColors.techBlueSoft,
                  child: Icon(Icons.shopping_bag_outlined),
                ),
              ),
      ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    required this.controller,
    required this.id,
    super.key,
  });

  final AppController controller;
  final int id;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, Object?> _order = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await widget.controller.loadOrderDetail(widget.id);
    if (mounted) {
      setState(() {
        _order = value;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _order['product'] is List
        ? _order['product'] as List
        : const [];
    final status = int.tryParse('${_order['order_status'] ?? ''}');
    final receiver = '${_order['receiver_name'] ?? _order['realname'] ?? '--'}';
    final mobile = '${_order['receiver_mobile'] ?? _order['mobile'] ?? '--'}';
    final region = '${_order['receiver_region_name'] ?? ''}'.trim();
    final address =
        '${_order['receiver_address'] ?? _order['address'] ?? '--'}';
    final orderNumber = '${_order['order_sn'] ?? widget.id}';
    return Scaffold(
      appBar: AppBar(title: const Text('订单详情')),
      backgroundColor: const Color(0xFFF7F4F1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_order.isEmpty)
                    const _InlineNotice(
                      message: '订单详情加载失败，请稍后重试。',
                      icon: Icons.error_outline_rounded,
                      color: SaydianColors.orange,
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9E1025), Color(0xFFD20B27)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            backgroundColor: Color(0x2AFFFFFF),
                            foregroundColor: Colors.white,
                            child: Icon(Icons.shopping_bag_outlined),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _orderStatusLabel(status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _orderStatusDescription(status),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: SaydianColors.brandRed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$receiver  $mobile',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    '$region$address',
                                    style: const TextStyle(
                                      color: SaydianColors.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          for (var index = 0; index < products.length; index++)
                            if (products[index] is Map) ...[
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _OrderProductImage(
                                      product: products[index] as Map,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${(products[index] as Map)['product_name'] ?? '商品'}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${(products[index] as Map)['sku_name'] ?? ''}',
                                            style: const TextStyle(
                                              color: SaydianColors.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '¥${(products[index] as Map)['product_money'] ?? (products[index] as Map)['price'] ?? '--'}',
                                                  style: const TextStyle(
                                                    color:
                                                        SaydianColors.brandRed,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '×${(products[index] as Map)['num'] ?? 1}',
                                                style: const TextStyle(
                                                  color: SaydianColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index != products.length - 1)
                                const Divider(height: 1, indent: 104),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _OrderAmountRow(
                              label: '商品金额',
                              value: '¥${_order['order_money'] ?? '--'}',
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            _OrderAmountRow(
                              label: '实付款',
                              value: '¥${_order['pay_money'] ?? '--'}',
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _OrderInfoRow(label: '订单编号', value: orderNumber),
                            const SizedBox(height: 10),
                            _OrderInfoRow(
                              label: '下单时间',
                              value: '${_order['created_at'] ?? '--'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (status != null && status > 0)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'after-sales',
                                ),
                                builder: (_) => AfterSalesPage(
                                  controller: widget.controller,
                                  order: _order,
                                  orderNumber: orderNumber,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.support_agent_outlined),
                            label: const Text('申请售后'),
                          ),
                        if (status != null && status >= 2)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShopExpressPage(
                                  controller: widget.controller,
                                  orderId: widget.id,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: const Text('查看物流'),
                          ),
                        if (status == 2)
                          FilledButton.icon(
                            key: const Key('confirm-order-receipt'),
                            onPressed: _confirmReceipt,
                            icon: const Icon(Icons.inventory_rounded),
                            label: const Text('确认收货'),
                          ),
                        if (status == 0)
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShopPaymentStatusPage(
                                  controller: widget.controller,
                                  orderId: widget.id,
                                  ordersPageBuilder: (_) => OrdersPage(
                                    controller: widget.controller,
                                    initialStatus: 0,
                                  ),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.payment_rounded),
                            label: const Text('查看支付状态'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _orderStatusLabel(int? status) => switch (status) {
    0 => '等待付款',
    1 => '等待发货',
    2 => '等待收货',
    3 => '交易完成',
    4 => '交易完成',
    _ => '${_order['order_status_name'] ?? '订单处理中'}',
  };

  String _orderStatusDescription(int? status) => switch (status) {
    0 => '请在订单有效期内完成支付',
    1 => '商家正在准备您的商品',
    2 => '商品已发出，请注意查收',
    3 => '感谢您使用赛电商城',
    4 => '感谢您使用赛电商城',
    _ => '订单状态以商城最新数据为准',
  };

  Future<void> _confirmReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认已经收到商品？'),
        content: const Text('确认收货后订单将完成。如尚未收到商品，请不要确认。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不确认'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认收货'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await widget.controller.confirmOrderReceipt(widget.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '已确认收货' : widget.controller.errorMessage ?? '确认收货失败',
        ),
      ),
    );
    if (success) await _load();
  }
}

class _OrderAmountRow extends StatelessWidget {
  const _OrderAmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value,
        style: TextStyle(
          color: emphasized ? SaydianColors.brandRed : SaydianColors.ink,
          fontSize: emphasized ? 19 : 15,
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ],
  );
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 78,
        child: Text(label, style: const TextStyle(color: SaydianColors.muted)),
      ),
      Expanded(child: SelectableText(value)),
    ],
  );
}

class UnitSettingsPage extends StatefulWidget {
  const UnitSettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<UnitSettingsPage> createState() => _UnitSettingsPageState();
}

class _UnitSettingsPageState extends State<UnitSettingsPage> {
  late String _distance = widget.controller.distanceUnit;
  late String _temperature = widget.controller.temperatureUnit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单位设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: RadioGroup<String>(
              groupValue: _distance,
              onChanged: (value) {
                setState(() => _distance = value!);
                widget.controller.setUnits(distance: value);
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: '公里',
                    title: Text('公里'),
                    subtitle: Text('距离使用 km'),
                  ),
                  RadioListTile<String>(
                    value: '英里',
                    title: Text('英里'),
                    subtitle: Text('距离使用 mi'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: RadioGroup<String>(
              groupValue: _temperature,
              onChanged: (value) {
                setState(() => _temperature = value!);
                widget.controller.setUnits(temperature: value);
              },
              child: const Column(
                children: [
                  RadioListTile<String>(value: '摄氏度（℃）', title: Text('摄氏度（℃）')),
                  RadioListTile<String>(value: '华氏度（℉）', title: Text('华氏度（℉）')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _InlineNotice(
            message: '单位选择会立即生效。重新安装应用后可能需要再次设置。',
            icon: Icons.info_outline_rounded,
            color: SaydianColors.blue,
          ),
        ],
      ),
    );
  }
}

class GoalSettingsPage extends StatefulWidget {
  const GoalSettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<GoalSettingsPage> createState() => _GoalSettingsPageState();
}

class _GoalSettingsPageState extends State<GoalSettingsPage> {
  late final TextEditingController _steps;
  late final TextEditingController _distance;
  late final TextEditingController _calories;

  @override
  void initState() {
    super.initState();
    _steps = TextEditingController(text: '${widget.controller.stepGoal}');
    _distance = TextEditingController(
      text: '${widget.controller.distanceGoal}',
    );
    _calories = TextEditingController(text: '${widget.controller.calorieGoal}');
  }

  @override
  void dispose() {
    _steps.dispose();
    _distance.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final steps = int.tryParse(_steps.text);
    final distance = double.tryParse(_distance.text);
    final calories = int.tryParse(_calories.text);
    if (steps == null ||
        distance == null ||
        calories == null ||
        steps <= 0 ||
        distance <= 0 ||
        calories <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的目标数值')));
      return;
    }
    final saved = await widget.controller.saveActivityGoals(
      steps: steps,
      distance: distance,
      calories: calories,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? '目标已保存' : widget.controller.errorMessage ?? '保存失败',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('目标设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _steps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '每日步数目标（步）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '每日距离目标（公里）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _calories,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '每日热量目标（千卡）'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.controller.isBusy ? null : _save,
            child: const Text('保存目标'),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileEditPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('个人资料'),
                  subtitle: const Text('昵称、性别、生日、身高和体重'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ShopAddressBookPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('收货地址'),
                  subtitle: const Text('查看账号中的收货地址'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'reset-password'),
                      builder: (_) =>
                          PasswordRecoveryPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('重置密码'),
                  subtitle: const Text('验证手机号后重新设置登录密码'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArticleDetailPage(
                        controller: controller,
                        article: const {'id': 3, 'title': '隐私协议'},
                        singleArticle: true,
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私协议'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('account-logout'),
            onPressed: controller.isBusy
                ? null
                : () async {
                    await controller.logout();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
            child: Text(controller.isPreviewMode ? '退出体验' : '退出登录'),
          ),
          TextButton(
            onPressed: controller.session == null
                ? null
                : () => _confirmDeleteAccount(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('注销账号'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销账号？'),
        content: const Text('账号及相关数据删除成功后，本机会退出登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAccount();
  }
}

class AddressPage extends StatefulWidget {
  const AddressPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收货地址')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final addresses = widget.controller.addresses;
          if (addresses.isEmpty) {
            return const Center(
              child: Text(
                '暂无收货地址',
                style: TextStyle(color: SaydianColors.muted),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.loadAddresses,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const CircleAvatar(
                      child: Icon(Icons.location_on_outlined),
                    ),
                    title: Text(
                      '${address['realname'] ?? ''}  ${address['mobile'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${address['address_name'] ?? address['region'] ?? ''}'
                        '${address['address_details'] ?? ''}',
                      ),
                    ),
                    trailing: '${address['is_default']}' == '1'
                        ? const Chip(label: Text('默认'))
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nickname;
  late final TextEditingController _birthday;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late int _gender;
  late String _avatarUrl;
  Uint8List? _avatarBytes;
  String? _avatarFilePath;
  bool _isPickingAvatar = false;
  bool _isLoadingProfile = false;
  bool _profileEdited = false;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.memberProfile;
    _nickname = TextEditingController(text: '${profile['nickname'] ?? ''}');
    _birthday = TextEditingController(text: '${profile['birthday'] ?? ''}');
    _height = TextEditingController(text: '${profile['height'] ?? ''}');
    _weight = TextEditingController(text: '${profile['weight'] ?? ''}');
    _gender = int.tryParse('${profile['gender'] ?? 1}') ?? 1;
    _avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadLatestProfile());
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _birthday.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final initial = DateTime.tryParse(_birthday.text) ?? DateTime(1990);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _profileEdited = true;
      _birthday.text = DateFormat('yyyy-MM-dd').format(selected);
    }
  }

  Future<void> _loadLatestProfile() async {
    if (widget.controller.session == null || _isLoadingProfile) return;
    setState(() {
      _isLoadingProfile = true;
      _profileLoadError = null;
    });
    await widget.controller.refreshMemberProfile();
    if (!mounted) return;
    final profile = widget.controller.memberProfile;
    setState(() {
      _isLoadingProfile = false;
      if (profile.isEmpty) {
        _profileLoadError = widget.controller.errorMessage ?? '个人资料读取失败，请稍后重试';
        return;
      }
      if (_profileEdited) return;
      _nickname.text = '${profile['nickname'] ?? ''}';
      _birthday.text = '${profile['birthday'] ?? ''}';
      _height.text = '${profile['height'] ?? ''}';
      _weight.text = '${profile['weight'] ?? ''}';
      _gender = int.tryParse('${profile['gender'] ?? 1}') ?? 1;
      if (_avatarFilePath == null) {
        _avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
      }
    });
  }

  void _markProfileEdited(String _) {
    _profileEdited = true;
  }

  Future<void> _pickAvatar() async {
    if (widget.controller.session == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录后可更换头像')));
      return;
    }
    setState(() => _isPickingAvatar = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 6 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片过大，请选择较小的照片')));
        return;
      }
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarFilePath = image.path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法读取照片，请检查相册权限后重试')));
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (_isPickingAvatar) return;
    final height = double.tryParse(_height.text);
    final weight = double.tryParse(_weight.text);
    if (_nickname.text.trim().isEmpty ||
        _birthday.text.isEmpty ||
        height == null ||
        height < 50 ||
        height > 300 ||
        weight == null ||
        weight < 10 ||
        weight > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写资料，身高 50~300 cm、体重 10~500 kg')),
      );
      return;
    }
    final saved = await widget.controller.saveMemberProfile(
      nickname: _nickname.text.trim(),
      gender: _gender,
      birthday: _birthday.text,
      height: height,
      weight: weight,
      avatarFilePath: _avatarFilePath,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? '个人资料已保存' : widget.controller.errorMessage ?? '保存失败',
        ),
      ),
    );
    if (saved) Navigator.of(context).pop();
  }

  Future<void> _logout() async {
    final isPreview = widget.controller.isPreviewMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPreview ? '退出体验？' : '退出登录？'),
        content: Text(isPreview ? '退出后将返回登录页面。' : '确认退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: '更换头像',
              child: GestureDetector(
                key: const Key('profile-avatar-picker'),
                onTap: _isPickingAvatar ? null : _pickAvatar,
                child: _MemberAvatar(
                  imageUrl: _avatarUrl,
                  imageBytes: _avatarBytes,
                  size: 94,
                  showEditBadge: true,
                  loading: _isPickingAvatar,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _avatarFilePath == null ? '点击头像更换照片' : '已选择新头像，保存后生效',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted),
          ),
          if (_isLoadingProfile) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              '正在读取个人资料…',
              textAlign: TextAlign.center,
              style: TextStyle(color: SaydianColors.muted),
            ),
          ] else if (_profileLoadError case final message?) ...[
            const SizedBox(height: 14),
            _InlineNotice(
              message: message,
              icon: Icons.info_outline_rounded,
              color: SaydianColors.warning,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadLatestProfile,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新读取'),
              ),
            ),
          ],
          const SizedBox(height: 22),
          TextField(
            key: const Key('profile-nickname'),
            controller: _nickname,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            decoration: const InputDecoration(labelText: '昵称'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: '性别'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('男')),
              DropdownMenuItem(value: 2, child: Text('女')),
            ],
            onChanged: _isLoadingProfile
                ? null
                : (value) => setState(() {
                    _profileEdited = true;
                    _gender = value ?? 1;
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-birthday'),
            controller: _birthday,
            readOnly: true,
            enabled: !_isLoadingProfile,
            onTap: _isLoadingProfile ? null : _selectBirthday,
            decoration: const InputDecoration(
              labelText: '出生日期',
              suffixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-height'),
            controller: _height,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '身高（cm）'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-weight'),
            controller: _weight,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '体重（kg）'),
          ),
          const SizedBox(height: 18),
          const _InlineNotice(
            message: '头像和个人资料会在点击保存后同步到账号，用于个人中心和远程关爱成员识别。',
            icon: Icons.privacy_tip_outlined,
            color: SaydianColors.blue,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('profile-save'),
            onPressed:
                widget.controller.isBusy ||
                    _isPickingAvatar ||
                    _isLoadingProfile
                ? null
                : _save,
            child: Text(_isPickingAvatar ? '正在读取照片' : '保存资料'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('profile-logout'),
            onPressed: widget.controller.isBusy ? null : _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: SaydianColors.danger,
              side: const BorderSide(color: Color(0x55C6283F)),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(widget.controller.isPreviewMode ? '退出体验' : '退出登录'),
          ),
        ],
      ),
    );
  }
}

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({
    required this.controller,
    this.healthOnly = false,
    super.key,
  });

  final AppController controller;
  final bool healthOnly;

  @override
  State<PermissionManagementPage> createState() =>
      _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage>
    with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _statuses = const {};

  List<Permission> get _permissions =>
      defaultTargetPlatform == TargetPlatform.android
      ? [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
          Permission.notification,
          Permission.photos,
          Permission.camera,
          Permission.contacts,
        ]
      : [
          Permission.bluetooth,
          Permission.locationWhenInUse,
          Permission.notification,
          Permission.photos,
          Permission.camera,
          Permission.contacts,
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.healthOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.refreshDeviceSettings());
      });
    } else {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !widget.healthOnly) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final permission in _permissions) {
      statuses[permission] = await permission.status;
    }
    if (mounted) setState(() => _statuses = statuses);
  }

  Future<void> _request(Permission permission) async {
    if (permission == Permission.notification) {
      await openAppSettings();
    } else {
      await permission.request();
    }
    await _refresh();
  }

  String _name(Permission permission) {
    if (permission == Permission.bluetoothScan) return '附近设备扫描';
    if (permission == Permission.bluetoothConnect) return '蓝牙设备连接';
    if (permission == Permission.bluetooth) return '蓝牙';
    if (permission == Permission.locationWhenInUse) return '位置';
    if (permission == Permission.photos) return '照片';
    if (permission == Permission.camera) return '相机';
    if (permission == Permission.contacts) return '联系人';
    return '通知';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.healthOnly ? '健康监测' : '权限管理')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.healthOnly) ..._healthMonitoringContent(),
            if (!widget.healthOnly) ...[
              const SizedBox(height: 20),
              const Text(
                'App 系统权限',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final permission in _permissions) ...[
                      ListTile(
                        leading: Icon(
                          _statuses[permission]?.isGranted == true
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: _statuses[permission]?.isGranted == true
                              ? SaydianColors.green
                              : SaydianColors.orange,
                        ),
                        title: Text(_name(permission)),
                        subtitle: Text(
                          _statuses[permission]?.isGranted == true
                              ? '已允许'
                              : '未允许',
                        ),
                        trailing: TextButton(
                          onPressed: () => _request(permission),
                          child: const Text('设置'),
                        ),
                      ),
                      if (permission != _permissions.last)
                        const Divider(indent: 56),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('打开系统应用设置'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deviceAutoSwitch({
    required String type,
    required String title,
    required IconData icon,
  }) {
    final settings = widget.controller.autoMeasureSettings;
    final enabled = settings[type] ?? false;
    final interval = widget.controller.autoMeasureIntervals[type];
    return Column(
      children: [
        SwitchListTile(
          key: ValueKey('device-health-auto-$type'),
          secondary: Icon(icon, color: SaydianColors.pink),
          title: Text(title),
          subtitle: Text(enabled ? '已开启' : '已关闭'),
          value: enabled,
          onChanged:
              widget.controller.connectedDevice == null ||
                  widget.controller.isDeviceSettingsLoading
              ? null
              : (value) {
                  unawaited(
                    widget.controller.setAutoMeasureSetting(type, value),
                  );
                },
        ),
        if (interval != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '监测间隔',
                    style: TextStyle(color: SaydianColors.muted),
                  ),
                ),
                if (interval.canModify)
                  DropdownButton<int>(
                    key: ValueKey('device-health-interval-$type'),
                    value: interval.minutes > 0 ? interval.minutes : null,
                    hint: const Text('请选择'),
                    items: [
                      for (final minutes in interval.choices)
                        DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes 分钟'),
                        ),
                    ],
                    onChanged:
                        !enabled || widget.controller.isDeviceSettingsLoading
                        ? null
                        : (minutes) {
                            if (minutes != null) {
                              unawaited(
                                widget.controller.setAutoMeasureInterval(
                                  type,
                                  minutes,
                                ),
                              );
                            }
                          },
                  )
                else
                  Text(
                    interval.minutes > 0
                        ? '每 ${interval.minutes} 分钟（手表固定）'
                        : '手表固定',
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _healthMonitoringContent() {
    final controller = widget.controller;
    final settings = controller.autoMeasureSettings;
    const specs = <({String type, String title, IconData icon})>[
      (
        type: 'heartRate',
        title: '心率自动检测',
        icon: Icons.favorite_outline_rounded,
      ),
      (type: 'bloodPressure', title: '血压自动检测', icon: Icons.speed_rounded),
      (type: 'bloodGlucose', title: '血糖自动检测', icon: Icons.water_drop_outlined),
      (
        type: 'bodyTemperature',
        title: '体温自动检测',
        icon: Icons.thermostat_rounded,
      ),
      (type: 'hrv', title: 'HRV 自动检测', icon: Icons.monitor_heart_outlined),
    ];
    final tiles = <Widget>[];

    void addTile(Widget tile) {
      if (tiles.isNotEmpty) tiles.add(const Divider(indent: 56));
      tiles.add(tile);
    }

    for (final spec in specs) {
      if (!settings.containsKey(spec.type)) continue;
      addTile(
        _deviceAutoSwitch(type: spec.type, title: spec.title, icon: spec.icon),
      );
      if (spec.type == 'heartRate' && controller.heartRateWarningSupported) {
        addTile(_heartRateWarningTile());
      }
    }
    if (controller.heartRateWarningSupported &&
        !settings.containsKey('heartRate')) {
      addTile(_heartRateWarningTile());
    }

    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              '手表健康检测',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed:
                controller.connectedDevice == null ||
                    controller.isDeviceSettingsLoading
                ? null
                : controller.refreshDeviceSettings,
            tooltip: '从手表刷新',
            icon: controller.isDeviceSettingsLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      Text(
        controller.deviceSettingsStatus,
        style: const TextStyle(color: SaydianColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (controller.connectedDevice == null)
        const FeatureStateCard(
          message: '连接手表后使用',
          detail: '连接后会显示当前手表可设置的健康检测项目。',
          icon: Icons.watch_outlined,
        )
      else if (tiles.isEmpty)
        FeatureStateCard(
          message: controller.deviceSettingsStatus,
          detail: '没有读取到可设置项目，可重新读取手表设置。',
          icon: Icons.monitor_heart_outlined,
          actionLabel: controller.isDeviceSettingsLoading ? null : '重新读取',
          onAction: controller.isDeviceSettingsLoading
              ? null
              : controller.refreshDeviceSettings,
        )
      else
        Card(child: Column(children: tiles)),
    ];
  }

  Widget _heartRateWarningTile() => ListTile(
    key: const ValueKey('device-health-heart-warning'),
    leading: const Icon(
      Icons.warning_amber_rounded,
      color: SaydianColors.orange,
    ),
    title: const Text('心率过高预警'),
    subtitle: const Text('达到阈值后由手表提醒'),
    trailing: DropdownButton<int>(
      value: widget.controller.heartRateWarning,
      items: [
        for (var value = 70; value < 190; value += 5)
          DropdownMenuItem(value: value, child: Text('$value 次/分')),
      ],
      onChanged:
          widget.controller.connectedDevice == null ||
              widget.controller.isDeviceSettingsLoading
          ? null
          : (value) {
              if (value != null) {
                unawaited(widget.controller.setHeartRateWarning(value));
              }
            },
    ),
  );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

// Retained for secondary status layouts.
// ignore: unused_element
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(message),
        trailing: action,
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    this.compact = false,
    this.legal = false,
    this.centered = false,
    this.onTap,
  });

  final String message;
  final IconData icon;
  final Color color;
  final bool compact;
  final bool legal;
  final bool centered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padding = legal || compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(14);
    final borderRadius = BorderRadius.circular(compact || legal ? 10 : 14);
    final decoration = BoxDecoration(
      color: color.withValues(alpha: legal ? 0.05 : 0.08),
      border: Border.all(color: color.withValues(alpha: legal ? 0.15 : 0.24)),
      borderRadius: borderRadius,
    );
    final text = Text(
      message,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: color,
        fontSize: centered
            ? 15
            : legal
            ? 12
            : compact
            ? 12.5
            : null,
        fontWeight: centered ? FontWeight.w600 : null,
        height: centered
            ? 1.35
            : legal
            ? 1.4
            : compact
            ? 1.3
            : 1.45,
      ),
    );
    final content = Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: compact || legal ? 16 : 20),
        SizedBox(width: compact || legal ? 7 : 10),
        if (centered) Flexible(child: text) else Expanded(child: text),
      ],
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: content,
      );
    }
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: content),
          ),
        ),
      ),
    );
  }
}
