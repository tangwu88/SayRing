part of '../pages.dart';

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
    if (widget.controller.isGlobalEdition) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.refreshCare());
      unawaited(widget.controller.refreshCareInvitations());
    });
  }

  @override
  Widget build(BuildContext context) => widget.controller.isGlobalEdition
      ? GlobalCarePage(controller: widget.controller)
      : ListenableBuilder(
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
                        colors: [
                          SaydianColors.techBlue,
                          SaydianColors.techIndigo,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x30316EF5),
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
                                  color: Color(0xFFDDEBFF),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          tooltip: '添加关爱',
                          onPressed:
                              controller.session == null ||
                                  controller.isPreviewMode
                              ? null
                              : () => _showAddCareDialog(context, controller),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: SaydianColors.techBlue,
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
                                builder: (_) => SharingManagementPage(
                                  controller: controller,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 76,
                          child: VerticalDivider(width: 1),
                        ),
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
                  Text(
                    context.l10n.careMembers,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (controller.careMembers.isEmpty)
                    _CareMembersStateCard(
                      status: controller.careStatus,
                      errorMessage: controller.careErrorMessage,
                      isPreviewMode: controller.isPreviewMode,
                      canAdd:
                          controller.session != null &&
                          !controller.isPreviewMode,
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
                              imageUrl: '${member['head_portrait'] ?? ''}'
                                  .trim(),
                              size: 46,
                            ),
                            title: Text(
                              '${member['nickname'] ?? member['mobile'] ?? '关爱成员'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${member['mobile'] ?? '手机号未提供'}\n点击查看实时健康数据',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      ),
                  const SizedBox(height: 4),
                  const InlineNotice(
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
                  label: Text(context.l10n.reload),
                )
              else
                FilledButton.icon(
                  onPressed: canAdd ? onAdd : null,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(context.l10n.addCare),
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
                    InlineNotice(
                      message: loadError,
                      icon: Icons.cloud_off_outlined,
                      color: SaydianColors.orange,
                    )
                  else if (_data.isEmpty)
                    const InlineNotice(
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
                      const InlineNotice(
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
    final unauthorized = item['state'] == 'unauthorized';
    final tips = unauthorized
        ? '对方未授权此项目'
        : '${item['tips'] ?? item['tip'] ?? ''}'.trim();
    final summary = unauthorized
        ? const <String, String>{}
        : _careSummary(item);
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
                      unauthorized
                          ? Icons.lock_outline
                          : unavailable
                          ? Icons.cloud_off_outlined
                          : Icons.monitor_heart_outlined,
                      color: unauthorized
                          ? SaydianColors.muted
                          : unavailable
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
    final unauthorized = state == 'unauthorized';
    final tips = unauthorized ? '对方未授权此项目' : '${item['tips'] ?? ''}'.trim();
    final metricUnit = '${item['unit'] ?? ''}'.trim();
    final rawRecords = unauthorized ? const <Object?>[] : item['records'];
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
    final summary = _careMetricDaySummary(
      title,
      records,
      normalizedLatest: item['latest'],
    );
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
            InlineNotice(
              message: tips.isNotEmpty ? tips : '这一天没有可展示的明细记录。',
              icon: unauthorized
                  ? Icons.lock_outline
                  : state == 'unavailable'
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
          Text(
            context.l10n.dailySummary,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
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
                Text(
                  context.l10n.remoteMemberData,
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
              InlineNotice(
                message: context.l10n.ecgWaveformUnavailable,
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
  List<Map<String, Object?>> records, {
  Object? normalizedLatest,
}) {
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
    final latest = _careMetricPressurePair({'bloodPressure': normalizedLatest});
    final displayedLatest = latest ?? values.last;
    result['最近'] = pair(displayedLatest.$1, displayedLatest.$2);
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
  result['最近'] = format(
    _carePositiveDisplayNumber(normalizedLatest) ?? values.last,
  );
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
    title: Text(context.l10n.addCare),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _mobileController,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '对方手机号',
          hintText: context.l10n.enterPhone,
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
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.send)),
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
