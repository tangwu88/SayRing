part of '../pages.dart';

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
      appBar: AppBar(title: Text(context.l10n.unitSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            header: true,
            child: Text(
              context.l10n.distance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Card(
            child: RadioGroup<String>(
              groupValue: _distance,
              onChanged: (value) {
                setState(() => _distance = value!);
                widget.controller.setUnits(distance: value);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: "公里",
                    title: Text(context.l10n.unitKmLabel),
                  ),
                  RadioListTile<String>(
                    value: "英里",
                    title: Text(context.l10n.unitMilesLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              context.l10n.unitsTemperature,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Card(
            child: RadioGroup<String>(
              groupValue: _temperature,
              onChanged: (value) {
                setState(() => _temperature = value!);
                widget.controller.setUnits(temperature: value);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: "摄氏度（℃）",
                    title: Text(context.l10n.unitCelsiusLabel),
                  ),
                  RadioListTile<String>(
                    value: "华氏度（℉）",
                    title: Text(context.l10n.unitFahrenheitLabel),
                  ),
                ],
              ),
            ),
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

  @override
  void initState() {
    super.initState();
    _steps = TextEditingController(text: '${widget.controller.stepGoal}');
    _distance = TextEditingController(
      text: '${widget.controller.distanceGoal}',
    );
  }

  @override
  void dispose() {
    _steps.dispose();
    _distance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final steps = int.tryParse(_steps.text);
    final distance = double.tryParse(_distance.text);
    if (steps == null || distance == null || steps <= 0 || distance <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uiCopy(context, "请输入有效的目标数值"))));
      return;
    }
    final saved = await widget.controller.saveActivityGoals(
      steps: steps,
      distance: distance,
      calories: widget.controller.calorieGoal,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? uiCopy(context, "目标已保存")
              : widget.controller.errorMessage ?? uiCopy(context, "保存失败"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.goalSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _steps,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.dailyStepGoalField,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.dailyDistanceGoalField,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.controller.isBusy ? null : _save,
            child: Text(context.l10n.saveGoals),
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
    if (controller.isLocalMode) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.accountSettings)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uiCopy(context, "本机使用"),
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      uiCopy(context, "戒指连接、测量和睡眠明细可在本机使用；账号同步、资料和关爱功能需登录后开启。"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('local-mode-sign-in'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GlobalCodeLoginPage(controller: controller),
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: Text(uiCopy(context, "登录同步")),
            ),
            const SizedBox(height: 12),
            ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GlobalLegalPage(
                    controller: controller,
                    document: GlobalLegalDocumentType.privacyPolicy,
                  ),
                ),
              ),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(context.l10n.privacyAgreement),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.accountSettings)),
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
                  title: Text(context.l10n.personalInfo),
                  subtitle: Text(
                    controller.isGlobalEdition
                        ? context.l10n.emailOrPhone
                        : uiCopy(context, "注册手机号和基础资料"),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                if (controller.commerceEnabled) ...[
                  const Divider(indent: 56),
                  ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ShopAddressBookPage(controller: controller),
                      ),
                    ),
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(context.l10n.deliveryAddresses),
                    subtitle: Text(context.l10n.viewAccountAddresses),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'reset-password'),
                      builder: (_) => controller.isGlobalEdition
                          ? GlobalAuthPage(
                              controller: controller,
                              resetPassword: true,
                            )
                          : PasswordRecoveryPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.password_rounded),
                  title: Text(context.l10n.resetPassword),
                  subtitle: Text(
                    controller.isGlobalEdition
                        ? context.l10n.emailOrPhone
                        : uiCopy(context, "验证手机号后重新设置登录密码"),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => controller.isGlobalEdition
                          ? GlobalLegalPage(
                              controller: controller,
                              document: GlobalLegalDocumentType.privacyPolicy,
                            )
                          : ArticleDetailPage(
                              controller: controller,
                              article: {
                                'id': 3,
                                'title': uiCopy(context, "隐私协议"),
                              },
                              singleArticle: true,
                            ),
                    ),
                  ),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(context.l10n.privacyAgreement),
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
            child: Text(
              controller.isPreviewMode
                  ? uiCopy(context, "退出体验")
                  : uiCopy(context, "退出登录"),
            ),
          ),
          TextButton(
            onPressed: controller.session == null
                ? null
                : () => _confirmDeleteAccount(context),
            style: TextButton.styleFrom(foregroundColor: SaydianColors.danger),
            child: Text(context.l10n.deleteAccount),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmDeleteAccountTitle),
        content: Text(context.l10n.deleteAccountHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: SaydianColors.danger,
            ),
            child: Text(context.l10n.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await controller.deleteAccount();
    if (!context.mounted) return;
    if (deleted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userFacingMessage(
            controller.errorMessage,
            fallback: uiCopy(context, "注销失败，请稍后重试"),
          ),
        ),
      ),
    );
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
      appBar: AppBar(title: Text(context.l10n.deliveryAddresses)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final addresses = widget.controller.addresses;
          if (addresses.isEmpty) {
            return Center(
              child: Text(
                uiCopy(context, "暂无收货地址"),
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
                        ? Chip(label: Text(uiCopy(context, "默认")))
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
  late String _registeredMobile;
  Uint8List? _avatarBytes;
  String? _avatarFilePath;
  bool _isPickingAvatar = false;
  bool _isLoadingProfile = false;
  bool _profileEdited = false;
  String? _profileLoadError;

  int _profileGender(Object? rawValue) {
    final value = int.tryParse('${rawValue ?? ''}');
    return value == 1 || value == 2 ? value! : 0;
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.memberProfile;
    _nickname = TextEditingController(text: '${profile['nickname'] ?? ''}');
    _birthday = TextEditingController(text: '${profile['birthday'] ?? ''}');
    _height = TextEditingController(text: '${profile['height'] ?? ''}');
    _weight = TextEditingController(text: '${profile['weight'] ?? ''}');
    _gender = _profileGender(profile['gender']);
    _avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
    _registeredMobile = _mobileFromProfile(profile);
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

  String _mobileFromProfile(Map<String, Object?> profile) {
    if (widget.controller.isGlobalEdition) {
      return [profile['emailMasked'], profile['phoneMasked']]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' · ');
    }
    return '${profile['mobile'] ?? ''}'.trim();
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
        _profileLoadError =
            widget.controller.memberProfileReadError ??
            uiCopy(context, "暂未读取到个人资料，请重新读取");
        return;
      }
      _registeredMobile = _mobileFromProfile(profile);
      if (_profileEdited) return;
      _nickname.text = '${profile['nickname'] ?? ''}';
      _birthday.text = '${profile['birthday'] ?? ''}';
      _height.text = '${profile['height'] ?? ''}';
      _weight.text = '${profile['weight'] ?? ''}';
      _gender = _profileGender(profile['gender']);
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
      ).showSnackBar(SnackBar(content: Text(uiCopy(context, "登录后可更换头像"))));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiCopy(context, "图片过大，请选择较小的照片"))),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarFilePath = image.path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiCopy(context, "无法读取照片，请检查相册权限后重试"))),
      );
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (_isPickingAvatar) return;
    if (_avatarFilePath case final avatarFilePath?
        when !_profileEdited && widget.controller.isGlobalEdition) {
      final saved = await widget.controller.saveMemberAvatar(avatarFilePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? uiCopy(context, "头像已保存")
                : widget.controller.errorMessage ?? uiCopy(context, "头像保存失败"),
          ),
        ),
      );
      if (saved) Navigator.of(context).pop();
      return;
    }
    if (_gender != 1 && _gender != 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uiCopy(context, "请选择性别"))));
      return;
    }
    final height = double.tryParse(_height.text);
    final weight = double.tryParse(_weight.text);
    if (_nickname.text.trim().isEmpty ||
        _birthday.text.isEmpty ||
        height == null ||
        height < 50 ||
        height > 250 ||
        weight == null ||
        weight < 10 ||
        weight > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiCopy(context, "请完整填写资料，身高 50~250 cm、体重 10~500 kg")),
        ),
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
          saved
              ? uiCopy(context, "个人资料已保存")
              : widget.controller.errorMessage ?? uiCopy(context, "保存失败"),
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
        title: Text(
          isPreview ? uiCopy(context, "退出体验？") : uiCopy(context, "退出登录？"),
        ),
        content: Text(
          isPreview
              ? uiCopy(context, "退出后将返回登录页面。")
              : uiCopy(context, "确认退出当前账号吗？"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.exit),
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
    if (widget.controller.isLocalMode) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.personalInfo)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 42),
                const SizedBox(height: 14),
                Text(
                  uiCopy(context, "本机使用不上传头像或个人资料。"),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  uiCopy(context, "登录后才可编辑和同步个人资料。"),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GlobalCodeLoginPage(controller: widget.controller),
                    ),
                  ),
                  child: Text(uiCopy(context, "登录同步")),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.personalInfo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: uiCopy(context, "更换头像"),
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
            _avatarFilePath == null
                ? uiCopy(context, "点击头像更换照片")
                : uiCopy(context, "已选择新头像，保存后生效"),
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted),
          ),
          if (_isLoadingProfile) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              context.l10n.loadingProfile,
              textAlign: TextAlign.center,
              style: TextStyle(color: SaydianColors.muted),
            ),
          ] else if (_profileLoadError case final message?) ...[
            const SizedBox(height: 14),
            InlineNotice(
              message: message,
              icon: Icons.info_outline_rounded,
              color: SaydianColors.warning,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadLatestProfile,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.readAgain),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Semantics(
            label: widget.controller.isGlobalEdition
                ? '${context.l10n.emailOrPhone}, ${_registeredMobile.isEmpty ? '—' : _registeredMobile}'
                : _registeredMobile.isEmpty
                ? uiCopy(context, "注册手机号，未获取")
                : uiCopy(
                    context,
                    "注册手机号，{p0}",
                    parameters: [_registeredMobile],
                  ),
            child: InputDecorator(
              key: const Key('profile-registered-mobile'),
              decoration: InputDecoration(
                labelText: widget.controller.isGlobalEdition
                    ? context.l10n.emailOrPhone
                    : uiCopy(context, "注册手机号"),
                suffixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              child: Text(
                _registeredMobile.isEmpty
                    ? (widget.controller.isGlobalEdition ? '—' : '未获取')
                    : _registeredMobile,
                style: const TextStyle(color: SaydianColors.ink, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-nickname'),
            controller: _nickname,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            decoration: InputDecoration(labelText: context.l10n.nickname),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('profile-gender-$_gender'),
            initialValue: _gender,
            decoration: InputDecoration(labelText: context.l10n.gender),
            items: [
              DropdownMenuItem(value: 0, child: Text(uiCopy(context, "未设置"))),
              DropdownMenuItem(value: 1, child: Text(uiCopy(context, "男"))),
              DropdownMenuItem(value: 2, child: Text(uiCopy(context, "女"))),
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
            decoration: InputDecoration(
              labelText: context.l10n.birthDate,
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
            decoration: InputDecoration(labelText: context.l10n.heightCm),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-weight'),
            controller: _weight,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.weightKg),
          ),
          const SizedBox(height: 18),
          InlineNotice(
            message: context.l10n.profileSaveExplanation,
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
            child: Text(
              _isPickingAvatar
                  ? uiCopy(context, "正在读取照片")
                  : uiCopy(context, "保存资料"),
            ),
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
            label: Text(
              widget.controller.isPreviewMode
                  ? uiCopy(context, "退出体验")
                  : uiCopy(context, "退出登录"),
            ),
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
  bool _statusesLoaded = false;

  List<Permission> get _permissions =>
      defaultTargetPlatform == TargetPlatform.android
      ? [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
          if (widget.controller.visibleDeviceFeatures.contains(
            DeviceFeature.camera,
          ))
            Permission.camera,
          if (widget.controller.notificationServiceConfigured)
            Permission.notification,
        ]
      : [
          Permission.bluetooth,
          Permission.locationWhenInUse,
          if (widget.controller.visibleDeviceFeatures.contains(
            DeviceFeature.camera,
          ))
            Permission.camera,
          if (widget.controller.notificationServiceConfigured)
            Permission.notification,
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.healthOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(widget.controller.refreshDeviceSettings());
        }
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
    // Camera visibility can change after a late capability handshake. Read its
    // OS status now without requesting access; otherwise a newly visible row
    // would falsely look unreadable until this page is reopened.
    final permissionsToCheck = {..._permissions, Permission.camera};
    for (final permission in permissionsToCheck) {
      try {
        statuses[permission] = await permission.status;
      } catch (_) {
        // An unavailable platform status must not be reported as denied.
      }
    }
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _statusesLoaded = true;
      });
    }
  }

  Future<void> _request(Permission permission) async {
    final status = _statuses[permission];
    if (permission == Permission.notification ||
        status == PermissionStatus.permanentlyDenied ||
        status == PermissionStatus.restricted) {
      await openAppSettings();
    } else {
      await permission.request();
    }
    await _refresh();
  }

  String _name(Permission permission) {
    if (permission == Permission.bluetoothScan) {
      return uiCopy(context, "附近设备扫描");
    }
    if (permission == Permission.bluetoothConnect) {
      return uiCopy(context, "蓝牙设备连接");
    }
    if (permission == Permission.bluetooth) return uiCopy(context, "蓝牙");
    if (permission == Permission.locationWhenInUse) {
      return uiCopy(context, "位置（户外运动轨迹）");
    }
    if (permission == Permission.camera) return uiCopy(context, "相机（戒指遥控拍照）");
    return uiCopy(context, "通知");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.healthOnly ? uiCopy(context, "健康监测") : uiCopy(context, "权限管理"),
        ),
        actions: [
          if (widget.healthOnly)
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final availability = widget.controller.availabilityFor(
                  DeviceFeature.findWatch,
                );
                final busy = widget.controller.deviceFeatureBusy.contains(
                  DeviceFeature.findWatch,
                );
                return Tooltip(
                  message: availability.isReady
                      ? uiCopy(context, "查找已连接的戒指")
                      : availability.message,
                  child: TextButton(
                    key: const ValueKey('health-monitoring-find-device'),
                    onPressed: availability.isReady && !busy
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: 'device-find',
                              ),
                              builder: (_) => DeviceFeaturePage(
                                controller: widget.controller,
                                feature: DeviceFeature.findWatch,
                              ),
                            ),
                          )
                        : null,
                    child: MediaQuery.textScalerOf(context).scale(16) > 22
                        ? Icon(
                            Icons.radar_rounded,
                            semanticLabel: uiCopy(context, "查找设备"),
                          )
                        : Text(uiCopy(context, "查找设备")),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.healthOnly) ..._healthMonitoringContent(),
            if (!widget.healthOnly) ...[
              const SizedBox(height: 20),
              Text(
                context.l10n.appPermissions,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final permission in _permissions) ...[
                      Builder(
                        builder: (context) {
                          final status = _statuses[permission];
                          final allowed =
                              status == PermissionStatus.granted ||
                              status == PermissionStatus.limited;
                          return ListTile(
                            leading: Icon(
                              allowed
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              color: allowed
                                  ? SaydianColors.green
                                  : SaydianColors.orange,
                            ),
                            title: Text(_name(permission)),
                            subtitle: Text(
                              status == PermissionStatus.limited
                                  ? uiCopy(context, "已允许访问部分照片")
                                  : status == PermissionStatus.granted
                                  ? uiCopy(context, "已允许")
                                  : status == null
                                  ? (_statusesLoaded
                                        ? uiCopy(context, "状态暂不可读取")
                                        : uiCopy(context, "正在读取状态"))
                                  : uiCopy(context, "未允许"),
                            ),
                            trailing: TextButton(
                              onPressed: () => _request(permission),
                              child: Text(context.l10n.settings),
                            ),
                          );
                        },
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
                label: Text(context.l10n.openSystemSettings),
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
    return Column(
      children: [
        SwitchListTile(
          key: ValueKey('device-health-auto-$type'),
          secondary: Icon(icon, color: SaydianColors.pink),
          title: Text(title),
          subtitle: Text(
            enabled ? uiCopy(context, "已开启") : uiCopy(context, "已关闭"),
          ),
          value: enabled,
          onChanged:
              widget.controller.connectedDevice == null ||
                  widget.controller.isDeviceSettingsLoading ||
                  widget.controller.isDeviceSettingsWriting
              ? null
              : (value) {
                  unawaited(
                    widget.controller.setAutoMeasureSetting(type, value),
                  );
                },
        ),
        if (!_usesSharedMonitoringInterval ||
            (type != 'heartRate' && type != 'bloodOxygen'))
          _deviceAutoInterval(type),
      ],
    );
  }

  // The bundled CoolWear SDK exposes one physical interval for these two
  // switches. This is a presentation grouping, not a new device capability.
  bool get _usesSharedMonitoringInterval =>
      widget.controller.connectedDevice?.sdkSource ==
      WearableSdkSource.coolwear;

  Widget _deviceAutoInterval(String type, {bool shared = false}) {
    final interval = widget.controller.autoMeasureIntervals[type];
    if (interval == null) return const SizedBox.shrink();
    final enabled = widget.controller.autoMeasureSettings[type] == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(shared ? 18 : 72, 0, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              uiCopy(context, "监测间隔"),
              style: const TextStyle(color: SaydianColors.muted),
            ),
          ),
          if (interval.canModify)
            DropdownButton<int>(
              key: ValueKey(
                'device-health-interval-${shared ? 'shared' : type}',
              ),
              value: interval.choices.contains(interval.minutes)
                  ? interval.minutes
                  : null,
              hint: Text(context.l10n.choose),
              items: [
                for (final minutes in interval.choices)
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(
                      uiCopy(context, "{p0} 分钟", parameters: [minutes]),
                    ),
                  ),
              ],
              onChanged:
                  !enabled ||
                      widget.controller.connectedDevice == null ||
                      widget.controller.isDeviceSettingsLoading ||
                      widget.controller.isDeviceSettingsWriting
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
                  ? uiCopy(
                      context,
                      "每 {p0} 分钟（戒指固定）",
                      parameters: [interval.minutes],
                    )
                  : uiCopy(context, "戒指固定"),
              style: const TextStyle(color: SaydianColors.muted),
            ),
        ],
      ),
    );
  }

  List<Widget> _healthMonitoringContent() {
    final controller = widget.controller;
    final settings = controller.autoMeasureSettings;
    final sharedTypes = _usesSharedMonitoringInterval
        ? ['heartRate', 'bloodOxygen']
              .where(
                (type) =>
                    settings.containsKey(type) &&
                    controller.autoMeasureIntervals.containsKey(type),
              )
              .toList()
        : <String>[];
    // Oxygen-only monitoring must remain configurable while heart rate is off.
    final sharedType =
        sharedTypes.where((type) => settings[type] == true).firstOrNull ??
        sharedTypes.firstOrNull;
    final specs = <({String type, String title, IconData icon})>[
      (
        type: 'heartRate',
        title: uiCopy(context, "心率自动检测"),
        icon: Icons.favorite_outline_rounded,
      ),
      (
        type: 'bloodOxygen',
        title: uiCopy(context, "血氧自动检测"),
        icon: Icons.water_drop_outlined,
      ),
      (
        type: 'heartRate24h',
        title: uiCopy(context, "24 小时心率"),
        icon: Icons.monitor_heart_outlined,
      ),
      (
        type: 'hrv',
        title: uiCopy(context, "心率变异性（HRV）自动检测"),
        icon: Icons.monitor_heart_outlined,
      ),
      (
        type: 'stress',
        title: uiCopy(context, "压力自动检测"),
        icon: Icons.self_improvement_rounded,
      ),
      (
        type: 'bloodPressure',
        title: uiCopy(context, "血压自动检测"),
        icon: Icons.speed_rounded,
      ),
      (
        type: 'bloodGlucose',
        title: uiCopy(context, "血糖自动检测"),
        icon: Icons.water_drop_outlined,
      ),
      (
        type: 'bodyTemperature',
        title: uiCopy(context, "皮肤温度自动检测"),
        icon: Icons.thermostat_rounded,
      ),
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
          Expanded(
            child: Text(
              uiCopy(context, "戒指健康检测"),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed:
                controller.connectedDevice == null ||
                    controller.isDeviceSettingsLoading ||
                    controller.isDeviceSettingsWriting
                ? null
                : controller.refreshDeviceSettings,
            tooltip: uiCopy(context, "从戒指刷新"),
            icon: controller.isDeviceSettingsLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      if (tiles.isNotEmpty)
        Text(
          controller.deviceSettingsStatus,
          style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      const SizedBox(height: 8),
      if (controller.connectedDevice == null)
        FeatureStateCard(
          message: devicePromptLabel(context, context.l10n.connectWatchToUse),
          detail: devicePromptLabel(context, context.l10n.monitoringHint),
          icon: Icons.watch_outlined,
        )
      else if (tiles.isEmpty && controller.isDeviceSettingsLoading)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(controller.deviceSettingsStatus),
        )
      else if (tiles.isEmpty)
        FeatureStateCard(
          message: controller.deviceSettingsStatus,
          detail: uiCopy(context, "没有读取到可设置项目，可重新读取戒指设置。"),
          icon: Icons.monitor_heart_outlined,
          actionLabel:
              controller.isDeviceSettingsLoading ||
                  controller.isDeviceSettingsWriting
              ? null
              : uiCopy(context, "重新读取"),
          onAction:
              controller.isDeviceSettingsLoading ||
                  controller.isDeviceSettingsWriting
              ? null
              : controller.refreshDeviceSettings,
        )
      else ...[
        Card(child: Column(children: tiles)),
        if (sharedType != null) ...[
          const SizedBox(height: 12),
          Card(
            key: const ValueKey('device-health-shared-interval'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(Icons.schedule_rounded),
                  title: Text(uiCopy(context, "共同监测间隔")),
                  subtitle: Text(uiCopy(context, "心率与血氧共用此间隔，分别通过上方开关开启或关闭。")),
                ),
                _deviceAutoInterval(sharedType, shared: true),
                if (!sharedTypes.any((type) => settings[type] == true))
                  Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Text(uiCopy(context, "请先开启心率或血氧自动检测，再设置间隔。")),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          uiCopy(context, "监测频率越高，耗电越快。仅显示戒指实际支持的项目；未提供间隔的项目由固件管理，当前无法调整。"),
          style: TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      ],
    ];
  }

  Widget _heartRateWarningTile() => ListTile(
    key: const ValueKey('device-health-heart-warning'),
    leading: const Icon(
      Icons.warning_amber_rounded,
      color: SaydianColors.orange,
    ),
    title: Text(context.l10n.watchHighHeartRate),
    subtitle: Text(devicePromptLabel(context, context.l10n.watchThresholdHint)),
    trailing: DropdownButton<int>(
      value: widget.controller.heartRateWarning,
      items: [
        for (var value = 70; value < 190; value += 5)
          DropdownMenuItem(
            value: value,
            child: Text(uiCopy(context, "{p0} 次/分", parameters: [value])),
          ),
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
