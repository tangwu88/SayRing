import 'package:flutter/material.dart';

import '../domain/sleep_timeline.dart';
import 'app_theme.dart';
import 'sleep_detail_widgets.dart';

/// Public, account-free review access. All content is synthetic and stays in
/// memory. Never pass an AppController, repository or wearable bridge here.
class ReviewDemoPage extends StatefulWidget {
  const ReviewDemoPage({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  State<ReviewDemoPage> createState() => _ReviewDemoPageState();
}

class _ReviewDemoPageState extends State<ReviewDemoPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('review-demo-page'),
    appBar: AppBar(
      title: const Text('Say Ring · 只读演示'),
      actions: [
        TextButton(
          key: const Key('review-demo-exit'),
          onPressed: widget.onExit,
          child: const Text('退出演示'),
        ),
      ],
    ),
    body: Column(
      children: [
        const _DemoNotice(),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _DemoHealthPage(onOpen: _open),
              _DemoDevicePage(onOpen: _open),
              _DemoProfilePage(onOpen: _open, onExit: widget.onExit),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.favorite_outline), label: '健康'),
        NavigationDestination(icon: Icon(Icons.circle_outlined), label: '设备'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
      ],
    ),
  );

  void _open(String title, Widget child) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(
          children: [
            const _DemoNotice(),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('review-demo-disclaimer'),
    width: double.infinity,
    color: SaydianColors.techBlueSoft,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: const Row(
      children: [
        Icon(
          Icons.visibility_outlined,
          size: 20,
          color: SaydianColors.techBlue,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '只读演示 · 所有数值均为虚构示例，非戒指测量',
            style: TextStyle(
              color: SaydianColors.techBlueDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DemoHealthPage extends StatelessWidget {
  const _DemoHealthPage({required this.onOpen});

  final void Function(String title, Widget child) onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('review-demo-health'),
    padding: const EdgeInsets.all(16),
    children: [
      Text('健康概览', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text('了解佩戴戒指后可查看的健康与睡眠记录。'),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          key: const Key('review-demo-sleep'),
          leading: const Icon(
            Icons.bedtime_outlined,
            color: SaydianColors.techIndigo,
          ),
          title: const Text('睡眠详情'),
          subtitle: const Text('夜间睡眠 7小时50分 · 含阶段时间轴与小睡'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpen(
            '睡眠详情 · 示例',
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('示例日期：2026年10月1日'),
                const Text('阶段和时间点可展开查看；真实数据以戒指同步结果为准。'),
                const SizedBox(height: 8),
                SleepTimelineCard(
                  timeline: reviewDemoSleepTimeline,
                  isDemo: true,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text('近期数据 · 示例', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final metric in _demoMetrics)
        Card(
          child: ListTile(
            key: Key('review-demo-metric-${metric.key}'),
            leading: Icon(metric.icon, color: SaydianColors.techIndigo),
            title: Text(metric.title),
            subtitle: const Text('示例记录 · 非实时测量'),
            trailing: Text(
              metric.value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            onTap: () => onOpen(
              '${metric.title} · 示例',
              _DemoMetricDetail(metric: metric),
            ),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        '本应用记录健康趋势，不用于疾病诊断、治疗或紧急情况处理。',
        style: TextStyle(color: SaydianColors.muted),
      ),
    ],
  );
}

class _DemoMetric {
  const _DemoMetric(this.key, this.title, this.value, this.icon, this.unit);

  final String key;
  final String title;
  final String value;
  final IconData icon;
  final String unit;
}

const _demoMetrics = [
  _DemoMetric('heart', '心率', '72 bpm', Icons.favorite_outline, '次/分钟'),
  _DemoMetric('oxygen', '血氧', '98%', Icons.water_drop_outlined, '%'),
  _DemoMetric('steps', '步数', '8,250 步', Icons.directions_walk, '步'),
];

class _DemoMetricDetail extends StatelessWidget {
  const _DemoMetricDetail({required this.metric});

  final _DemoMetric metric;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(metric.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                metric.value,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: SaydianColors.techIndigo,
                ),
              ),
              Text('单位：${metric.unit} · 演示数值'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('正式使用时如何获取数据'),
        subtitle: Text('登录后绑定兼容戒指，完成设备握手与同步，才能查看自己的记录。'),
      ),
    ],
  );
}

class _DemoDevicePage extends StatelessWidget {
  const _DemoDevicePage({required this.onOpen});

  final void Function(String title, Widget child) onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('review-demo-device'),
    padding: const EdgeInsets.all(16),
    children: [
      Text('设备', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Card(
        child: ListTile(
          leading: Icon(Icons.circle_outlined),
          title: Text('R21 智能戒指 · 兼容设备示意'),
          subtitle: Text('未连接；演示模式不申请蓝牙权限，也不搜索或连接设备。'),
        ),
      ),
      Card(
        child: ListTile(
          key: const Key('review-demo-device-guide'),
          leading: const Icon(Icons.bluetooth_searching),
          title: const Text('了解连接流程'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpen(
            '连接戒指 · 流程说明',
            ListView(
              padding: EdgeInsets.all(20),
              children: [
                ListTile(
                  title: Text('1. 登录并允许蓝牙'),
                  subtitle: Text('真实连接仅在已登录的正式模式中提供。'),
                ),
                ListTile(
                  title: Text('2. 选择身边的兼容戒指'),
                  subtitle: Text('App 必须完成厂商 SDK 握手和能力读取。'),
                ),
                ListTile(
                  title: Text('3. 同步与恢复'),
                  subtitle: Text('保存绑定后，戒指重新靠近时尝试自动连接；实际结果依赖系统与设备状态。'),
                ),
                SizedBox(height: 12),
                Text('此页面是流程说明，不代表已完成任何真实连接。'),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text('设备设置、测量和同步在只读演示中不可操作。真实流程另附实体戒指录屏供审核。'),
    ],
  );
}

class _DemoProfilePage extends StatelessWidget {
  const _DemoProfilePage({required this.onOpen, required this.onExit});

  final void Function(String title, Widget child) onOpen;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('review-demo-profile'),
    padding: const EdgeInsets.all(16),
    children: [
      const Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text('演示用户'),
          subtitle: Text('没有真实账号、头像、手机号或健康数据'),
        ),
      ),
      Card(
        child: ListTile(
          key: const Key('review-demo-profile-guide'),
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('资料与账号管理'),
          subtitle: const Text('查看昵称、头像和注销功能的位置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpen(
            '资料与账号 · 流程说明',
            ListView(
              padding: EdgeInsets.all(20),
              children: [
                ListTile(
                  title: Text('个人资料'),
                  subtitle: Text('登录后可在“我的 → 个人资料”修改昵称和头像。'),
                ),
                ListTile(
                  title: Text('注销账号'),
                  subtitle: Text('登录后可在“我的 → 账号与安全”发起注销；演示模式没有可注销的账号。'),
                ),
                ListTile(
                  title: Text('隐私与支持'),
                  subtitle: Text('登录页可查看用户协议与隐私政策；“我的”页面可联系客户服务。'),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const Key('review-demo-sign-in'),
        onPressed: onExit,
        child: const Text('退出演示并登录'),
      ),
    ],
  );
}

/// Deterministic, synthetic example only. Never persist or upload this value.
final SleepTimeline reviewDemoSleepTimeline = _buildReviewDemoSleepTimeline();

SleepTimeline _buildReviewDemoSleepTimeline() {
  final night = DateTime.utc(2026, 9, 30, 14, 45);
  SleepStageSegment segment(int start, int end, SleepStage stage) =>
      SleepStageSegment(
        startAt: night.add(Duration(minutes: start)),
        endAt: night.add(Duration(minutes: end)),
        stage: stage,
        rawStage: -1,
      );
  return SleepTimeline(
    deviceId: 'demo-only-no-device',
    sdkDate: '2026-10-01',
    timezone: '+08:00',
    readAt: DateTime.utc(2026, 10, 1, 8),
    sessions: [
      SleepSession(
        kind: SleepSessionKind.night,
        segments: [
          segment(0, 25, SleepStage.light),
          segment(25, 115, SleepStage.deep),
          segment(115, 210, SleepStage.light),
          segment(210, 275, SleepStage.rem),
          segment(275, 290, SleepStage.awake),
          segment(290, 365, SleepStage.light),
          segment(365, 415, SleepStage.deep),
          segment(415, 455, SleepStage.rem),
          segment(455, 485, SleepStage.light),
        ],
      ),
      SleepSession(
        kind: SleepSessionKind.nap,
        segments: [
          segment(875, 895, SleepStage.light),
          segment(895, 905, SleepStage.rem),
        ],
      ),
    ],
  );
}
