part of '../pages.dart';

String _profileCareMemberNumber(Map<String, Object?> profile) {
  for (final key in ['memberNo', 'promo_code']) {
    final value = profile[key];
    if (value is! String && value is! int) continue;
    try {
      return CareInvitationTarget.memberId('$value').value;
    } on FormatException {
      // A UUID, referral code or unknown value is not a care member number.
    }
  }
  return '--';
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final profile = controller.memberProfile;
    final name = _memberDisplayName(context, controller);
    final memberId = _profileCareMemberNumber(profile);
    final avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
    return ListView(
      key: const Key('my-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (controller.isLocalMode) ...[
          Material(
            key: const Key('local-mode-login-prompt'),
            color: SaydianColors.techBlueSoft,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openPage(
                context,
                GlobalCodeLoginPage(controller: controller),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_iphone_outlined,
                      color: SaydianColors.techBlue,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前为本机使用',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '戒指数据只保存在本机；登录后可使用账号同步服务。',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '登录同步',
                      style: TextStyle(
                        color: SaydianColors.techBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: SaydianColors.techBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (controller.isPreviewMode) ...[
          Material(
            key: const Key('preview-login-prompt'),
            color: SaydianColors.techBlueSoft,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => unawaited(controller.logout()),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      color: SaydianColors.techBlue,
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
                            controller.commerceEnabled
                                ? '登录后可保存健康数据、设备和订单信息'
                                : '登录后可保存健康数据和设备信息',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '立即登录',
                      style: TextStyle(
                        color: SaydianColors.techBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: SaydianColors.techBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ProfileHeaderCard(
          name: name,
          detail: controller.session == null
              ? context.l10n.signInCloudHint
              : context.l10n.memberId(memberId),
          avatarUrl: avatarUrl,
          onTap: () => _openPage(
            context,
            controller.isLocalMode
                ? GlobalCodeLoginPage(controller: controller)
                : ProfileEditPage(controller: controller),
          ),
        ),
        const SizedBox(height: 12),
        _ProfileSummaryLayout(
          children: [
            _ProfileStat(
              key: const Key('profile-stat-device'),
              icon: Icons.circle_outlined,
              label: context.l10n.device,
              value: controller.connectedDevice == null
                  ? context.l10n.notConnected
                  : context.l10n.online,
              color: controller.connectedDevice == null
                  ? SaydianColors.muted
                  : SaydianColors.green,
              onTap: () => controller.selectTab(1),
            ),
            _ProfileStat(
              key: const Key('profile-stat-health-records'),
              icon: Icons.monitor_heart_outlined,
              label: context.l10n.healthRecords,
              value: context.l10n.recordCount(controller.healthRecords.length),
              color: SaydianColors.techViolet,
              onTap: () => _openPage(
                context,
                AllHealthDataPage(
                  controller: controller,
                  title: context.l10n.healthRecords,
                ),
              ),
            ),
            _ProfileStat(
              key: const Key('profile-stat-care-members'),
              icon: Icons.family_restroom_rounded,
              label: context.l10n.careMembers,
              value: context.l10n.memberCount(controller.careMembers.length),
              color: SaydianColors.techBlue,
              onTap: () => _openPage(
                context,
                controller.isGlobalEdition
                    ? CarePage(controller: controller)
                    : Scaffold(
                        appBar: AppBar(title: Text(context.l10n.remoteCare)),
                        body: CarePage(controller: controller),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        HealthReminderShortcut(controller: controller),
        const SizedBox(height: 12),
        if (controller.commerceEnabled) ...[
          Card(
            key: const Key('profile-orders-card'),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: SaydianColors.line),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.myOrders,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openOrders(context, null),
                        child: Text(context.l10n.all),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                  child: _ProfileActionLayout(
                    children: [
                      _OrderEntry(
                        label: context.l10n.awaitingPayment,
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: () => _openOrders(context, 0),
                      ),
                      _OrderEntry(
                        label: context.l10n.awaitingShipment,
                        icon: Icons.inventory_2_outlined,
                        onTap: () => _openOrders(context, 1),
                      ),
                      _OrderEntry(
                        label: context.l10n.awaitingDelivery,
                        icon: Icons.local_shipping_outlined,
                        onTap: () => _openOrders(context, 2),
                      ),
                      _OrderEntry(
                        label: context.l10n.afterSales,
                        icon: Icons.support_agent_rounded,
                        onTap: () => _openPage(
                          context,
                          AfterSalesPage(controller: controller),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Card(
          key: const Key('profile-quick-actions-card'),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: SaydianColors.line),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              if (controller.connectedDevice == null) ...[
                _MyQuickEntry(
                  key: const Key('my-add-device'),
                  title: context.l10n.addDevice,
                  subtitle: context.l10n.searchNearbyWatch,
                  icon: Icons.watch_outlined,
                  color: SaydianColors.techBlue,
                  onTap: () => _openPage(
                    context,
                    DeviceSearchPage(controller: controller),
                  ),
                ),
                const Divider(height: 1, indent: 72),
              ],
              if (!controller.hideAiContent) ...[
                _MyQuickEntry(
                  key: const Key('my-ai-question'),
                  title: context.l10n.aiQuestion,
                  subtitle: context.l10n.aiQuestionHint,
                  icon: Icons.chat_bubble_outline_rounded,
                  color: SaydianColors.techViolet,
                  onTap: () => _openPage(
                    context,
                    AiChatPage(controller: controller, app: 1),
                  ),
                ),
                const Divider(height: 1, indent: 72),
              ],
              _MyQuickEntry(
                title: context.l10n.unitSettings,
                subtitle: context.l10n.unitSettingsHint,
                icon: Icons.straighten_rounded,
                color: SaydianColors.techCyan,
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
          key: const Key('profile-services-card'),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: SaydianColors.line),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 14),
                    child: Text(
                      context.l10n.myServices,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
    if (!controller.commerceEnabled) return;
    _openPage(
      context,
      OrdersPage(controller: controller, initialStatus: status),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.detail,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String detail;
  final String avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: SaydianColors.ink,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      ],
    );
    final avatar = _MemberAvatar(imageUrl: avatarUrl, size: 72);
    const edit = SizedBox.square(
      dimension: 48,
      child: Icon(Icons.edit_outlined, color: SaydianColors.techBlue, size: 21),
    );
    return Semantics(
      button: true,
      hint: context.l10n.personalInfo,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            key: const Key('profile-header-card'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: SaydianColors.line),
              borderRadius: BorderRadius.circular(28),
            ),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [avatar, const Spacer(), edit]),
                      const SizedBox(height: 16),
                      identity,
                    ],
                  )
                : Row(
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      Expanded(child: identity),
                      edit,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSummaryLayout extends StatelessWidget {
  const _ProfileSummaryLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final columns = textScale > 1.6
          ? 1
          : textScale > 1.25 || constraints.maxWidth < 320
          ? 2
          : 3;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _ProfileActionLayout extends StatelessWidget {
  const _ProfileActionLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final columns = textScale > 1.3 || constraints.maxWidth < 300 ? 2 : 4;
      return Wrap(
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(width: constraints.maxWidth / columns, child: child),
        ],
      );
    },
  );
}

String _memberDisplayName(BuildContext context, AppController controller) {
  final nickname = '${controller.memberProfile['nickname'] ?? ''}'.trim();
  if (nickname.isNotEmpty) return nickname;
  final sessionName = controller.session?.displayName.trim() ?? '';
  if (sessionName.isNotEmpty) return sessionName;
  if (controller.isLocalMode) return '本机使用';
  return controller.isPreviewMode ? '体验用户' : context.l10n.defaultUser;
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
      decoration: const BoxDecoration(color: SaydianColors.techBlueSoft),
      child: Icon(
        Icons.person_rounded,
        color: SaydianColors.techBlue,
        size: size * 0.52,
      ),
    );
    final bytes = imageBytes;
    final image = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover)
        : imageUrl.isNotEmpty
        ? SafeNetworkImage(
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
                  border: Border.all(color: const Color(0x33316EF5)),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: size * 0.18,
                  color: SaydianColors.techBlue,
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
      constraints: const BoxConstraints(minHeight: 118),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: SaydianColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth > 200;
                final graphic = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 23),
                );
                final labels = Column(
                  crossAxisAlignment: horizontal
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      textAlign: horizontal ? TextAlign.left : TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: horizontal ? TextAlign.left : TextAlign.center,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
                return horizontal
                    ? Row(
                        children: [
                          graphic,
                          const SizedBox(width: 14),
                          Expanded(child: labels),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: SaydianColors.outline,
                          ),
                        ],
                      )
                    : Column(
                        children: [graphic, const SizedBox(height: 10), labels],
                      );
              },
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
      if (!controller.hideAiContent)
        (
          label: context.l10n.healthProfile,
          icon: Icons.assignment_ind_outlined,
          page: HealthProfilePage(controller: controller),
        ),
      (
        label: context.l10n.accountSettings,
        icon: Icons.manage_accounts_outlined,
        page: AccountSettingsPage(controller: controller),
      ),
      (
        label: context.l10n.permissions,
        icon: Icons.admin_panel_settings_outlined,
        page: PermissionManagementPage(controller: controller),
      ),
      (
        label: '帮助反馈',
        icon: Icons.help_outline_rounded,
        page: FeedbackPage(controller: controller),
      ),
      (
        label: context.l10n.customerService,
        icon: Icons.headset_mic_outlined,
        page: CustomerServicePage(
          isGlobalEdition: controller.isGlobalEdition,
          controller: controller,
        ),
      ),
      (
        label: context.l10n.aboutApp,
        icon: Icons.info_outline_rounded,
        page: AboutSaydianPage(controller: controller),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = textScale > 1.3 || constraints.maxWidth < 300 ? 2 : 3;
        final width = constraints.maxWidth / columns;
        return Wrap(
          alignment: WrapAlignment.start,
          runSpacing: 16,
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
    return Semantics(
      hint: subtitle,
      child: Tooltip(
        message: subtitle,
        child: ListTile(
          onTap: onTap,
          minVerticalPadding: 16,
          leading: _SettingsIcon(icon: icon, color: color),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: SaydianColors.outline,
          ),
        ),
      ),
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: SaydianColors.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: SaydianColors.techBlue, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: SaydianColors.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: SaydianColors.techBlue, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
