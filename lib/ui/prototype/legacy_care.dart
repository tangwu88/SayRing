part of '../prototype_pages.dart';

class SharingManagementPage extends StatelessWidget {
  const SharingManagementPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final targets = <Map<String, Object?>>[];
    final seenMemberIds = <int>{};
    for (final invitation in controller.careInvitations) {
      final status = int.tryParse('${invitation['examine_status'] ?? 0}') ?? 0;
      final inviterId = int.tryParse('${invitation['inviter_id'] ?? 0}') ?? 0;
      if (status != 1 || inviterId <= 0 || !seenMemberIds.add(inviterId)) {
        continue;
      }
      final rawMember = invitation['member'];
      final member = rawMember is Map
          ? rawMember.map(
              (key, value) => MapEntry<String, Object?>('$key', value),
            )
          : const <String, Object?>{};
      targets.add({
        'member_id': inviterId,
        'nickname': '${member['nickname'] ?? ''}'.trim(),
        'mobile': '${member['mobile'] ?? ''}'.trim(),
        'head_portrait': '${member['head_portrait'] ?? ''}'.trim(),
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(uiCopy(context, "共享管理"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FeatureStateCard(
            message: uiCopy(context, "默认不共享任何健康数据"),
            detail: uiCopy(context, "家人接受邀请并选择允许的健康项目后，对方才能查看。"),
            icon: Icons.privacy_tip_outlined,
            color: SaydianColors.green,
          ),
          const SizedBox(height: 14),
          if (targets.isEmpty)
            FeatureStateCard(
              message: uiCopy(context, "暂无需要授权的关爱人"),
              detail: uiCopy(context, "收到并同意家人的关爱邀请后，可在这里选择允许对方查看的健康项目。"),
              icon: Icons.group_outlined,
            )
          else
            for (final member in targets)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () {
                    final memberId = int.tryParse(
                      '${member['member_id'] ?? 0}',
                    );
                    if (memberId == null || memberId == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(uiCopy(context, "成员信息不完整，暂时无法设置共享项目")),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CareShareSettingsPage(
                          controller: controller,
                          member: member,
                          memberId: memberId,
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    foregroundImage:
                        '${member['head_portrait'] ?? ''}'.startsWith('http')
                        ? SafeNetworkImageProvider('${member['head_portrait']}')
                        : null,
                    child: const Icon(Icons.person_outline),
                  ),
                  title: Text(
                    '${member['nickname'] ?? ''}'.trim().isNotEmpty
                        ? '${member['nickname']}'.trim()
                        : uiCopy(context, "关爱邀请人"),
                  ),
                  subtitle: Text(
                    '${member['mobile'] ?? ''}'.trim().isNotEmpty
                        ? uiCopy(
                            context,
                            "{p0} · 设置允许查看的健康项目",
                            parameters: [member['mobile']],
                          )
                        : uiCopy(
                            context,
                            "邀请人账号 ID：{p0} · 设置允许查看的健康项目",
                            parameters: [member['member_id']],
                          ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
        ],
      ),
    );
  }
}

class CareShareSettingsPage extends StatefulWidget {
  const CareShareSettingsPage({
    required this.controller,
    required this.member,
    required this.memberId,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?> member;
  final int memberId;

  @override
  State<CareShareSettingsPage> createState() => _CareShareSettingsPageState();
}

class _CareShareSettingsPageState extends State<CareShareSettingsPage> {
  Map<String, String> get _dailyKeys => <String, String>{
    'steps': uiCopy(context, "步数"),
    'reliang': uiCopy(context, "卡路里"),
    'juli': uiCopy(context, "距离"),
    'sleep': uiCopy(context, "总睡眠"),
  };
  Map<String, String> get _healthKeys => <String, String>{
    'bloodPressure': uiCopy(context, "血压"),
    'bloodGlucose': uiCopy(context, "血糖"),
    'bloodOxygen': uiCopy(context, "血氧"),
    'bodyTemperature': uiCopy(context, "体温"),
    'ecg': uiCopy(context, "心电图"),
    'heartReat': uiCopy(context, "心率"),
    'HRV': 'HRV',
    'bodycomposition': uiCopy(context, "身体成分"),
    'bloodcomposition': uiCopy(context, "血液成分"),
  };

  Set<String> _enabled = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late final int _sessionGeneration;
  int _requestGeneration = 0;
  bool _sessionChanged = false;

  bool get _sessionCurrent =>
      !_sessionChanged &&
      widget.controller.isCareShareSessionCurrent(_sessionGeneration);

  bool get _canEdit =>
      _sessionCurrent && !_loading && !_saving && _error == null;

  @override
  void initState() {
    super.initState();
    _sessionGeneration = widget.controller.careShareSessionGeneration;
    widget.controller.addListener(_onSessionChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted || _sessionChanged || _sessionCurrent) return;
    setState(() {
      _sessionChanged = true;
      _requestGeneration++;
      _loading = false;
      _saving = false;
    });
  }

  bool _isCurrentRequest(int generation) =>
      mounted && _sessionCurrent && _requestGeneration == generation;

  Future<void> _load() async {
    if (!_sessionCurrent || _saving) return;
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await widget.controller.loadCareShareSettings(
        memberId: widget.memberId,
      );
      if (!_isCurrentRequest(generation)) return;
      setState(() {
        _enabled = values;
        _loading = false;
      });
    } catch (_) {
      if (!_isCurrentRequest(generation)) return;
      setState(() {
        _error = uiCopy(context, "共享设置读取失败，请重新读取");
        _loading = false;
      });
    }
  }

  void _setGroup(Iterable<String> keys, bool enabled) {
    if (!_canEdit) return;
    setState(() {
      final values = {..._enabled};
      enabled ? values.addAll(keys) : values.removeAll(keys);
      _enabled = values;
    });
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    final generation = ++_requestGeneration;
    setState(() => _saving = true);
    final succeeded = await widget.controller.saveCareShareSettings(
      memberId: widget.memberId,
      settings: _enabled,
    );
    if (!mounted || !_isCurrentRequest(generation)) return;
    setState(() {
      _saving = false;
      _error = succeeded ? null : uiCopy(context, "保存未确认，请重新读取后重试");
    });
    if (succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uiCopy(context, "共享设置已保存"))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.member['nickname'] ?? widget.member['mobile'] ?? uiCopy(context, "关爱成员")}';
    return Scaffold(
      appBar: AppBar(title: Text(uiCopy(context, "共享数据管理"))),
      body: !_sessionCurrent
          ? Padding(
              padding: EdgeInsets.all(16),
              child: FeatureStateCard(
                message: uiCopy(context, "账号已变化，请返回后重新查看"),
                icon: Icons.person_outline,
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FeatureStateCard(
                  message: name,
                  detail: uiCopy(context, "仅共享已开启的项目，更改后请保存"),
                  icon: Icons.privacy_tip_outlined,
                  color: SaydianColors.green,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  FeatureStateCard(
                    message: _error!,
                    icon: Icons.cloud_off_outlined,
                  ),
                ],
                const SizedBox(height: 14),
                _permissionGroup(uiCopy(context, "每日数据"), _dailyKeys),
                const SizedBox(height: 12),
                _permissionGroup(uiCopy(context, "健康数据"), _healthKeys),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _canEdit ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? uiCopy(context, "保存中")
                        : uiCopy(context, "保存共享设置"),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(uiCopy(context, "重新读取共享设置")),
                ),
              ],
            ),
    );
  }

  Widget _permissionGroup(String title, Map<String, String> values) {
    final allEnabled = values.keys.every(_enabled.contains);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: TextButton(
              onPressed: _canEdit
                  ? () => _setGroup(values.keys, !allEnabled)
                  : null,
              child: Text(
                allEnabled ? uiCopy(context, "全部关闭") : uiCopy(context, "全选"),
              ),
            ),
          ),
          for (final entry in values.entries) ...[
            const Divider(indent: 16),
            SwitchListTile(
              title: Text(entry.value),
              value: _enabled.contains(entry.key),
              onChanged: _canEdit
                  ? (enabled) => _setGroup([entry.key], enabled)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class CareInvitationsPage extends StatefulWidget {
  const CareInvitationsPage({
    required this.controller,
    this.targetInvitationId,
    super.key,
  });

  final AppController controller;
  final String? targetInvitationId;

  @override
  State<CareInvitationsPage> createState() => _CareInvitationsPageState();
}

class _CareInvitationsPageState extends State<CareInvitationsPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isGlobalEdition) {
      unawaited(widget.controller.refreshCareInvitations());
    }
  }

  Future<void> _respond(Map<String, Object?> invite, bool accepted) async {
    final id = int.tryParse('${invite['id'] ?? 0}') ?? 0;
    if (id == 0) return;
    await widget.controller.respondCareInvitation(id: id, accepted: accepted);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isGlobalEdition) {
      return GlobalCarePage(controller: widget.controller);
    }
    return Scaffold(
      appBar: AppBar(title: Text(uiCopy(context, "关爱邀请"))),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final invitations = widget.controller.pendingCareInvitations;
          final targetId = widget.targetInvitationId;
          final targetedMatches = targetId == null
              ? const <Map<String, Object?>>[]
              : widget.controller.careInvitations
                    .where(
                      (item) =>
                          '${item['id'] ?? item['invitation_id'] ?? ''}' ==
                          targetId,
                    )
                    .toList(growable: false);
          final targeted = targetedMatches.isEmpty
              ? null
              : targetedMatches.first;
          if (invitations.isEmpty) {
            return RefreshIndicator(
              onRefresh: widget.controller.refreshCareInvitations,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FeatureStateCard(
                    message: targeted != null
                        ? uiCopy(context, "该关爱邀请已处理")
                        : targetId != null &&
                              widget.controller.careInvitationStatus != '加载中'
                        ? uiCopy(context, "该关爱邀请已处理或撤销")
                        : widget.controller.careInvitationStatus == '服务暂不可用'
                        ? uiCopy(context, "关爱邀请服务暂不可用")
                        : uiCopy(context, "暂无新的关爱邀请"),
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refreshCareInvitations,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final invite = invitations[index];
                final member = invite['member'];
                final memberMap = member is Map ? member : const {};
                final nickname = '${memberMap['nickname'] ?? ''}'.trim();
                final mobile = '${memberMap['mobile'] ?? ''}'.trim();
                final avatar = '${memberMap['head_portrait'] ?? ''}'.trim();
                final inviterId = '${invite['inviter_id'] ?? ''}'.trim();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: SaydianColors.brandRedSoft,
                              foregroundImage:
                                  avatar.startsWith('http://') ||
                                      avatar.startsWith('https://')
                                  ? SafeNetworkImageProvider(avatar)
                                  : null,
                              child: const Icon(
                                Icons.person_rounded,
                                color: SaydianColors.brandRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nickname.isEmpty
                                        ? uiCopy(context, "Say Ring 用户")
                                        : nickname,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mobile.isNotEmpty
                                        ? mobile
                                        : inviterId.isNotEmpty
                                        ? uiCopy(
                                            context,
                                            "邀请人账号 ID：{p0}",
                                            parameters: [inviterId],
                                          )
                                        : uiCopy(context, "邀请人信息暂不可用"),
                                    style: const TextStyle(
                                      color: SaydianColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (nickname.isEmpty && mobile.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            uiCopy(context, "请确认邀请人后再接受"),
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respond(invite, false),
                                child: Text(uiCopy(context, "拒绝")),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _respond(invite, true),
                                child: Text(uiCopy(context, "同意")),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
